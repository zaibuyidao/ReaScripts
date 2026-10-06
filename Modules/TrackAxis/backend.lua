-- @noindex
return function(r, json, send)
  local M, project, session = {}, nil, 0
  local ready, previous, next_tick, next_detail, next_index = false, {}, 0, 0, 0
  local last_change, index_dirty, force = -1, true, true
  local selected_fx, catalog = nil, nil
  local gesture, editing_message, gesture_time = nil, nil, 0
  local next_theme = 0
  local record_cache = {}
  local mode = "track"
  local section = "ReaWebAPI.TrackAxis"
  local A, null = json.array, json.null

  local track_fields = {
    fxEnabled = {"I_FXEN", 0, 1, true},
    volume = {"D_VOL", 0, 4}, pan = {"D_PAN", -1, 1}, width = {"D_WIDTH", -1, 1},
    panMode = {"I_PANMODE", -1, 6, true}, panLeft = {"D_DUALPANL", -1, 1}, panRight = {"D_DUALPANR", -1, 1},
    mute = {"B_MUTE", 0, 1, true}, solo = {"I_SOLO", 0, 2, true}, arm = {"I_RECARM", 0, 1, true},
    monitor = {"I_RECMON", 0, 2, true}, monitorItems = {"I_RECMONITEMS", 0, 1, true}, phase = {"B_PHASE", 0, 1, true},
    automation = {"I_AUTOMODE", 0, 5, true}, input = {"I_RECINPUT", -1, 16383, true},
    recordMode = {"I_RECMODE", 0, 16, true}, mainSend = {"B_MAINSEND", 0, 1, true},
    channels = {"I_NCHAN", 2, 128, true}, tcp = {"B_SHOWINTCP", 0, 1, true}, mcp = {"B_SHOWINMIXER", 0, 1, true},
  }

  local item_fields = {
    position = {"D_POSITION", 0, 1e9}, length = {"D_LENGTH", 0.000001, 1e9},
    mute = {"B_MUTE", 0, 1, true}, lock = {"C_LOCK", 0, 1, true}, loop = {"B_LOOPSRC", 0, 1, true},
  }

  local take_fields = {rate = {"D_PLAYRATE", 0.01, 16}, pitch = {"D_PITCH", -120, 120}, offset = {"D_STARTOFFS", 0, 1e9}}
  local function fail(code) error(code, 0) end
  local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
  local function bounded(n, spec)
    return finite(n) and n >= spec[2] and n <= spec[3] and (not spec[4] or n % 1 == 0)
  end

  local function text(s, limit) return type(s) == "string" and #s <= limit and not s:find("%z") and utf8.len(s) ~= nil end
  local function guid(track) return r.GetTrackGUID(track) end
  local function name(track) local _, s = r.GetTrackName(track) return s end
  local function value(track, field) return r.GetMediaTrackInfo_Value(track, field) end

  local function track_ref(track)
    if not track then return null end

    return {guid = guid(track), name = name(track), number = value(track, "IP_TRACKNUMBER")}
  end

  local function aggregate_track(track)
    if value(track, "I_FOLDERDEPTH") > 0 then return true end

    for i = 0, r.GetTrackNumSends(track, -1) - 1 do
      if r.GetTrackSendInfo_Value(track, -1, i, "I_SRCCHAN") >= 0 then
        return true
      end
    end

    return false
  end

  local function selection()
    if mode == "master" then
      local track = r.GetMasterTrack(project)
      return {track}, "master:" .. guid(track), {[track] = true}
    end
    local tracks, ids, set = {}, {}, {}

    for i = 0, r.CountSelectedTracks(project) - 1 do
      local track = r.GetSelectedTrack(project, i)
      tracks[#tracks + 1], ids[#ids + 1], set[track] = track, guid(track), true
    end

    return tracks, table.concat(ids, "|"), set
  end

  local function items_for(set)
    local items, ids = {}, {}
    if mode == "master" then return items, "" end

    for i = 0, r.CountSelectedMediaItems(project) - 1 do
      local item = r.GetSelectedMediaItem(project, i)

      if set[r.GetMediaItemTrack(item)] then
        local _, id = r.GetSetMediaItemInfo_String(item, "GUID", "", false)
        local take = r.GetActiveTake(item)
        local take_id = ""
        if take then _, take_id = r.GetSetMediaItemTakeInfo_String(take, "GUID", "", false) end
        items[#items + 1], ids[#ids + 1] = item, id .. ":" .. take_id
      end
    end

    return items, table.concat(ids, "|")
  end

  local function common(objects, read)
    if #objects == 0 then return {}, {} end
    local result, mixed = read(objects[1]), {}

    for i = 2, #objects do
      local other = read(objects[i])

      for k, v in pairs(result) do
        local equal = type(v) == "number" and type(other[k]) == "number" and math.abs(v - other[k]) < 1e-9 or v == other[k]
        if not equal then result[k], mixed[k] = null, true end
      end
    end

    return result, mixed
  end

  local function color(track)
    local native = r.GetTrackColor(track)
    if native == 0 then return "" end
    local red, green, blue = r.ColorFromNative(native)

    return string.format("#%02x%02x%02x", red, green, blue)
  end

  local function track_line(chunk, key, replacement)
    local depth, found = 0, nil
    local updated = chunk:gsub("[^\r\n]+", function(line)
      if depth == 1 and line:match("^" .. key .. "%s") then
        found = line:sub(#key + 2)
        if replacement then return key .. " " .. replacement end
      end

      if line:match("^<") then
        depth = depth + 1
      elseif line == ">" then
        depth = depth - 1
      end

      return line
    end)

    return found, updated
  end

  local function record_values(track)
    local key, revision = guid(track), r.GetProjectStateChangeCount(project)
    local cached = record_cache[key]
    if cached and cached.revision == revision and cached.session == session then return cached end
    local ok, chunk = r.GetTrackStateChunk(track, "", false)
    if not ok then return {preservePDC = null, midiMap = null} end

    local rec = track_line(chunk, "REC") or ""
    local fields = {} for field in rec:gmatch("%S+") do fields[#fields+1] = tonumber(field) end
    local map = tonumber((track_line(chunk, "MIDI_INPUT_CHANMAP"))) or -1
    cached = {revision = revision, session = session, preservePDC = fields[6] or 0, midiMap = map + 1}
    record_cache[key] = cached

    return cached
  end

  local function track_values(track)
    local _, icon = r.GetSetMediaTrackInfo_String(track, "P_ICON", "", false)
    local result = {color = color(track), name = name(track), icon = icon or ""}

    for k, field in pairs(track_fields) do
      result[k] = value(track, field[1])
    end

    if mode == "master" then result.mono = r.GetToggleCommandState(40917) == 1 and 1 or 0 end

    local recording = record_values(track)
    result.preservePDC, result.midiMap = recording.preservePDC, recording.midiMap
    result.recordOutput = value(track,"I_RECMODE_FLAGS") & 3
    result.recordLatency = result.recordMode == 3 or result.recordMode == 6 or result.recordMode == 11
    result.panModeEffective = result.panMode

    if result.panMode == -1 and r.GetTrackUIPan then
      local _, _, _, mode = r.GetTrackUIPan(track) result.panModeEffective = mode
    end

    if result.icon ~= "" and not result.icon:match("^[/\\]") and not result.icon:match("^%a:[/\\]") then
      result.icon = r.GetResourcePath() .. (result.icon:match("^Data[/\\]") and "/" or "/Data/track_icons/") .. result.icon
    end

    return result
  end

  local function theme_colors()
    local colors = {}

    if r.GetThemeColor then
      for _, key in ipairs({"col_main_bg", "col_main_text", "col_main_bg2", "col_main_text2", "col_main_editbk", "col_buttonbg", "col_main_3dsh", "genlist_selbg", "genlist_selfg"}) do
        local native = r.GetThemeColor(key, 0)

        if native ~= -1 and not (key == "col_buttonbg" and native == 0) then
          local red, green, blue = r.ColorFromNative(native)
          colors[key] = string.format("#%02x%02x%02x", red & 255, green & 255, blue & 255)
        end
      end
    end

    if r.GSC_mainwnd then
      local face, text = r.GSC_mainwnd(15), r.GSC_mainwnd(18)

      if (face & 0xffffff) ~= (text & 0xffffff) then
        for key, native in pairs({buttonface = face, buttontext = text}) do
          local red, green, blue = r.ColorFromNative(native)
          colors[key] = string.format("#%02x%02x%02x", red & 255, green & 255, blue & 255)
        end
      end
    end

    return {available = next(colors) ~= nil, colors = colors}
  end

  local function metadata(track)
    local _, raw = r.GetProjExtState(project, section, guid(track))
    if raw == "" then return {version = 1, notes = "", category = "", status = "", tags = ""} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" or data.version ~= 1 then return nil end

    for _, k in ipairs({"notes", "category", "status", "tags"}) do
      if not text(data[k], 32768) then
        return nil
      end
    end

    return data
  end

  local function emit(part, data)
    local encoded = json.encode(data)
    if previous[part] ~= encoded and send({type = "state", part = part, session = session, data = data}) then previous[part] = encoded end
  end

  local function route_key(rows)
    local hash = 2166136261
    local raw = json.encode(rows)
    for i = 1, #raw do hash = ((hash ~ raw:byte(i)) * 16777619) & 0xffffffff end

    return string.format("%08x", hash)
  end

  local function end_gesture()
    if gesture then r.Undo_OnStateChangeEx2(gesture.project, "TrackAxis: " .. gesture.label, -1, -1) gesture = nil end
  end

  local function check_project(reloaded)
    local active = r.EnumProjects(-1, "")

    if reloaded or project ~= active then
      end_gesture()
      project, session = active, session + 1
      previous, selected_fx = {}, nil
      next_tick, next_detail, next_index, last_change = 0, 0, 0, -1
      force, index_dirty = true, true
    end
  end

  local function hardware_output_name(channel)
    local index, mono = channel & 1023, (channel & 1024) ~= 0
    if index + (mono and 1 or 2) > r.GetNumAudioOutputs() then return nil end
    local first = r.GetOutputChannelName(index)
    if not first or first == "" then return nil end
    if mono then return first end
    local second = r.GetOutputChannelName(index + 1)
    if not second or second == "" then return nil end

    return first .. " / " .. second
  end

  local function hardware_outputs()
    local rows, count = A(), math.min(1024, r.GetNumAudioOutputs())

    for i = 0, count - 2 do
      local name = hardware_output_name(i)
      if name then rows[#rows + 1] = {value = i, label = (i + 1) .. ": " .. name} end
    end

    for i = 0, count - 1 do
      local name = hardware_output_name(1024 + i)
      if name then rows[#rows + 1] = {value = 1024 + i, label = (i + 1) .. ": " .. name} end
    end

    return rows
  end

  local function valid_output(channel)
    if not finite(channel) or channel % 1 ~= 0 then return false end

    for _, output in ipairs(hardware_outputs()) do
      if output.value == channel then return true end
    end

    return false
  end

  local function routes(track, categories)
    local rows = A()

    for _, category in ipairs(categories or (mode == "master" and {1} or {0, -1})) do
      for i = 0, r.GetTrackNumSends(track, category) - 1 do
        local function get(field) return r.GetTrackSendInfo_Value(track, category, i, field) end
        local destination = get("I_DSTCHAN")
        local output_name

        if category == 1 then
          output_name = hardware_output_name(destination)

          if not output_name then
            local _, fallback = r.GetTrackSendName(track, i, "")
            output_name = fallback
          end
        end
        rows[#rows + 1] = {
          index = i, category = category, name = output_name,
          peer = category == 1 and null or track_ref(get(category == 0 and "P_DESTTRACK" or "P_SRCTRACK")),
          volume = get("D_VOL"), pan = get("D_PAN"), mute = get("B_MUTE"),
          phase = get("B_PHASE"), mono = get("B_MONO"),
          mode = get("I_SENDMODE"), sourceChannels = get("I_SRCCHAN"), destinationChannels = destination, midi = get("I_MIDIFLAGS"),
        }
      end
    end

    return rows
  end

  local function fx_index(track, id)
    for i = 0, r.TrackFX_GetCount(track) - 1 do
      if r.TrackFX_GetFXGUID(track, i) == id then
        return i
      end
    end

    return nil
  end
 
  local function fx_state(track)
    local rows = A()

    for i = 0, r.TrackFX_GetCount(track) - 1 do
      local _, fxname = r.TrackFX_GetFXName(track, i)
      local ok, preset = r.TrackFX_GetPreset(track, i)
      rows[#rows + 1] = {guid = r.TrackFX_GetFXGUID(track, i), index = i, name = fxname,
        enabled = r.TrackFX_GetEnabled(track, i), offline = r.TrackFX_GetOffline(track, i), preset = ok and preset or ""}
    end

    return rows
  end

  local function parameters(track)
    local i = track and selected_fx and fx_index(track, selected_fx)

    if not i then
      selected_fx = nil
      return {guid = null, rows = A(), total = 0}
    end

    local total, rows = r.TrackFX_GetNumParams(track, i), A()

    for p = 0, total - 1 do
      local _, pname = r.TrackFX_GetParamName(track, i, p)
      local _, formatted = r.TrackFX_GetFormattedParamValue(track, i, p)
      rows[#rows + 1] = {index = p, name = pname, value = r.TrackFX_GetParamNormalized(track, i, p), formatted = formatted}
    end

    return {guid = selected_fx, rows = rows, total = total}
  end

  local function item_values(item)
    local result = {}

    for k, field in pairs(item_fields) do
      local n = r.GetMediaItemInfo_Value(item, field[1])
      result[k] = k == "lock" and (math.floor(n) & 1) or n
    end

    local take = r.GetActiveTake(item)
    for k, field in pairs(take_fields) do
      result[k] = take and r.GetMediaItemTakeInfo_Value(take, field[1]) or null
    end
    local _, tname = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    result.takeName = tname
    result.takeCount = r.CountTakes(item)

    return result
  end

  local function read_item(item)
    if r.GetActiveTake(item) then return
      item_values(item)
    end

    local result = {rate = null, pitch = null, offset = null, takeName = null, takeCount = r.CountTakes(item)}

    for k, field in pairs(item_fields) do
      local n = r.GetMediaItemInfo_Value(item, field[1]) result[k] = k == "lock" and (math.floor(n) & 1) or n
    end

    return result
  end

  local function source_info(item)
    local take = r.GetActiveTake(item)
    local src = take and r.GetMediaItemTake_Source(take)
    if not src then return null end

    local seen = {}

    while not seen[src] do
      seen[src] = true
      local parent = r.GetMediaSourceParent(src)

      if not parent then
        break
      end
  
      src = parent
    end

    local duration, qn = r.GetMediaSourceLength(src)
    local format = r.GetMediaSourceType(src)
    local path = r.GetMediaSourceFileName(src)

    return {path = path, format = format, sampleRate = r.GetMediaSourceSampleRate(src), channels = r.GetMediaSourceNumChannels(src),
      duration = duration, durationIsQN = qn, overview = path ~= "" and format ~= "MIDI" and format ~= "SECTION" and not qn}
  end

  local function inputs()
    local rows = {mono = A(), stereo = A(), midi = A()}
    local count = r.GetNumAudioInputs()

    for i = 0, count - 1 do
      rows.mono[#rows.mono + 1] = {value = i, label = r.GetInputChannelName(i)}
    end

    for i = 0, count - 2 do
      rows.stereo[#rows.stereo + 1] = {value = 1024 + i, label = r.GetInputChannelName(i) .. " / " .. r.GetInputChannelName(i + 1)}
    end

    rows.midi[#rows.midi + 1] = {value = 4096 + (63 << 5), label = "allMIDI", translated = true}

    for i = 0, math.min(61, r.GetNumMIDIInputs() - 1) do
      local ok, label = r.GetMIDIInputName(i, "")

      if ok then
        rows.midi[#rows.midi + 1] = {value = 4096 + (i << 5), label = label}
      end
    end

    rows.midi[#rows.midi + 1] = {value = 4096 + (62 << 5), label = "virtualMIDI", translated = true}
    return rows
  end

  local function undo(label, fn)
    local m = editing_message

    if m and m.gesture then
      if not text(m.gesture, 128) or m.gesture == "" then
        fail("invalidValue")
      end

      if gesture and gesture.id ~= m.gesture then
        end_gesture()
      end

      if not gesture then
        gesture = {id = m.gesture, project = project, key = m.selectionKey, label = label}
      end

      gesture_time = r.time_precise()
    else
      end_gesture() r.Undo_BeginBlock2(project)
    end

    r.PreventUIRefresh(1)
    local ok, err = pcall(fn)
    r.PreventUIRefresh(-1)

    if not m or not m.gesture then
      r.Undo_EndBlock2(project, "TrackAxis: " .. label, -1)
    end

    r.TrackList_AdjustWindows(false)
    r.UpdateArrange()

    if not ok then error(err, 0) end
  end

  local function resolve_track(id)
    for i = 0, r.CountTracks(project) - 1 do
      local t = r.GetTrack(project, i)
      if guid(t) == id then
        return t
      end
    end
  end

  local function command(m)
    check_project()

    if m.session ~= session then
      fail("staleState")
    end

    local action = m.action

    if action == "mode" then
      if m.value ~= "track" and m.value ~= "master" then
        fail("invalidValue")
      end

      if mode ~= m.value then
        end_gesture()
        mode, previous, selected_fx = m.value, {}, nil
        force, next_tick, next_detail = true, 0, 0
      end

      return
    end

    local tracks, key, set = selection()

    if action == "gestureEnd" then
      if gesture and gesture.id == m.gesture then end_gesture() end

      return
    end

    if gesture and (gesture.id ~= m.gesture or gesture.key ~= key) then
      end_gesture()
    end

    if action == "selectTrack" then
      if mode == "master" then fail("invalidValue") end
      local t = resolve_track(m.guid)
      if not t then fail("staleState") end
      r.SetOnlyTrackSelected(t)
      r.TrackList_AdjustWindows(false)

      return
    end

    if key ~= m.selectionKey or #tracks == 0 then fail("staleState") end
    local track = #tracks == 1 and tracks[1] or nil

    if mode == "master" then
      if action == "setTrack" then
        if not ({fxEnabled=true,volume=true,pan=true,width=true,panMode=true,panLeft=true,panRight=true,mute=true,solo=true,phase=true,mono=true,channels=true,automation=true})[m.field] then fail("invalidValue") end
      elseif action == "quick" then
        if m.operation ~= "chain" and m.operation ~= "master" and m.operation ~= "envelopes" then fail("invalidValue") end
      elseif not ({route=true,routeAdd=true,routeDelete=true,routeOpen=true,fx=true,fxAdd=true,fxSelect=true,fxCatalog=true,setMetadata=true})[action] then
        fail("invalidValue")
      end
    end

    if action == "setTrack" then
      if m.field == "mono" then
        if mode ~= "master" or not bounded(m.value,{nil,0,1,true}) then fail("invalidValue") end
        local current = r.GetToggleCommandState(40917) == 1 and 1 or 0
        if current ~= m.value then undo("Master mono",function() r.Main_OnCommand(40917,0) end) end

        return
      elseif m.field == "preservePDC" then
        if not bounded(m.value, {nil,0,1,true}) then fail("invalidValue") end
        undo("Preserve PDC", function() r.Main_OnCommand(m.value == 1 and 41921 or 41920,0) end)
        record_cache = {}

        return
      elseif m.field == "recordOutput" then
        if not bounded(m.value,{nil,0,2,true}) then fail("invalidValue") end

        undo("Record output mode",function()
          for _,t in ipairs(tracks) do r.SetMediaTrackInfo_Value(t,"I_RECMODE_FLAGS",(value(t,"I_RECMODE_FLAGS") & ~3) | m.value) end
        end)

        return
      elseif m.field == "recordLatency" then
        if not bounded(m.value,{nil,0,1,true}) then fail("invalidValue") end
        local modes = {[1]={1,3},[3]={1,3},[5]={5,6},[6]={5,6},[10]={10,11},[11]={10,11}}

        for _,t in ipairs(tracks) do if not modes[value(t,"I_RECMODE")] then fail("invalidValue") end end
        undo("Record output latency",function()
          for _,t in ipairs(tracks) do r.SetMediaTrackInfo_Value(t,"I_RECMODE",modes[value(t,"I_RECMODE")][m.value + 1]) end
        end)

        return
      elseif m.field == "midiMap" then
        if not bounded(m.value, {nil,0,16,true}) then fail("invalidValue") end
        local chunks = {}

        for i, t in ipairs(tracks) do
          local ok, chunk = r.GetTrackStateChunk(t,"",false)
          if not ok then fail("saveFailed") end
          local found, updated = track_line(chunk,"MIDI_INPUT_CHANMAP",tostring(m.value-1))
          chunks[i] = found and updated or chunk:gsub("\n", "\nMIDI_INPUT_CHANMAP " .. (m.value-1) .. "\n",1)
        end

        undo("MIDI input mapping", function()
          for i,t in ipairs(tracks) do if not r.SetTrackStateChunk(t,chunks[i],false) then fail("saveFailed") end end
        end)

        record_cache = {}

        return
      end

      local spec = track_fields[m.field]
      if not spec or not bounded(m.value, spec) or m.field == "channels" and m.value % 2 ~= 0 then
        fail("invalidValue")
      end

      if m.field == "panMode" and not ({[-1]=true,[3]=true,[5]=true,[6]=true})[m.value] then
        fail("invalidValue")
      end

      local changed = false

      for _, t in ipairs(tracks) do
        if math.abs(value(t, spec[1]) - m.value) > 1e-12 then
          changed = true
          break
        end
      end

      if not changed then return end
      undo(m.field, function() for _, t in ipairs(tracks) do r.SetMediaTrackInfo_Value(t, spec[1], m.value) end end)

    elseif action == "rename" then
      if not track or not text(m.value, 1024) then
        fail("invalidValue")
      end

      undo("Rename track", function() r.GetSetMediaTrackInfo_String(track, "P_NAME", m.value, true) end)
    elseif action == "color" then
      if type(m.value) ~= "string" or m.value ~= "" and not m.value:match("^#%x%x%x%x%x%x$") then
        fail("invalidValue")
      end

      local native = m.value == "" and 0 or (r.ColorToNative(tonumber(m.value:sub(2,3),16), tonumber(m.value:sub(4,5),16), tonumber(m.value:sub(6,7),16)) | 0x1000000)
      undo("Track color", function() for _, t in ipairs(tracks) do r.SetMediaTrackInfo_Value(t, "I_CUSTOMCOLOR", native) end end)
    elseif action == "setIcon" then
      if not text(m.path, 8192) or m.path ~= "" and (not m.path:lower():match("%.png$") and not m.path:lower():match("%.jpe?g$")) then
        fail("invalidValue")
      end

      if m.path ~= "" and not r.file_exists(m.path) then
        fail("iconUnavailable")
      end

      undo("Track icon", function() for _, t in ipairs(tracks) do r.GetSetMediaTrackInfo_String(t, "P_ICON", m.path, true) end end)
    elseif action == "setMetadata" then
      if not ({notes = true, category = true, status = true, tags = true})[m.field] or not text(m.value, m.field == "notes" and 32768 or 2048) then
        fail("invalidValue")
      end

      local entries = {}

      for i, t in ipairs(tracks) do
        entries[i] = metadata(t)
        if not entries[i] then
          fail("metadataInvalid")
        end
      end

      undo("Track metadata", function()
        for i, t in ipairs(tracks) do
          entries[i][m.field] = m.value
          if r.SetProjExtState(project, section, guid(t), json.encode(entries[i])) <= 0 then
            fail("saveFailed")
          end
        end
        r.MarkProjectDirty(project)
      end)

      index_dirty = true
    elseif action == "route" then
      if not track then fail("singleTrack") end
      local rows = routes(track)
      local expected = gesture and gesture.id == m.gesture and gesture.routeKey or m.routeKey
      if expected ~= route_key(rows) then fail("staleState") end

      local row
      for _, entry in ipairs(rows) do
        if entry.index == m.index and entry.category == m.category then
          row = entry
          break
        end
      end

      local spec = ({volume = {"D_VOL",0,4}, pan = {"D_PAN",-1,1}, mute = {"B_MUTE",0,1,true},
        phase = {"B_PHASE",0,1,true}, mono = {"B_MONO",0,1,true},
        mode = {"I_SENDMODE",0,8,true}, sourceChannels = {"I_SRCCHAN",-1,126,true}, destinationChannels = {"I_DSTCHAN",0,126,true}})[m.field]

      if m.category == 1 and (m.field == "sourceChannels" or m.field == "destinationChannels") then
        spec = {spec[1], m.field == "sourceChannels" and -1 or 0, 2047, true}
      end

      if not row or not spec or not bounded(m.value, spec) then fail("invalidValue") end

      if m.category == 1 then
        if m.field == "mode" and m.value == 8 then fail("invalidValue") end
        if m.field == "destinationChannels" and not valid_output(m.value) then fail("invalidValue") end
        if m.field == "sourceChannels" and m.value ~= -1 and (m.value & 1023) + (m.value >= 1024 and 1 or 2) > 128 then fail("invalidValue") end
      end

      if m.field == "mode" and not ({[0]=true,[1]=true,[3]=true,[8]=true})[m.value] then fail("invalidValue") end
      if m.category ~= 1 and (m.field == "sourceChannels" or m.field == "destinationChannels") and m.value ~= -1 and m.value % 2 ~= 0 then fail("invalidValue") end

      undo("Routing " .. m.field, function()
        if (m.field == "sourceChannels" or m.field == "destinationChannels") and m.value >= 0 then
          local endpoint, count

          if m.category == 1 then
            if m.field == "sourceChannels" then endpoint, count = track, (m.value & 1023) + (m.value >= 1024 and 1 or 2) end
          else
            endpoint = r.GetTrackSendInfo_Value(track, m.category, m.index, m.field == "sourceChannels" and "P_SRCTRACK" or "P_DESTTRACK")
            count = m.value + 2
          end

          if endpoint and value(endpoint, "I_NCHAN") < count then r.SetMediaTrackInfo_Value(endpoint, "I_NCHAN", math.ceil(count / 2) * 2) end
        end

        r.SetTrackSendInfo_Value(track, m.category, m.index, spec[1], m.value)
      end)

      if gesture and gesture.id == m.gesture then
        gesture.routeKey = route_key(routes(track))
      end
    elseif action == "routeDelete" or action == "routeOpen" then
      if not track or (mode == "master" and m.category ~= 1 or mode ~= "master" and m.category ~= 0 and m.category ~= -1) then
        fail("invalidValue")
      end

      local rows = routes(track)
      if m.routeKey ~= route_key(rows) then
        fail("staleState")
      end

      local found = false
      for _, row in ipairs(rows) do
        if row.category == m.category and row.index == m.index then
          found = true

          break
        end
      end

      if not found then
        fail("staleState")
      end

      if action == "routeOpen" then
        r.Main_OnCommand(mode == "master" and 42235 or 40293,0)

        return
      end

      undo("Delete routing", function() if not r.RemoveTrackSend(track, m.category, m.index) then fail("saveFailed") end end)
    elseif action == "routeAdd" then
      if mode == "master" then
        if m.category ~= 1 or not valid_output(m.output) then fail("invalidValue") end
        undo("Add hardware output", function()
          local i = r.CreateTrackSend(track, nil)
          if i < 0 then fail("saveFailed") end
          if not r.SetTrackSendInfo_Value(track, 1, i, "I_DSTCHAN", m.output) then fail("saveFailed") end
        end)

        return
      end

      local peer = resolve_track(m.peer)

      if not track or not peer or peer == track or (m.category ~= 0 and m.category ~= -1) then
        fail("invalidValue")
      end

      undo("Add routing", function()
        local src, dst = track, peer
        if m.category == -1 then src, dst = peer, track end
        if r.CreateTrackSend(src, dst) < 0 then fail("saveFailed") end
      end)
    elseif action == "setItem" then
      local items, item_key = items_for(set)
      if #items == 0 or m.itemKey ~= item_key then
        fail("staleState")
      end

      local spec = item_fields[m.field] or take_fields[m.field]
      if m.field == "takeName" then
        if not text(m.value, 1024) then
          fail("invalidValue")
        end
      elseif not spec or not bounded(m.value, spec) then
        fail("invalidValue")
      end

      if take_fields[m.field] or m.field == "takeName" then
        for _, item in ipairs(items) do
          if not r.GetActiveTake(item) then fail("noTake") end
        end
      end

      undo("Item " .. m.field, function()
        for _, item in ipairs(items) do
          local take = r.GetActiveTake(item)

          if m.field == "takeName" then
            r.GetSetMediaItemTakeInfo_String(take, "P_NAME", m.value, true)
          elseif take_fields[m.field] then
            r.SetMediaItemTakeInfo_Value(take, spec[1], m.value)
          elseif m.field == "lock" then
            local old = math.floor(r.GetMediaItemInfo_Value(item, "C_LOCK"))
            r.SetMediaItemInfo_Value(item, "C_LOCK", (old & ~1) | m.value)
          elseif m.field == "position" then
            r.SetMediaItemPosition(item, m.value, false)
          elseif m.field == "length" then
            r.SetMediaItemLength(item, m.value, false)
          else
            r.SetMediaItemInfo_Value(item, spec[1], m.value)
          end

          r.UpdateItemInProject(item)
        end
      end)
    elseif action == "fxSelect" then
      if not track or not fx_index(track, m.guid) then fail("staleState") end

      if type(m.visible) ~= "boolean" then
        fail("invalidValue")
      end

      if m.visible then
        selected_fx = m.guid
      elseif selected_fx == m.guid then
        selected_fx = nil
      end
    elseif action == "fxCatalog" then
      if not catalog then
        catalog = A()
        if r.APIExists("EnumInstalledFX") then
          for i = 0, 19999 do
            local ok, n, ident = r.EnumInstalledFX(i)
            if not ok then break end
            catalog[#catalog + 1] = {name = n, ident = ident}
          end
        end
      end

      local rows = A()
      for _, fx in ipairs(catalog) do
        rows[#rows + 1] = fx
      end

      local base, directories = r.GetResourcePath() .. "/FXChains/", 0
      local function chains(relative, depth)
        if depth > 16 or directories >= 4096 or #rows >= 40000 then return end
        directories = directories + 1
        local directory = base .. relative
        r.EnumerateFiles(directory, -1)

        for i = 0, 19999 do
          local file = r.EnumerateFiles(directory, i)

          if not file then break end
          if file:lower():match("%.rfxchain$") then rows[#rows + 1] = {name = relative .. file:sub(1, -10), ident = relative .. file, format = "FXCHAIN"} end
        end

        r.EnumerateSubdirectories(directory, -1)

        for i = 0, 4095 do
          local child = r.EnumerateSubdirectories(directory, i)
          if not child then break end

          if child ~= "." and child ~= ".." then
            chains(relative .. child .. "/", depth + 1)
          end
        end
      end

      chains("", 0)

      if not send({type = "catalog", session = session, rows = rows}) then
        fail("sendFailed")
      end

    elseif action == "fxAdd" then
      if not track or not text(m.name, 4096) or m.name == "" then fail("invalidValue") end
      local added

      undo("Add FX", function() added = r.TrackFX_AddByName(track, m.name, false, -1) if added < 0 then fail("fxNotFound") end end)
      r.TrackFX_Show(track, added, 3)
    elseif action == "fx" then
      local i = track and fx_index(track, m.guid)

      if not i then fail("staleState") end
      if m.operation == "open" then r.TrackFX_Show(track, i, 3) return end
      if m.operation == "toggleWindow" then
        if r.TrackFX_GetOpen(track, i) then
          -- The same FX can be visible in both its floating window and the chain.
          r.TrackFX_Show(track, i, 2)
          if r.TrackFX_GetOpen(track, i) then r.TrackFX_SetOpen(track, i, false) end
        else r.TrackFX_Show(track, i, 3) end
        return
      end
      if m.operation == "delete" and m.confirmed ~= true then
        fail("confirmationRequired")
      end

      if m.operation == "parameter" and (not finite(m.parameter) or m.parameter % 1 ~= 0 or m.parameter < 0 or m.parameter >= r.TrackFX_GetNumParams(track, i) or not bounded(m.value, {nil,0,1})) then
        fail("invalidValue")
      end

      local destination

      if m.operation == "move" then
        destination = fx_index(track, m.target)
        if not destination or destination == i then
          fail("staleState")
        end
      end

      if (m.operation == "enabled" or m.operation == "offline") and type(m.value) ~= "boolean" then
        fail("invalidValue")
      end

      if not ({enabled=true,offline=true,delete=true,move=true,parameter=true})[m.operation] then
        fail("invalidValue")
      end

      undo("FX " .. m.operation, function()
        if m.operation == "enabled" then r.TrackFX_SetEnabled(track, i, m.value)
        elseif m.operation == "offline" then r.TrackFX_SetOffline(track, i, m.value)
        elseif m.operation == "delete" then r.TrackFX_Delete(track, i)
        elseif m.operation == "move" then r.TrackFX_CopyToTrack(track, i, track, destination, true)
        else r.TrackFX_SetParamNormalized(track, i, m.parameter, m.value) end
      end)
    elseif action == "quick" then
      if m.operation == "master" then
        r.SetMasterTrackVisibility(r.GetMasterTrackVisibility() ~ 1)
        r.TrackList_AdjustWindows(false)
      elseif m.operation == "delete" then
        if m.confirmed ~= true then
          fail("confirmationRequired")
        end

        undo("Delete tracks", function() for i = #tracks, 1, -1 do r.DeleteTrack(tracks[i]) end end)
      elseif m.operation == "duplicate" then
        undo("Duplicate tracks", function() r.Main_OnCommand(40062, 0) end)
      elseif m.operation == "spacerBefore" or m.operation == "spacerAfter" then
        undo("Track spacers", function()
          r.Main_OnCommand(({spacerBefore=42665,spacerAfter=42666})[m.operation], 0)
        end)
      elseif m.operation == "envelopes" and track then
        local selected = {}
        for i = 0, r.CountSelectedTracks2(project, true) - 1 do
          selected[#selected+1] = r.GetSelectedTrack2(project, i, true)
        end
        r.PreventUIRefresh(1)

        local ok, err = pcall(function()
          r.SetOnlyTrackSelected(track)
          r.Main_OnCommand(40292, 0)
        end)

        r.SetTrackSelected(track, false)
        for _, t in ipairs(selected) do
          r.SetTrackSelected(t, true)
        end

        r.PreventUIRefresh(-1)
        if not ok then error(err, 0) end
      elseif m.operation == "chain" and track then
        r.TrackFX_Show(track, 0, 1)
      elseif track and (m.operation == "parent" or m.operation == "next" or m.operation == "previous") then
        local dest = m.operation == "parent" and r.GetParentTrack(track) or nil
        if m.operation ~= "parent" then
          dest = r.GetTrack(project, value(track, "IP_TRACKNUMBER") - 1 + (m.operation == "next" and 1 or -1))
        end

        if dest then r.SetOnlyTrackSelected(dest) end
      else
        fail("invalidValue")
      end
    else
      fail("invalidValue")
    end
  end

  function M.receive(m)
    if m.type == "ready" then
      ready, previous, force, next_tick, next_detail, next_index, index_dirty = true, {}, true, 0, 0, 0, true
      next_theme = 0
    elseif m.type == "refresh" then
      force, next_tick = true, 0
    elseif m.type == "projectLoaded" then
      check_project(true)
    elseif m.type == "gesturePing" then
      if gesture and gesture.id == m.gesture then
        gesture_time = r.time_precise()
      end
    elseif m.type == "command" then
      editing_message = m
      local ok, err = pcall(command, m)
      editing_message = nil
      if not ok then end_gesture() end

      send({type = "ack", id = m.id, ok = ok, error = ok and null or tostring(err), session = session})
      force, next_tick, next_detail = true, 0, 0
    end
  end

  function M.tick(now)
    if gesture and now - gesture_time > 3 then end_gesture() end
    if not ready or now < next_tick then return end
    next_tick = now + 0.12
    check_project()
    if now >= next_theme then emit("theme", theme_colors()) next_theme = now + 0.5 end
    local tracks, key, set = selection()
    if gesture and gesture.key ~= key then end_gesture() end
    local change = r.GetProjectStateChangeCount(project)
    local changed = change ~= last_change
    if changed then index_dirty = true end

    last_change = change
    local vals, mixed = common(tracks, track_values)
    local refs = A()

    for _, t in ipairs(tracks) do
      refs[#refs + 1] = track_ref(t)
    end

    local t = #tracks == 1 and tracks[1] or nil
    local _, project_path = r.EnumProjects(-1, "")

    emit("tracks", {mode = mode, masterVisible = (r.GetMasterTrackVisibility() & 1) ~= 0, count = #tracks, key = key, refs = refs, values = vals, mixed = mixed,
      parent = t and track_ref(r.GetParentTrack(t)) or null, folder = t and value(t, "I_FOLDERDEPTH") or null,
      aggregate = mode == "track" and t and aggregate_track(t) or false,
      projectName = project_path:match("([^/\\]+)$") or "", selected = #tracks > 0,
      iconDirectory = r.GetResourcePath() .. "/Data/track_icons/"})

    local selection_changed = M.last_selection ~= key
    if selection_changed then selected_fx = nil end
    M.last_selection = key

    if force or changed or selection_changed or now >= next_detail then
      local hardware_rows = routes(r.GetMasterTrack(project), {1})
      emit("hardwareRouting", {rows = hardware_rows})
      if t then
        local rows = mode == "master" and hardware_rows or routes(t)
        emit("routing", {key = key, rows = rows, routeKey = route_key(rows), outputs = mode == "master" and hardware_outputs() or nil})
        emit("fx", {key = key, rows = fx_state(t)})
      else
        emit("routing", {key = key, rows = A(), routeKey = ""})
        emit("fx", {key = key, rows = A()})
      end

      local items, item_key = items_for(set)
      local iv, im = common(items, read_item)
      local takes_available = #items > 0

      for _, item in ipairs(items) do
        if not r.GetActiveTake(item) then
          takes_available = false

          break
        end
      end

      emit("items", {key = key, itemKey = item_key, count = #items, values = iv, mixed = im, takesAvailable = takes_available, source = #items == 1 and source_info(items[1]) or null})

      local invalid = false
      local mv, mm = common(tracks, function(tr) local data = metadata(tr) if not data then invalid = true end return data or {version=1,notes="",category="",status="",tags=""} end)

      emit("metadata", {key = key, values = mv, mixed = mm, invalid = invalid})
      emit("inputs", inputs())

      next_detail = now + 0.8
    end

    emit("parameters", parameters(t))

    if index_dirty and now >= next_index then
      local list = A()

      for i = 0, r.CountTracks(project) - 1 do
        local tr = r.GetTrack(project, i)
        local meta = metadata(tr)

        list[#list + 1] = {guid = guid(tr), name = name(tr), number = i + 1, tags = meta and meta.tags or "", color = color(tr)}
      end

      emit("index", list)
      index_dirty, next_index = false, now + 0.75
    end

    force = false
  end

  M.close = end_gesture
  return M
end
