-- @description Solo MIDI Note Play From Edit Cursor Position (Perform Until Shortcut Released)
-- @version 1.0.4
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

--[[
1.Once activated, the script will operate in the background. To deactivate it, simply run the script once more, or alternatively, configure the script as a toolbar button to conveniently toggle its activation status.
2.If the virtual key activates a system alert, please bind the key to 'Action: No-op (no action)
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Solo Track Shortcut Setting.lua
4.To remove the shortcut key, navigate to the REAPER installation folder, locate the 'reaper-extstate.ini' file, and then find and delete the following lines:
[SOLO_MIDI_NOTE_SHORTCUT_SETTING]
VirtualKey=the key you set
--]]

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ")
  end
  reaper.ShowConsoleMsg("\n")
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
end

local language = getSystemLanguage()

if language == "简体中文" then
  swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
  swserr = "警告"
  jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
  jstitle = "你必须安裝 JS_ReaScriptAPI"
  title = "独奏MIDI音符快捷键设置"
  lable = "输入 (0-9,A-Z,使用';;'代替','或.)"
  err_title = "不能设置这个按键，请改其他按键"
elseif language == "繁体中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
  title = "獨奏MIDI音符快捷鍵設置"
  lable = "輸入 (0-9,A-Z,使用';;'代替','或.)"
  err_title = "不能設置這個按鍵，請改其他按鍵"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
  title = "Solo MIDI Note Shortcut Settings"
  lable = "Enter (0-9, A-Z, use ';;' for ',' or .)"
  err_title = "This key can't be set. Please choose another."
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
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
  -- map['<'] = 0xBC
  -- map['>'] = 0xBE
  return map
end

key_map = generateKeyMap()

local key = reaper.GetExtState("SOLO_MIDI_NOTE_SHORTCUT_SETTING", "VirtualKey")
VirtualKeyCode = key_map[key]
shift_key = 0x10
ctrl_key = 0x11
alt_key = 0x12

if (not key or not key_map[key]) then
  key = "9"
  local retval, retvals_csv = reaper.GetUserInputs(title, 1, lable, key)

  if retval == nil or retval == false then 
    return
  end

  -- If the user entered ";;", interpret it as ","
  if retvals_csv == ";;" then
    retvals_csv = ","
  end

  if (not key_map[retvals_csv]) then
    reaper.MB(err_title, "Error", 0)
    return
  end

  key = retvals_csv
  VirtualKeyCode = key_map[key]
  reaper.SetExtState("SOLO_MIDI_NOTE_SHORTCUT_SETTING", "VirtualKey", key, true)

  if language == "简体中文" then
    okk_title = "虚拟键 ".. key .." 设置完毕。接下来，你需要将按键 ".. key .." 设置为无动作，以避免触发系统警报声。\n点击【确定】将会弹出操作列表的快捷键设置，请将快捷键设置为按键 ".. key .." 。\n\n最后，请重新运行 Solo MIDI Note 脚本，並使用快捷键 ".. key .." 进行独奏。"
    okk_box = "继续下一步"
  elseif language == "繁体中文" then
    okk_title = "虛擬鍵 ".. key .." 設置完畢。接下來，你需要將按鍵 ".. key .." 設置為無動作，以避免觸發系統警報聲。\n點擊【確定】將會彈出操作列表的快捷鍵設置，請將快捷鍵設置為按鍵 ".. key .." 。\n\n最後，請重新運行 Solo MIDI Note 腳本，並使用快捷鍵 ".. key .." 進行獨奏。"
    okk_box = "繼續下一步"
  else
    okk_title = "The virtual key " .. key .. " has been set up. Next, you need to configure the key " .. key .. " to 'No Action' to prevent triggering system alert sounds.\nClicking [OK] will open the action list's shortcut settings. Please set the shortcut to key " .. key .. ".\n\nLastly, please rerun the Solo MIDI Note script and use the shortcut " .. key .. " to solo."
    okk_box = "Proceed to the next step."
  end

  reaper.MB(okk_title, okk_box, 0) -- 继续下一步
  reaper.DoActionShortcutDialog(0, 0, 65535, -1) -- No-op (no action)
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
cur_pos = reaper.GetCursorPosition()

function main()
  editor = reaper.MIDIEditor_GetActive()
  state = reaper.JS_VKeys_GetState(0)
  reaper.Undo_BeginBlock()

  if state:byte(VirtualKeyCode) ~= 0 and play_flag == false then
    for take, _ in pairs(all_takes) do
      if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
      stash_save_take_events(take)
      set_note_mute(take)
      set_unselect_note_mute(take)
      ::continue::
      -- reaper.MIDIEditor_OnCommand(editor, 40443) -- View: Move edit cursor to mouse cursor
      reaper.SetEditCurPos(cur_pos, 0, 0)
      reaper.MIDIEditor_OnCommand(editor, 1140) -- Transport: Play
      play_flag = true
    end
  end
  if state:byte(VirtualKeyCode) == 0 and play_flag == true then
    for take, _ in pairs(all_takes) do
      if reaper.MIDI_EnumSelNotes(take, -1) == -1 then goto continue end
      stash_apply_take_events(take)
      ::continue::
      reaper.MIDIEditor_OnCommand(editor, 1142) -- Transport: Stop
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