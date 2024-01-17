-- @description Insert SysEx Message
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_inlineeditor] .
-- @about Requires JS_ReaScriptAPI & SWS Extension

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
local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
local title = ""
local captions_csv = ""

if language == "简体中文" then
  title = "插入系统专用消息"
  captions_csv = "输入系统专用消息,extrawidth=160"
elseif language == "繁体中文" then
  title = "插入系統專用消息"
  captions_csv = "輸入系統專用消息,extrawidth=160"
else
  title = "Insert SysEx Message"
  captions_csv = "Enter SysEx Message,extrawidth=160"
end

local sysex_byte = reaper.GetExtState("INSERT_SYSEX", "SysexByte")
if (sysex_byte == "") then sysex_byte = "F0 41 10 42 12 00 00 7F 01 00 F7" end

user_ok, sysex_byte = reaper.GetUserInputs(title, 1, captions_csv, sysex_byte)
reaper.SetExtState("INSERT_SYSEX", "SysexByte", sysex_byte, false)

if (string.sub(sysex_byte, 1, 2) == "F0") or (string.sub(sysex_byte, 1, 2) == "f0") then sysex_byte = string.sub(sysex_byte, 3) end
if (string.sub(sysex_byte, -2) == "F7") or (string.sub(sysex_byte, -2) == "f7") then sysex_byte = string.sub(sysex_byte, 1, -3) end
sysex_byte = sysex_byte:gsub("%s+", "") -- 去除所有空格

reaper.Undo_BeginBlock()
if window == "midi_editor" then
  if not inline_editor then
    if not user_ok then return reaper.SN_FocusMIDIEditor() end
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  else
    take = reaper.BR_GetMouseCursorContext_Take()
  end

  local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 获取光标位置
  local bytestr = ''
  for char_pair in sysex_byte:gmatch('..') do
    bytestr = bytestr .. string.char(tonumber(char_pair, 16))
  end

  reaper.MIDI_InsertTextSysexEvt(take, true, false, ppqpos, -1, bytestr)

  if not inline_editor then reaper.SN_FocusMIDIEditor() end
else
  if not user_ok then return end
  count_sel_items = reaper.CountSelectedMediaItems(0)
  if count_sel_items == 0 then return end
  for i = 1, count_sel_items do
    item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
    take = reaper.GetTake(item, 0)

    local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 获取光标位置
    local bytestr = ''
    for char_pair in sysex_byte:gmatch('..') do
      bytestr = bytestr .. string.char(tonumber(char_pair, 16))
    end

    reaper.MIDI_InsertTextSysexEvt(take, true, false, ppqpos, -1, bytestr)
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()