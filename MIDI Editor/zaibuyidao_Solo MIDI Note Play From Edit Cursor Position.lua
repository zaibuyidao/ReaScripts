-- @description Solo MIDI Note Play From Edit Cursor Position
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   # Optimized playback speed when soloing MIDI notes.
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  local params = {...}
  for i=1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
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
  reaper.SetExtState("SoloMIDINotePlayFromEditCursorPosition", tostring(take), encodedStr, false)
end

local function stash_apply_take_events(take)
  local base64Str = reaper.GetExtState("SoloMIDINotePlayFromEditCursorPosition", tostring(take))
  local retval, decodedStr = reaper.NF_Base64_Decode(base64Str) -- 使用REAPER的函数进行Base64解码
  if retval then
    reaper.MIDI_SetAllEvts(take, decodedStr)
  end
end

function set_note_mute(take, value) -- 将音符设置为静音
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
cur_pos = reaper.GetCursorPosition()

for take in next, all_takes do
  if isPlay == 0 then -- 停止播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_save_take_events(take)
    set_note_mute(take)
    set_unselect_note_mute(take)
    ::continue::
    reaper.SetEditCurPos(cur_pos, 0, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play -- 播放
  end

  if isPlay == 1 then -- 正在播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_apply_take_events(take)
    ::continue::
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop -- 停止
  end
end
