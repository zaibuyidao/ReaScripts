-- NoIndex: true
local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

function table.serialize(obj)
  local lua = ""
  local t = type(obj)
  if t == "number" then
    lua = lua .. obj
  elseif t == "boolean" then
    lua = lua .. tostring(obj)
  elseif t == "string" then
    lua = lua .. string.format("%q", obj)
  elseif t == "table" then
      lua = lua .. "{\n"
  for k, v in pairs(obj) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
  end
  local metatable = getmetatable(obj)
  if metatable ~= nil and type(metatable.__index) == "table" then
    for k, v in pairs(metatable.__index) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
    end
  end
  lua = lua .. "}"
  elseif t == "nil" then
    return nil
  else
    error("can not serialize a " .. t .. " type.")
  end
  return lua
end

function table.unserialize(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then return nil end
  return func()
end

function getSavedData(key1, key2)
  return table.unserialize(reaper.GetExtState(key1, key2))
end

local function SaveSoloTracks(t) -- 保存Solo的軌道
  for i = 1, reaper.CountTracks(0) do
    local tr= reaper.GetTrack(0, i-1)
    t[#t+1] = { GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") }
  end
  reaper.SetExtState("InstantSoloTrackfromMousePosition", "SoloTrackRestores", table.serialize(t), false)
end

local function RestoreSoloTracks(t) -- 恢復Solo的軌道状态
  t = getSavedData("InstantSoloTrackfromMousePosition", "SoloTrackRestores")
  for i = 1, #t do
    local src_tr = reaper.BR_GetMediaTrackByGUID(0, t[i].GUID)
    reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", t[i].solo)
  end
end

local function stash_save_take_events(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local encodedStr = reaper.NF_Base64_Encode(MIDI, true) -- 使用REAPER的函数进行Base64编码
  reaper.SetExtState("InstantSoloNotefromMousePosition", tostring(take), encodedStr, false)
end

local function stash_apply_take_events(take)
  local base64Str = reaper.GetExtState("InstantSoloNotefromMousePosition", tostring(take))
  local retval, decodedStr = reaper.NF_Base64_Decode(base64Str) -- 使用REAPER的函数进行Base64解码
  if retval then
    reaper.MIDI_SetAllEvts(take, decodedStr)
  end
end

function set_note_mute(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos, t, offset, flags, msg = 1, {}
  while pos < #MIDI do
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
    local status = msg:byte(1) >> 4
    local isNoteOn = status == 9 and msg:byte(3) > 0
    local isNoteOff = status == 8 or (status == 9 and msg:byte(3) == 0)

    -- 检查音符是否被选中
    if (isNoteOn or isNoteOff) and flags & 1 == 1 then
      flags = 1 -- 保持选中的音符状态
    elseif (isNoteOn or isNoteOff) then
      flags = 2 -- 设置未选中的音符为静音
    end
    
    t[#t + 1] = string.pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(t))
end

function set_unselect_note_mute(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos, t, offset, flags, msg = 1, {}
  while pos < #MIDI do
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
    local status = msg:byte(1) >> 4
    local isNoteOn = status == 9 and msg:byte(3) > 0
    local isNoteOff = status == 8 or (status == 9 and msg:byte(3) == 0)

    -- 静音未选中的音符
    if (isNoteOn or isNoteOff) and flags & 1 == 0 then
      flags = 2 -- 设置音符为静音
    end
    
    t[#t + 1] = string.pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(t))
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

all_takes = getAllTakes()
play_state = reaper.GetPlayState()
count_sel_items = reaper.CountSelectedMediaItems(0)
cursor_pos = reaper.GetCursorPosition()
init_solo_tracks = {}

if play_state == 0 then -- 停止播放
  local editor = reaper.MIDIEditor_GetActive()
  if editor == nil then return end

  SaveSoloTracks(init_solo_tracks) -- 保存轨道Solo状态

  local selected_track = {}

  for m = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, m)
    local track = reaper.GetMediaItem_Track(item)
    if (not selected_track[track]) then
      selected_track[track] = true
    end
  end

  for track, _ in pairs(selected_track) do
    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
  end

  local function should_mute_take(take)
    return reaper.MIDI_EnumSelNotes(take, -1) == -1
  end

  for take, _ in pairs(all_takes) do
    stash_save_take_events(take)
    set_unselect_note_mute(take)
  end

  reaper.SetEditCurPos(cursor_pos, 0, 0)
  reaper.MIDIEditor_OnCommand(editor, 1140) -- Transport: Play
end

if play_state == 1 then -- 正在播放
  local editor = reaper.MIDIEditor_GetActive()
  if editor == nil then return end

  RestoreSoloTracks(init_solo_tracks)

  for take, _ in pairs(all_takes) do
    stash_apply_take_events(take)
    reaper.MIDIEditor_OnCommand(editor, 1142) -- Transport: Stop
  end
end
reaper.PreventUIRefresh(-1)
reaper.defer(NoUndoPoint)