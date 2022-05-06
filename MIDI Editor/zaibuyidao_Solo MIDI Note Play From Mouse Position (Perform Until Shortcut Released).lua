--[[
 * ReaScript Name: Solo MIDI Note Play From Mouse Position (Perform Until Shortcut Released)
 * Version: 1.0.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-11-28)
  + Initial release
--]]

--[[
1.After running the script, it will work in the background. If you want to stop it, run the script again (or set the script as a toolbar button to toggle it on and off).
2.If the bound key triggers the system alarm, then please bind the key to Action:No-op (no action)
3.If you want to change the key, find reaper-extstate.ini in the REAPER installation folder, find and delete:
[SoloItemPlayFromMousePosition]
Key=the key you set
--]]

function print(...)
  local params = {...}
  for i=1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
end

if not reaper.APIExists("JS_VKeys_GetState") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'. Then restart REAPER and run the script again. Thank you!\n\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動 REAPER 並再次運行腳本。謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "Error", 0)
  end
  return reaper.defer(function() end)
end

-- https://docs.microsoft.com/en-us/windows/desktop/inputdev/virtual-key-codes

key_map = { 
  ['0'] = 0x30,
  ['1'] = 0x31,
  ['2'] = 0x32,
  ['3'] = 0x33,
  ['4'] = 0x34,
  ['5'] = 0x35,
  ['6'] = 0x36,
  ['7'] = 0x37,
  ['8'] = 0x38,
  ['9'] = 0x39,
  ['A'] = 0x41,
  ['B'] = 0x42,
  ['C'] = 0x43,
  ['D'] = 0x44,
  ['E'] = 0x45,
  ['F'] = 0x46,
  ['G'] = 0x47,
  ['H'] = 0x48,
  ['I'] = 0x49,
  ['J'] = 0x4A,
  ['K'] = 0x4B,
  ['L'] = 0x4C,
  ['M'] = 0x4D,
  ['N'] = 0x4E,
  ['O'] = 0x4F,
  ['P'] = 0x50,
  ['Q'] = 0x51,
  ['R'] = 0x52,
  ['S'] = 0x53,
  ['T'] = 0x54,
  ['U'] = 0x55,
  ['V'] = 0x56,
  ['W'] = 0x57,
  ['X'] = 0x58,
  ['Y'] = 0x59,
  ['Z'] = 0x5A,
  ['a'] = 0x41,
  ['b'] = 0x42,
  ['c'] = 0x43,
  ['d'] = 0x44,
  ['e'] = 0x45,
  ['f'] = 0x46,
  ['g'] = 0x47,
  ['h'] = 0x48,
  ['i'] = 0x49,
  ['j'] = 0x4A,
  ['k'] = 0x4B,
  ['l'] = 0x4C,
  ['m'] = 0x4D,
  ['n'] = 0x4E,
  ['o'] = 0x4F,
  ['p'] = 0x50,
  ['q'] = 0x51,
  ['r'] = 0x52,
  ['s'] = 0x53,
  ['t'] = 0x54,
  ['u'] = 0x55,
  ['v'] = 0x56,
  ['w'] = 0x57,
  ['x'] = 0x58,
  ['y'] = 0x59,
  ['z'] = 0x5A
}

key = reaper.GetExtState("SoloMIDINoteFromMousePosition", "VirtualKey")
VirtualKeyCode = key_map[key]

function show_select_key_dialog()
  if (not key or not key_map[key]) then
    key = '9'
    local retval, retvals_csv = reaper.GetUserInputs("Set the Solo Key", 1, "Enter 0-9 or A-Z", key)
    if not retval then
      stop_solo = true
      return stop_solo
    end
    if (not key_map[retvals_csv]) then
      reaper.MB("Cannot set this Key", "Error", 0)
      stop_solo = true
      return stop_solo
    end
    key = retvals_csv
    VirtualKeyCode = key_map[key]
    reaper.SetExtState("SoloMIDINoteFromMousePosition", "VirtualKey", key, true)
  end
end

show_select_key_dialog()
if stop_solo then return end

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

local function stash_save_take_events(take)
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  MIDI = encodeBase64(MIDI)
  reaper.SetExtState("SoloMIDINotePlayFromMousePosition", tostring(take), MIDI, false)
end

local function stash_apply_take_events(take)
  local MIDI = reaper.GetExtState("SoloMIDINotePlayFromMousePosition", tostring(take))
  MIDI = decodeBase64(MIDI)
  reaper.MIDI_SetAllEvts(take, MIDI)
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
  return tTake
end

all_takes = get_all_takes()
play_flag = false
-- cur_pos = reaper.GetCursorPosition()

function main()
  editor = reaper.MIDIEditor_GetActive()
  state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態
  reaper.Undo_BeginBlock()

  if state:byte(VirtualKeyCode) ~= 0 and play_flag == false then
    for take, _ in pairs(all_takes) do
      if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
      stash_save_take_events(take)
      set_note_mute(take)
      set_unselect_note_mute(take)
      ::continue::
      reaper.MIDIEditor_OnCommand(editor, 40443) -- View: Move edit cursor to mouse cursor
      -- reaper.SetEditCurPos(cur_pos, 0, 0)
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
      play_flag = false
    end
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
