-- @noindex
-- @description ReaWebAPI Demo (Lua backend)
local reaper = reaper
local bridge_apis = {
  "ReaWeb_Open", "ReaWeb_Close", "ReaWeb_IsOpen", "ReaWeb_IsReady",
  "ReaWeb_Send", "ReaWeb_Receive", "ReaWeb_GetDiagnostics", "ReaWeb_GetLastError",
  "ReaWeb_SetFrame",
}
for _, name in ipairs(bridge_apis) do
  if not reaper.APIExists(name) then
    reaper.MB("Install ReaWebAPI v0.3.9.12 or later and restart REAPER.", "ReaWebAPI", 0)
    return
  end
end

local instance_key = debug.getinfo(1, "S").source
local directory = instance_key:sub(2):match("^(.*[/\\])")
local window = reaper.ReaWeb_Open(directory .. "index.html", instance_key)
if window == 0 then
  reaper.MB(reaper.ReaWeb_GetLastError(), "ReaWebAPI", 0)
  return
end
-- C++ reuses the window; ExtState prevents a second Lua polling loop.
local backend_section = "ReaWebAPI.Backends"
if tonumber(reaper.GetExtState(backend_section, instance_key)) == window then return end
reaper.SetExtState(backend_section, instance_key, tostring(window), false)
reaper.atexit(function()
  reaper.ReaWeb_Close(window)
  if reaper.GetExtState(backend_section, instance_key) == tostring(window) then
    reaper.DeleteExtState(backend_section, instance_key, false)
  end
end)

-- Only plain values cross the bridge. Native project/track pointers stay in Lua.
local array_mt = {}
local function array(values) return setmetatable(values or {}, array_mt) end
local escapes = { ['"'] = '\\"', ['\\'] = '\\\\' }
local function json_string(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
    return escapes[c] or string.format('\\u%04x', c:byte())
  end) .. '"'
end
local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function json(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "string" then return json_string(value) end
  if kind == "boolean" then return tostring(value) end
  if kind == "number" then
    assert(finite(value), "Cannot send a non-finite number")
    return (string.format("%.17g", value):gsub(",", "."))
  end
  assert(kind == "table", "Only plain data can be sent to the WebView")
  local parts = {}
  if getmetatable(value) == array_mt then
    for _, item in ipairs(value) do parts[#parts + 1] = json(item) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do parts[#parts + 1] = json_string(key) .. ":" .. json(value[key]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

local project, master_guid, selected_track, selected_guid
local epoch, selection = 0, 0
local session, previous = nil, nil
local received, sent, state_skipped, write_skipped, last_send_error = 0, 0, 0, 0, ""
local frames_written, frame_error = 0, ""
local function update_context()
  local current = reaper.EnumProjects(-1)
  local master = reaper.GetTrackGUID(reaper.GetMasterTrack(current))
  -- The master GUID also changes when a project is replaced in the same tab.
  if current ~= project or master ~= master_guid then
    project, master_guid = current, master
    epoch, selection = epoch + 1, selection + 1
    selected_track, selected_guid = nil, nil
  end
  local track = reaper.GetSelectedTrack(project, 0)
  local guid = track and reaper.GetTrackGUID(track) or nil
  if track ~= selected_track or guid ~= selected_guid then
    selected_track, selected_guid = track, guid
    selection = selection + 1
  end
end
local function snapshot()
  update_context()
  local state = {
    epoch = epoch, selection = selection, changeCount = reaper.GetProjectStateChangeCount(project),
    count = reaper.CountTracks(project), track = false, version = reaper.GetAppVersion(),
  }
  if selected_track then
    local _, name = reaper.GetTrackName(selected_track)
    local color = reaper.GetTrackColor(selected_track)
    local r, g, b = reaper.ColorFromNative(color)
    state.track = {
      id = selected_guid, name = name, pan = reaper.GetMediaTrackInfo_Value(selected_track, "D_PAN"),
      volume = reaper.GetMediaTrackInfo_Value(selected_track, "D_VOL"),
      color = color, hex = color == 0 and "#b7f58a" or string.format("#%02x%02x%02x", r, g, b),
    }
  end
  return state
end
local function project_snapshot()
  local cursor = reaper.GetCursorPositionEx(project)
  local beat, bar, beats_per_bar, _, denominator = reaper.TimeMap2_timeToBeats(project, cursor)
  local total, markers, regions = reaper.CountProjectMarkers(project)
  local rows = array()
  for i = 0, math.min(total, 12) - 1 do
    local ok, region, start_pos, end_pos, name, number = reaper.EnumProjectMarkers3(project, i)
    if ok ~= 0 then
      rows[#rows + 1] = { region = region, start = start_pos, finish = end_pos, name = name, number = number }
    end
  end
  return {
    name = reaper.GetProjectName(project), cursor = cursor, position = reaper.GetPlayPositionEx(project),
    playState = reaper.GetPlayStateEx(project), tempo = reaper.Master_GetTempo(),
    beat = beat, bar = bar, beatsPerBar = beats_per_bar, denominator = denominator,
    total = total, markers = markers, regions = regions, rows = rows,
  }
end
local function track_fx()
  local count = reaper.TrackFX_GetCount(selected_track)
  local rows = array()
  for fx = 0, math.min(count, 16) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(selected_track, fx)
    local params = reaper.TrackFX_GetNumParams(selected_track, fx)
    local row = { name = ok and name or "(FX unavailable)", params = params }
    if params > 0 then row.value, row.min, row.max = reaper.TrackFX_GetParam(selected_track, fx, 0) end
    rows[#rows + 1] = row
  end
  local _, name = reaper.GetTrackName(selected_track)
  return { name = name, count = count, rows = rows }
end
local function with_undo(label, fn)
  -- Complete each Undo block in this invocation; never leave it open across defer.
  reaper.Undo_BeginBlock2(project)
  local ok, result = pcall(fn)
  reaper.Undo_EndBlock2(project, label, 1)
  if not ok then error(result, 0) end
  reaper.UpdateArrange()
  return result
end

local function execute(command, value, requested_epoch, requested_selection)
  update_context()
  if command == "ready" then return { project = project_snapshot() } end
  if command == "console" then
    reaper.ShowConsoleMsg(value .. "\n")
    return {}
  end
  if command == "diagnostics" then
    return {
      runtime = reaper.ReaWeb_GetDiagnostics(window), backend = "Lua / reaper.defer + extension frame timer",
      frameWrites = frames_written, frameError = frame_error, maxMessagesPerTick = 32,
      received = received, sent = sent, stateSkipped = state_skipped, writeSkipped = write_skipped,
      lastSendError = last_send_error, reaperVersion = reaper.GetAppVersion(),
    }
  end
  if requested_epoch ~= epoch then error("Project changed. Read the current project and try again.", 0) end
  if command == "project" then return project_snapshot() end
  if command == "cursor" then
    local value_number = tonumber(value)
    assert(finite(value_number), "Enter a finite time in seconds.")
    reaper.SetEditCurPos2(project, value_number, true, false)
    return project_snapshot()
  end
  if requested_selection ~= selection then error("Track selection changed. Try again on the current track.", 0) end
  if not selected_track or not reaper.ValidatePtr2(project, selected_track, "MediaTrack*") then
    error("Select a track first.", 0)
  end
  if command == "fx" then return track_fx() end
  if command == "volume" or command == "reset-volume" then
    local volume = command == "reset-volume" and 1 or tonumber(value)
    -- The UI uses dB; D_VOL takes linear amplitude (1 = 0 dB, 0 = silence).
    assert(finite(volume) and volume >= 0 and volume <= 4, "Volume must be between silence and +12 dB.")
    local function write()
      assert(reaper.SetMediaTrackInfo_Value(selected_track, "D_VOL", volume), "REAPER rejected the volume update.")
    end
    if command == "reset-volume" then with_undo("ReaWebAPI: reset track volume", write)
    else write(); reaper.UpdateArrange() end
    local actual = reaper.GetMediaTrackInfo_Value(selected_track, "D_VOL")
    assert(math.abs(actual - volume) < 0.000001, "Volume readback differs from the requested value.")
    return { volume = actual }
  end
  if command == "pan" or command == "center-pan" then
    local pan = command == "center-pan" and 0 or tonumber(value)
    assert(finite(pan) and pan >= -1 and pan <= 1, "Pan must be between -1 and 1.")
    local function write()
      assert(reaper.SetMediaTrackInfo_Value(selected_track, "D_PAN", pan), "REAPER rejected the Pan update.")
    end
    if command == "center-pan" then with_undo("ReaWebAPI: center track pan", write)
    else write(); reaper.UpdateArrange() end
    local actual = reaper.GetMediaTrackInfo_Value(selected_track, "D_PAN")
    assert(math.abs(actual - pan) < 0.000001, "Pan readback differs from the requested value.")
    return { pan = actual }
  end
  if command == "color" or command == "reset-color" then
    local native = 0
    if command == "color" then
      assert(value:match("^#%x%x%x%x%x%x$"), "Expected a six-digit RGB color.")
      native = reaper.ColorToNative(tonumber(value:sub(2, 3), 16), tonumber(value:sub(4, 5), 16), tonumber(value:sub(6, 7), 16))
    end
    with_undo("ReaWebAPI: track color", function()
      -- SetTrackColor(track, 0) means black; I_CUSTOMCOLOR = 0 restores the default.
      if command == "reset-color" then
        assert(reaper.SetMediaTrackInfo_Value(selected_track, "I_CUSTOMCOLOR", 0), "REAPER rejected the color reset.")
      else reaper.SetTrackColor(selected_track, native) end
    end)
    local actual = reaper.GetTrackColor(selected_track)
    assert(actual == (command == "reset-color" and 0 or (native | 0x1000000)), "Track color readback differs from the requested value.")
    return { color = actual }
  end
  error("Unknown demo command: " .. command, 0)
end

local function send(value)
  if reaper.ReaWeb_Send(window, json(value)) then
    sent = sent + 1
    return true
  end
  last_send_error = reaper.ReaWeb_GetLastError()
  return false
end
-- Continuous controls are written many times per gesture. Answering each step
-- with a full snapshot cost about ten REAPER reads per step on top of the write.
-- The page already receives the same content through the frame channel, so these
-- replies carry only the confirmed value. Every other command still returns state.
local continuous = { volume = true, pan = true }
-- UI -> Lua: session TAB requestId TAB command TAB epoch TAB selection TAB value.
-- Only the first five tabs are separators, so console text can contain tabs/newlines.
-- Lua -> UI: JSON responses and state. No JSON decoder or JS API mirror is needed.
local function parse(message)
  local client, request_id, command, requested_epoch, requested_selection, value =
    message:match("^([%w%-]+)\t(%d+)\t([%w%-]+)\t(%d+)\t(%d+)\t(.*)$")
  if not client then return nil end
  return {
    client = client, id = tonumber(request_id), command = command,
    epoch = tonumber(requested_epoch), selection = tonumber(requested_selection), value = value,
  }
end
-- Every request is answered exactly once, because the page counts outstanding
-- requests and waits for all of them. A drag step that a newer step of the same
-- control replaced is answered without touching REAPER: the write it asked for
-- is already obsolete, and skipping it saves a track write plus an arrange redraw
-- while the pointer is still moving.
local function handle_message(request, superseded)
  if request.command == "ready" then
    session, previous = request.client, nil
  elseif request.client ~= session then return end
  received = received + 1
  local response = { type = "response", session = request.client, id = request.id, ok = true }
  if superseded then
    response.data = { superseded = true }
    write_skipped = write_skipped + 1
  else
    local ok, result = pcall(execute, request.command, request.value, request.epoch, request.selection)
    response.ok = ok
    if ok then response.data = result else response.error = tostring(result) end
    -- A drag step is already on screen and already in the frame channel, so
    -- repeating the whole state in its reply only costs REAPER reads.
    if ok and continuous[request.command] then
      state_skipped = state_skipped + 1
    elseif request.command ~= "console" then
      response.state = snapshot()
    end
  end
  send(response)
end
local function tick()
  -- A drag can leave several steps of one control waiting in the queue. Applying
  -- every step costs a track write plus an arrange redraw each, and only the last
  -- value is visible, so a batch keeps the newest step per control and answers the
  -- rest as superseded. Other commands keep their order.
  local batch, newest = {}, {}
  for _ = 1, 32 do
    local message = reaper.ReaWeb_Receive(window)
    if message == "" then break end
    local request = parse(message)
    -- Unparseable text is ignored, exactly as before.
    if request then
      batch[#batch + 1] = request
      -- Only this window's own steps compete with each other. Counting a step
      -- from any other document would drop the step this window is waiting for.
      if continuous[request.command] and request.client == session then
        newest[request.command] = #batch
      end
    end
  end
  for index, request in ipairs(batch) do
    -- Only the last step of a control in this batch reaches REAPER; the earlier
    -- ones still get a reply, so the page stops waiting for them.
    local superseded = continuous[request.command] and request.client == session
      and newest[request.command] ~= index
    handle_message(request, superseded)
  end
  -- Hand the current content to the extension on every pass. The extension owns
  -- the frame rate and pushes it to the page on its own timer, so the page keeps
  -- refreshing even when this loop is between defers. Replacing is enough: the
  -- previous content stays on screen until a newer one arrives, so no queue and
  -- no per-pass send are needed. The state is read and encoded on every pass;
  -- only a change is written, so the extension is not asked to replace identical
  -- content.
  if session and reaper.ReaWeb_IsReady(window) then
    local encoded = json(snapshot())
    if encoded ~= previous then
      if reaper.ReaWeb_SetFrame(window, encoded) then
        previous = encoded
        frames_written = frames_written + 1
        frame_error = ""
      else
        frame_error = reaper.ReaWeb_GetLastError()
      end
    end
  end
end
local function loop()
  if not reaper.ReaWeb_IsOpen(window) then return end
  local ok, err = pcall(tick)
  if not ok then
    reaper.MB("Lua backend stopped:\n" .. tostring(err), "ReaWebAPI Demo", 0)
    return
  end
  reaper.defer(loop)
end
loop()
