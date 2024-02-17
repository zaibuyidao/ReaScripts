-- @description Solo MIDI Note Play From Edit Cursor Position (Perform Until Shortcut Released)
-- @version 1.0.9
-- @author zaibuyidao
-- @changelog
--   # Optimized playback speed when soloing MIDI notes.
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

--[[
1.Once activated, the script will operate in the background. To deactivate it, simply run the script once more, or alternatively, configure the script as a toolbar button to conveniently toggle its activation status.
2.If the virtual key activates a system alert, please bind the key to 'Action: No-op (no action)
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Solo MIDI Note Shortcut Setting.lua
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
elseif language == "繁體中文" then
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
  map['<'] = 0xE2
  map['>'] = 0xE2
  return map
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
  local shortcutSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/MIDI Editor/zaibuyidao_Solo MIDI Note Shortcut Setting.lua'

  if reaper.file_exists(shortcutSetting) then
    dofile(shortcutSetting)
  else
    reaper.MB(shortcutSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
    if reaper.APIExists('ReaPack_BrowsePackages') then
      reaper.ReaPack_BrowsePackages('zaibuyidao Solo MIDI Note Shortcut Setting')
    else
      reaper.MB('ReaPack extension not found', '', 0)
    end
  end
end

local key = reaper.GetExtState("SOLO_MIDI_NOTE_SHORTCUT_SETTING", "VirtualKey")
if key == "" then
  CheckShortcutSetting()
  reaper.defer(function() end) -- 终止执行
  key = reaper.GetExtState("SOLO_MIDI_NOTE_SHORTCUT_SETTING", "VirtualKey")
end

key_map = generateKeyMap()
VirtualKeyCode = key_map[key]
play_flag = false
cur_pos = reaper.GetCursorPosition()

function main()
  editor = reaper.MIDIEditor_GetActive()
  state = reaper.JS_VKeys_GetState(0)
  all_takes = get_all_takes()
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