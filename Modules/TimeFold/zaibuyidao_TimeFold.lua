-- NoIndex: true
local reaper = reaper
local source = debug.getinfo(1, "S").source
local directory = source:sub(2):match("^(.*[/\\])")
local json = dofile(directory .. "json.lua")
local snap_grid = dofile(directory .. "grid.lua")

function resource(path)
  local file = assert(io.open(directory .. path, "rb"))
  local text = file:read("*a")
  file:close()
  return json.decode(text)
end

local english = resource("locales/en.json")
local languages, resources = json.array(), {}
local language_order = {}

local file_index = 0

while true do
  local file = reaper.EnumerateFiles(directory .. "locales", file_index)
  if not file then break end
  file_index = file_index + 1
  local code = file:match("^([%w%-]+)%.json$")
  if code then
    local ok, data = pcall(resource, "locales/" .. file)
    if ok and data.locale == code and type(data.nativeName) == "string" and type(data.strings) == "table" then
      resources[code] = data.strings
      language_order[code] = type(data.order) == "number" and data.order or math.huge
      languages[#languages + 1] = { code = code, name = data.nativeName }
    end
  end
end

table.sort(languages, function(a, b) if language_order[a.code] ~= language_order[b.code] then return language_order[a.code] < language_order[b.code] end return a.code < b.code end)
local locale = "en"
local function t(key) return (resources[locale] or {})[key] or english.strings[key] or key end
if not reaper.APIExists("ReaWeb_Send") then reaper.MB(t("bridgeMissing"), t("appTitle"), 0) return end
if not reaper.APIExists("JS_Window_GetScrollInfo") or not reaper.APIExists("JS_Window_SetScrollPos") then
  reaper.MB(t("jsMissing"), t("appTitle"), 0) return
end

local arrange = reaper.JS_Window_FindChildByID(reaper.GetMainHwnd(), 1000)
if not arrange then reaper.MB(t("syncFailed"), t("appTitle"), 0) return end

local window = reaper.ReaWeb_Open(directory .. "index.html", source)
if window == 0 then reaper.MB(t("openFailed") .. "\n" .. reaper.ReaWeb_GetLastError(), t("appTitle"), 0) return end
if tonumber(reaper.GetExtState("ReaWebAPI.Backends", source)) == window then return end
reaper.SetExtState("ReaWebAPI.Backends", source, tostring(window), false)

local settings_window, settings_state, settings_ready, settings_dirty, settings_request
local settings_actions = {}
local editor_window, editor_state, editor_ready, editor_dirty, editor_closed, editor_action

reaper.atexit(function()
  if editor_window then reaper.ReaWeb_Close(editor_window) end
  if settings_window then reaper.ReaWeb_Close(settings_window) end
  reaper.ReaWeb_Close(window)
  if reaper.GetExtState("ReaWebAPI.Backends", source) == tostring(window) then reaper.DeleteExtState("ReaWebAPI.Backends", source, false) end
end)

local section, key = "ArrangeNavigator", "state.v1"
local project, session, revision, generation = nil, 0, 0, 0
local labels, raw_state, state_error = json.array(), nil, false
local next_id, changed, worker, pending = 1, -1, nil, nil
local ready, next_snapshot, next_transport, next_labels = false, 0, 0, 0
local label_dirty = false
local sent_sequence, acknowledged_sequence, hello_dirty, pending_error = 0, 0, false, nil
local next_layout, last_layout, rescan_at = 0, nil, 0
local undo, redo = json.array(), json.array()
local pending_snap, pending_notice

function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
function time(value) return finite(value) and value >= 0 and value <= 1e9 end
function range(a, b) return time(a) and time(b) and b - a >= 0.01 end
function name_valid(value) return type(value) == "string" and #value <= 1024 and not value:find("[%z\1-\31]") and utf8.len(value) ~= nil end
function color_valid(value) return value == nil or type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil end

function valid_labels(value)
  if not json.is_array(value) or #value > 512 then return false end
  local seen = {}
  for _, label in ipairs(value) do
    if type(label) ~= "table" or not finite(label.id) or label.id < 1 or label.id % 1 ~= 0 or label.id > 1e9
      or seen[label.id] or not range(label.start, label.finish) or not name_valid(label.name)
      or type(label.collapsed) ~= "boolean" or not color_valid(label.color) then return false end
    seen[label.id] = true
  end

  return true
end

function send(data)
  if sent_sequence - acknowledged_sequence >= 12 then return false end
  data.sequence = sent_sequence + 1
  if not reaper.ReaWeb_Send(window, json.encode(data)) then return false end
  sent_sequence = data.sequence

  return true
end

function error_message(code) pending_error = code end

function read_labels()
  local _, raw = reaper.GetProjExtState(project, section, key)
  if raw == raw_state then return end
  raw_state, revision = raw, revision + 1
  labels, next_id, state_error = json.array(), 1, false
  undo, redo = json.array(), json.array()
  if raw ~= "" then
    local ok, value = pcall(json.decode, raw)

    if ok and type(value) == "table" and value.version == 1 and valid_labels(value.labels) then
      labels = json.array(value.labels)

      for _, label in ipairs(labels) do next_id = math.max(next_id, label.id + 1) end
      if finite(value.nextId) and value.nextId % 1 == 0 and value.nextId <= 1e9 then next_id = math.max(next_id, value.nextId) end

      if value.history ~= nil then
        local h = value.history
        if type(h) ~= "table" or not json.is_array(h.undo) or not json.is_array(h.redo) or #h.undo + #h.redo > 64 then state_error = true
        else
          for _, stack in ipairs({h.undo, h.redo}) do for _, entry in ipairs(stack) do if not valid_labels(entry) then state_error = true break end end end
          if not state_error then undo, redo = json.array(h.undo), json.array(h.redo) end
        end
      end
    else
      state_error = true end
  end

  label_dirty = true
end

function publish_labels()
  if send({ type = "labels", session = session, revision = revision, labels = labels, stateError = state_error, canUndo = #undo > 0, canRedo = #redo > 0 }) then label_dirty = false end
end

function write_labels(updated, past, future, record)
  past, future = json.array(past or {table.unpack(undo)}), json.array(future or {})
  if record ~= false then past[#past + 1] = labels end

  local function encode() return json.encode({ version = 1, labels = updated, nextId = next_id, history = { undo = past, redo = future } }) end
  local raw = encode()

  while #past + #future > 64 or #raw > 2097152 do
    if #past > 0 then table.remove(past, 1) elseif #future > 0 then table.remove(future, 1) else break end
    raw = encode()
  end

  if reaper.SetProjExtState(project, section, key, raw) <= 0 then error_message("saveFailed") return end
  reaper.MarkProjectDirty(project)
  raw_state, labels, undo, redo, revision, label_dirty = raw, updated, past, future, revision + 1, true

  return true
end

function history_step(back)
  read_labels()
  if state_error then return end

  local past, future = json.array({table.unpack(undo)}), json.array({table.unpack(redo)})
  local from, to = back and past or future, back and future or past
  if #from == 0 then return end
  local restored = table.remove(from)
  to[#to + 1] = labels
  write_labels(restored, past, future, false)
end

function color(native)
  if native == 0 then return json.null end

  local r, g, b = reaper.ColorFromNative(native)
  return string.format("#%02x%02x%02x", r, g, b)
end

function batch_labels(data)
  read_labels()

  if state_error then error_message("stateInvalid") return end
  if data.revision ~= revision then label_dirty = true error_message("conflict") return end
  local updated = json.array({table.unpack(labels)})

  if data.action == "collapse" and type(data.collapsed) == "boolean" then
    local modified = false
    for i, label in ipairs(labels) do
      updated[i] = { id = label.id, start = label.start, finish = label.finish, name = label.name, color = label.color, collapsed = data.collapsed }
      modified = modified or label.collapsed ~= data.collapsed
    end
    if modified then write_labels(updated) end

    return
  end

  if data.action ~= "markers" and data.action ~= "regions" then return end
  local entries, index = {}, 0

  while true do
    local found, region, a, b, name, id, native_color = reaper.EnumProjectMarkers3(project, index)
    if found == 0 then break end
    index = index + 1
    if region == (data.action == "regions") then
      entries[#entries + 1] = { start = a, finish = b, name = name, sourceId = id, color = native_color ~= 0 and color(native_color) or "#718e86" }
    end
  end

  table.sort(entries, function(a, b) if a.start == b.start then return a.sourceId < b.sourceId end return a.start < b.start end)
  if data.action == "markers" then
    local boundary = reaper.GetProjectLength(project)
    for i = #entries, 1, -1 do
      if i < #entries and entries[i].start < entries[i + 1].start then boundary = entries[i + 1].start end
      entries[i].finish = boundary
    end
  end

  local function identity(label) return json.encode({label.start, label.finish, label.name}) end
  local seen, added = {}, 0

  for _, label in ipairs(labels) do seen[identity(label)] = true end

  for _, entry in ipairs(entries) do
    if range(entry.start, entry.finish) then
      if not name_valid(entry.name) then error_message("importInvalid") return end
      local key = identity(entry)
      if not seen[key] then
        added = added + 1
        if #updated >= 512 or next_id + added > 1e9 then error_message("labelLimit") return end
        updated[#updated + 1] = { id = next_id + added - 1, start = entry.start, finish = entry.finish, name = entry.name, color = entry.color, collapsed = false }
        seen[key] = true
      end
    end
  end

  if added > 0 then
    local previous_id = next_id
    next_id = next_id + added
    if not write_labels(updated) then next_id = previous_id return end
  end

  pending_notice = { type = "notice", session = session, code = added > 0 and "importedLabels" or "noLabelsImported", count = added }
end

function vertical_view()
  local ok, position, page, minimum, maximum = reaper.JS_Window_GetScrollInfo(arrange, "v")
  if not ok then return 0, 1, 0, 0 end

  if page <= 0 then
    local _, _, height = reaper.JS_Window_GetClientSize(arrange)
    page = math.max(1, height)
  end

  return position, page, minimum, math.max(minimum, maximum - page + 1)
end

function publish_layout()
  local position, page, minimum, maximum = vertical_view()
  local _, _, client_height = reaper.JS_Window_GetClientSize(arrange)
  local rows = json.array()

  for i = 0, reaper.CountTracks(project) - 1 do
    local track = reaper.GetTrack(project, i)
    rows[#rows + 1] = { id = reaper.GetTrackGUID(track), y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY"),
      height = reaper.GetMediaTrackInfo_Value(track, "I_WNDH"), pinned = reaper.GetMediaTrackInfo_Value(track, "B_TCPPIN") ~= 0,
      visible = reaper.GetMediaTrackInfo_Value(track, "B_SHOWINTCP") ~= 0 }
  end

  local value = { rows = rows, scroll = position, page = page, clientHeight = client_height, minimum = minimum, maximum = maximum }
  local encoded = json.encode(value)

  if encoded ~= last_layout then
    value.type, value.session = "layout", session
    if send(value) then last_layout = encoded end
  end
end

function start_snapshot(now, count)
  generation, changed, next_snapshot = generation + 1, count, now + 0.05
  local gen, proj, token = generation, project, session
  rescan_at = now + 1

  worker = coroutine.create(function()
    local background = reaper.GetThemeColor("col_mi_bg", 0)
    local r, g, b = reaper.ColorFromNative(background >= 0 and background or 0x888888)
    coroutine.yield({ type = "begin", session = token, generation = gen, length = reaper.GetProjectLength(proj), defaultItemColor = string.format("#%02x%02x%02x", r, g, b), trackCount = reaper.CountTracks(proj) })
    local records = json.array()
    local function add(record)
      records[#records + 1] = record

      if #records >= 256 then
        coroutine.yield({ type = "chunk", session = token, generation = gen, records = records })
        records = json.array()
      end
    end

    for i = 0, reaper.CountTracks(proj) - 1 do
      local track = reaper.GetTrack(proj, i)
      if not track then changed = -1 return end

      local id = reaper.GetTrackGUID(track)
      add({ kind = "track", index = i + 1, id = id, pinned = reaper.GetMediaTrackInfo_Value(track, "B_TCPPIN") ~= 0, spacer = reaper.GetMediaTrackInfo_Value(track, "I_SPACER") ~= 0 })
      track = reaper.GetTrack(proj, i)

      if not track or reaper.GetTrackGUID(track) ~= id then changed = -1 return end
      local item_count = reaper.CountTrackMediaItems(track)

      for j = 0, item_count - 1 do
        track = reaper.GetTrack(proj, i)
        if not track or reaper.GetTrackGUID(track) ~= id or reaper.CountTrackMediaItems(track) ~= item_count then changed = -1 return end
        local item = reaper.GetTrackMediaItem(track, j)
        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        add({ kind = "item", track = i + 1, start = position, finish = position + length, color = color(reaper.GetDisplayedMediaItemColor(item)) })
      end
    end

    if #records > 0 then coroutine.yield({ type = "chunk", session = token, generation = gen, records = records }) end
    coroutine.yield({ type = "end", session = token, generation = gen, length = reaper.GetProjectLength(proj) })
  end)
end

function command(message)
  local ok, data = pcall(json.decode, message)
  if not ok or type(data) ~= "table" then return end

  if data.type == "ready" then
    if editor_window then reaper.ReaWeb_Close(editor_window) end
    editor_window, editor_state, editor_ready, editor_action, editor_closed = nil, nil, false, nil, nil
    ready, worker, pending, changed, next_transport = true, nil, nil, -1, 0
    next_snapshot, label_dirty = 0, true
    sent_sequence, acknowledged_sequence, hello_dirty = 0, 0, true
    next_layout, last_layout = 0, nil
    pending_snap, pending_notice = nil, nil

    if resources[data.locale] then locale = data.locale end

    return
  end

  if not ready or data.session ~= session then return end

  if data.type == "ack" then
    if finite(data.sequence) and data.sequence % 1 == 0 and data.sequence > acknowledged_sequence and data.sequence <= sent_sequence then acknowledged_sequence = data.sequence end
    return
  end

  if data.type == "locale" and resources[data.locale] then
    locale = data.locale
    if editor_state then editor_state.language, editor_dirty = locale, true end
    return
  end

  if data.type == "history" then
    if data.action == "undo" or data.action == "redo" then history_step(data.action == "undo") end
  elseif data.type == "label-batch" then
    batch_labels(data)
  elseif data.type == "snap" and time(data.position) and finite(data.request) and finite(data.secondsPerPixel) and data.secondsPerPixel > 0
    and time(data.minimum) and time(data.maximum) and data.minimum <= data.position and data.position <= data.maximum then
    local ok, position = pcall(snap_grid, reaper, project, data.position, data.secondsPerPixel, data.minimum, data.maximum)
    if not ok or not time(position) then error_message("syncFailed") return end
    pending_snap = { type = "snap", session = session, request = data.request, position = position }
  elseif data.type == "settings-open" then
    settings_window = reaper.ReaWeb_Open(directory .. "settings.html", source, "settings")
    if settings_window == 0 then settings_window = nil error_message("settingsFailed") end
  elseif data.type == "settings-state" and type(data.state) == "table" then
    settings_state, settings_dirty = data.state, true
  elseif data.type == "editor-open" and type(data.state) == "table" and finite(data.state.request) then
    editor_state, editor_dirty, editor_action = data.state, true, nil
    editor_window = reaper.ReaWeb_Open(directory .. "editor.html", source, "editor")
    if editor_window == 0 then editor_window, editor_closed = nil, editor_state.request error_message("editorFailed") end
  elseif data.type == "editor-close" and editor_state and data.request == editor_state.request then
    if editor_window then reaper.ReaWeb_Close(editor_window) end
  elseif data.type == "refresh" then
    changed, next_snapshot = -1, 0
  elseif data.type == "transport" then
    if reaper.GetPlayStateEx(project) ~= 0 then reaper.OnStopButtonEx(project) else reaper.OnPlayButtonEx(project) end
    next_transport = 0
  elseif data.type == "seek" and time(data.position) then
    reaper.SetEditCurPos2(project, data.position, false, true)
    next_transport = 0
  elseif data.type == "view" and range(data.start, data.finish) then
    reaper.GetSet_ArrangeView2(project, true, 0, 0, data.start, data.finish)
    if finite(data.top) then
      local _, _, minimum, maximum = vertical_view()
      reaper.JS_Window_SetScrollPos(arrange, "v", math.floor(math.max(minimum, math.min(maximum, data.top)) + 0.5))
    end

    next_transport = 0
  elseif data.type == "label" then
    read_labels()

    if state_error then error_message("stateInvalid") return end
    if data.revision ~= revision then label_dirty = true error_message("conflict") return end
    local updated, found = json.array(), false

    for _, label in ipairs(labels) do
      if label.id == data.id then
        found = true
        if data.action ~= "delete" then
          if not range(data.start, data.finish) or not name_valid(data.name) or type(data.collapsed) ~= "boolean" or not color_valid(data.color) then error_message("invalidRange") return end
          updated[#updated + 1] = { id = label.id, start = data.start, finish = data.finish, name = data.name, collapsed = data.collapsed, color = data.color or label.color }
        end
      else updated[#updated + 1] = label end
    end

    if data.action == "create" then
      if #labels >= 512 then error_message("labelLimit") return end
      if not range(data.start, data.finish) or not name_valid(data.name) or not color_valid(data.color) then error_message("invalidRange") return end
      updated[#updated + 1] = { id = next_id, start = data.start, finish = data.finish, name = data.name, collapsed = false, color = data.color or "#718e86" }
      next_id = next_id + 1
    elseif not found or (data.action ~= "update" and data.action ~= "delete") then return end

    write_labels(updated)
  end
end

local function transport(now)
  local state = reaper.GetPlayStateEx(project)
  local a, b = reaper.GetSet_ArrangeView2(project, false, 0, 0, 0, 0)
  local loop_a, loop_b = reaper.GetSet_LoopTimeRange2(project, false, true, 0, 0, false)
  local selection_a, selection_b = reaper.GetSet_LoopTimeRange2(project, false, false, 0, 0, false)
  local cursor = reaper.GetCursorPositionEx(project)
  local top, height = vertical_view()
  send({ type = "transport", session = session, timestamp = now * 1000, playState = state,
    position = state & 1 == 1 and reaper.GetPlayPositionEx(project) or cursor, cursor = cursor,
    rate = reaper.Master_GetPlayRate(project), viewStart = a, viewEnd = b, viewTop = top, viewHeight = height,
    loopStart = loop_a, loopEnd = loop_b, repeatEnabled = reaper.GetSetRepeatEx(project, -1) == 1,
    selectionStart = selection_a, selectionEnd = selection_b, snapEnabled = reaper.GetToggleCommandStateEx(0, 1157) == 1 })
end

function poll_settings()
  if not settings_window then return end
  if not reaper.ReaWeb_IsOpen(settings_window) then settings_window, settings_ready, settings_actions = nil, false, {} return end
  if not reaper.ReaWeb_IsReady(settings_window) then settings_ready = false return end

  for _ = 1, 16 do
    local raw = reaper.ReaWeb_Receive(settings_window)
    if raw == "" then break end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == "table" then
      if data.type == "settings-ready" then settings_ready, settings_dirty, settings_request = true, true, true
      elseif data.type == "settings-action" and data.session == session and #settings_actions < 16 then
        settings_actions[#settings_actions + 1] = { type = "settings-action", session = session, action = data.action, value = data.value, revision = data.revision }
      end
    end
  end

  if settings_request and send({type = "settings-request", session = session}) then settings_request = false end
  if settings_actions[1] and send(settings_actions[1]) then table.remove(settings_actions, 1) end
  if settings_ready and settings_dirty and settings_state then
    if reaper.ReaWeb_Send(settings_window, json.encode({type = "settings-state", session = session, state = settings_state})) then settings_dirty = false end
  end
end

function poll_editor()
  if editor_window then
    if not reaper.ReaWeb_IsOpen(editor_window) then
      editor_closed = editor_state and editor_state.request
      editor_window, editor_ready, editor_state, editor_action = nil, false, nil, nil
    elseif reaper.ReaWeb_IsReady(editor_window) then
      for _ = 1, 16 do
        local raw = reaper.ReaWeb_Receive(editor_window)
        if raw == "" then break end
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == "table" then
          if data.type == "editor-ready" then editor_ready, editor_dirty = true, true
          elseif data.type == "editor-action" and editor_state and data.session == session and data.request == editor_state.request then
            editor_action = { type = "editor-action", session = session, request = data.request, action = data.action, value = data.value }
          end
        end
      end

      if editor_ready and editor_dirty and editor_state and reaper.ReaWeb_Send(editor_window, json.encode({type = "editor-state", session = session, state = editor_state})) then editor_dirty = false end
    else editor_ready = false end
  end

  if editor_action and send(editor_action) then editor_action = nil end
  if editor_closed and send({type = "editor-closed", session = session, request = editor_closed}) then editor_closed = nil end
end

function loop()
  if not reaper.ReaWeb_IsOpen(window) then return end
  local current = reaper.EnumProjects(-1)

  if current ~= project then
    project, session, raw_state, changed = current, session + 1, nil, -1
    worker, pending, next_snapshot, next_transport = nil, nil, 0, 0
    sent_sequence, acknowledged_sequence, hello_dirty, pending_error = 0, 0, true, nil
    next_layout, last_layout = 0, nil
    pending_snap, pending_notice = nil, nil
    settings_state, settings_actions = nil, {}

    if editor_window then reaper.ReaWeb_Close(editor_window) end
    editor_window, editor_state, editor_ready, editor_action, editor_closed = nil, nil, false, nil, nil

    read_labels()
  end

  if not reaper.ReaWeb_IsReady(window) then ready = false worker, pending = nil, nil end

  for _ = 1, 32 do
    local message = reaper.ReaWeb_Receive(window)
    if message == "" then break end
    if #message <= 8192 then command(message) end
  end

  poll_settings()
  poll_editor()

  if ready then
    local now = reaper.time_precise()

    if hello_dirty and send({ type = "hello", session = session, languages = languages }) then hello_dirty = false end
    if pending_error and send({ type = "error", session = session, code = pending_error }) then pending_error = nil end
    if now >= next_labels then read_labels() next_labels = now + 0.25 end
    if label_dirty then publish_labels() end
    if pending_snap and send(pending_snap) then pending_snap = nil end
    if pending_notice and send(pending_notice) then pending_notice = nil end
    if now >= next_layout then publish_layout() next_layout = now + 0.1 end
    if now >= next_transport then transport(now) next_transport = now + 1 / 30 end
    local count = reaper.GetProjectStateChangeCount(project)
    if not worker and now >= next_snapshot and (count ~= changed or now >= rescan_at) then start_snapshot(now, count) end

    local deadline = reaper.time_precise() + 0.003
  
    for _ = 1, 4 do
      if not worker or reaper.time_precise() > deadline then break end

      if not pending then
        local ok, message = coroutine.resume(worker)
        if not ok then worker = nil error_message("syncFailed") changed = -1 break end
        pending = message
      end

      if not pending then worker = nil break end
      if not send(pending) then break end

      pending = nil
    end
  end

  reaper.defer(loop)
end
loop()
