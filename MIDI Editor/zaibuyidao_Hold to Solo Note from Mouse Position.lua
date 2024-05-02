-- @description Hold to Solo Note from Mouse Position
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Intelligent SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

--[[
1.Once activated, the script will operate in the background. To deactivate it, simply run the script once more, or alternatively, configure the script as a toolbar button to conveniently toggle its activation status.
2.If the virtual key activates a system alert, please bind the key to 'Action: No-op (no action)
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Hold to Solo Note Setting.lua
4.To remove the shortcut key, navigate to the REAPER installation folder, locate the 'reaper-extstate.ini' file, and then find and delete the following lines:
[HOLD_TO_SOLO_NOTE_SETTING]
VirtualKey=the key you set
--]]

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

local function generateKeyMap()
  local map = {}
  for i = 0, 9 do
    map[tostring(i)] = 0x30 + i
  end
  for i = 0, 25 do
    local char = string.char(65 + i)  -- Uppercase A-Z
    map[char] = 0x41 + i
    char = string.char(97 + i)  -- Lowercase a-z
    map[char] = 0x41 + i  -- Virtual Key Codes are the same for uppercase
  end
  map[','] = 0xBC
  map['.'] = 0xBE
  map['<'] = 0xE2
  map['>'] = 0xE2
  return map
end

local function stash_save_take_events(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local encodedStr = reaper.NF_Base64_Encode(MIDI, true) -- 使用REAPER的函数进行Base64编码
  reaper.SetExtState("HoldtoSoloNotefromMousePosition", tostring(take), encodedStr, false)
end

local function stash_apply_take_events(take)
  local base64Str = reaper.GetExtState("HoldtoSoloNotefromMousePosition", tostring(take))
  local retval, decodedStr = reaper.NF_Base64_Decode(base64Str) -- 使用REAPER的函数进行Base64解码
  if retval then
    reaper.MIDI_SetAllEvts(take, decodedStr)
  end
end

function set_note_mute(take) -- 将音符设置为静音
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos, t, offset, flags, msg = 1, {}
  while pos < #MIDI do
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
    if msg:byte(1)>>4 == 9 and flags&1 == 1 then
      flags = 1
    end
    t[#t+1] = string.pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(t))
end

function set_unselect_note_mute(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos, t, offset, flags, msg = 1, {}
  while pos < #MIDI do
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
    if msg:byte(1)>>4 == 9 and flags&1 == 0 then
      flags = 2
    end
    t[#t+1] = string.pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(t))
end

function get_all_takes()
  local tTake = {}
  local editor = reaper.MIDIEditor_GetActive()
  if editor then
    for i = 0, math.huge do
      local take = reaper.MIDIEditor_EnumTakes(editor, i, false)
      if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
        tTake[take] = true
      else
        break
      end
    end
  else
    for i = 0, reaper.CountMediaItems(0)-1 do
      local item = reaper.GetMediaItem(0, i)
      for j = 0, reaper.CountTakes(item)-1 do
        local take = reaper.GetTake(item, j)
        if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
          tTake[take] = true
        end
      end
    end
  end
  return tTake
end

function CheckShortcutSetting()
  local shortcutSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/MIDI Editor/zaibuyidao_Hold to Solo Note Setting.lua'

  if reaper.file_exists(shortcutSetting) then
    dofile(shortcutSetting)
  else
    reaper.MB(shortcutSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
    if reaper.APIExists('ReaPack_BrowsePackages') then
      reaper.ReaPack_BrowsePackages('zaibuyidao Hold to Solo Note Setting')
    else
      reaper.MB('ReaPack extension not found', '', 0)
    end
  end
end

local key = reaper.GetExtState("HOLD_TO_SOLO_NOTE_SETTING", "VirtualKey")
if key == "" then
  CheckShortcutSetting()
  reaper.defer(function() end) -- 终止执行
  key = reaper.GetExtState("HOLD_TO_SOLO_NOTE_SETTING", "VirtualKey")
end

key_map = generateKeyMap()
VirtualKeyCode = key_map[key]
play_flag = false

function main()
  editor = reaper.MIDIEditor_GetActive()
  state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態
  all_takes = get_all_takes()
  reaper.Undo_BeginBlock()

  if state:byte(VirtualKeyCode) ~= 0 and play_flag == false then
    for take, _ in pairs(all_takes) do
      if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
      stash_save_take_events(take)
      set_note_mute(take)
      set_unselect_note_mute(take)
      ::continue::
      reaper.MIDIEditor_OnCommand(editor, 40443) -- View: Move edit cursor to mouse cursor
      reaper.MIDIEditor_OnCommand(editor, 1140) -- Transport: Play -- 播放
      play_flag = true
    end
  end
  if state:byte(VirtualKeyCode) == 0 and play_flag == true then
    for take, _ in pairs(all_takes) do
      if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
      stash_apply_take_events(take)
      ::continue::
      reaper.MIDIEditor_OnCommand(editor, 1142) -- Transport: Stop -- 停止播放
    end
    play_flag = false
  end
  reaper.Undo_EndBlock("", -1)
  reaper.defer(main)
end

local _, _, sectionId, cmdId = reaper.get_action_context()
if sectionId ~= -1 then
  reaper.SetToggleCommandState(sectionId, cmdId, 1)
  reaper.RefreshToolbar2(sectionId, cmdId)
  main()
  reaper.atexit(function()
    reaper.SetToggleCommandState(sectionId, cmdId, 0)
    reaper.RefreshToolbar2(sectionId, cmdId)
  end)
end