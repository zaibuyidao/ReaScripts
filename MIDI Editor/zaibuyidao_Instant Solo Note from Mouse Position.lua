-- @description Instant Solo Note from Mouse Position
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Intelligent SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

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

isPlay = reaper.GetPlayState()
all_takes = get_all_takes()

for take in next, all_takes do
  if isPlay == 0 then -- 停止播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_save_take_events(take)
    set_note_mute(take)
    set_unselect_note_mute(take)
    ::continue::
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play -- 播放
  end

  if isPlay == 1 then -- 正在播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_apply_take_events(take)
    ::continue::
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop -- 停止
  end
end
