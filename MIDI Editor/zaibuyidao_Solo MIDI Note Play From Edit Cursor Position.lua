--[[
 * ReaScript Name: Solo MIDI Note Play From Edit Cursor Position
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-5-5)
  + Initial release
--]]

function print(...)
  local params = {...}
  for i=1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
end

local function encodeBase64(source_str)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local s64 = ''
  local str = source_str

  while #str > 0 do
    local bytes_num = 0
    local buf = 0

    for byte_cnt=1,3 do
      buf = (buf * 256)
      if #str > 0 then
        buf = buf + string.byte(str, 1, 1)
        str = string.sub(str, 2)
        bytes_num = bytes_num + 1
      end
    end

    for group_cnt=1,(bytes_num+1) do
      local b64char = math.fmod(math.floor(buf/262144), 64) + 1
      s64 = s64 .. string.sub(b64chars, b64char, b64char)
      buf = buf * 64
    end

    for fill_cnt=1,(3-bytes_num) do
      s64 = s64 .. '='
    end
  end

  return s64
end

local function decodeBase64(str64)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local temp={}
  for i=1,64 do
    temp[string.sub(b64chars,i,i)] = i
  end
  temp['=']=0
  local str=""
  for i=1,#str64,4 do
    if i>#str64 then
      break
    end
    local data = 0
    local str_count=0
    for j=0,3 do
      local str1=string.sub(str64,i+j,i+j)
      if not temp[str1] then
        return
      end
      if temp[str1] < 1 then
        data = data * 64
      else
        data = data * 64 + temp[str1]-1
        str_count = str_count + 1
      end
    end
    for j=16,0,-8 do
      if str_count > 0 then
        str=str..string.char(math.floor(data/(2^j)))
        data=data%(2^j)
        str_count = str_count - 1
      end
    end
  end

  local last = tonumber(string.byte(str, string.len(str), string.len(str)))
  if last == 0 then
    str = string.sub(str, 1, string.len(str) - 1)
  end
  return str
end

tTake = {}
if reaper.MIDIEditor_EnumTakes then
  local editor = reaper.MIDIEditor_GetActive()
  for i = 0, math.huge do
    take = reaper.MIDIEditor_EnumTakes(editor, i, false)
    if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
      tTake[take] = true
      tTake[take] = {item = reaper.GetMediaItemTake_Item(take)}
    else
      break
    end
  end
else
  for i = 0, reaper.CountMediaItems(0)-1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
      tTake[take] = true
    end
  end

  for take in next, tTake do
    if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tT[take] = nil end -- Remove takes that were not affected by deselection
  end
end
if not next(tTake) then return end

local function stash_save_take_events(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  MIDI = encodeBase64(MIDI)
  reaper.SetExtState("SoloMIDINotePlayFromEditCursorPosition", tostring(take), MIDI, false)
end

local function stash_apply_take_events(take)
  local MIDI = reaper.GetExtState("SoloMIDINotePlayFromEditCursorPosition", tostring(take))
  MIDI = decodeBase64(MIDI)
  reaper.MIDI_SetAllEvts(take, MIDI)
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
cur_pos = reaper.GetCursorPosition()

for take in next, tTake do
  if isPlay == 0 then -- 停止播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_save_take_events(take)
    set_note_mute(take)
    set_unselect_note_mute(take)
    ::continue::
    -- reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
    reaper.SetEditCurPos(cur_pos, 0, 0)
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play -- 播放
  end

  if isPlay == 1 then -- 正在播放
    if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
    stash_apply_take_events(take)
    ::continue::
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop -- 停止播放
  end
end
