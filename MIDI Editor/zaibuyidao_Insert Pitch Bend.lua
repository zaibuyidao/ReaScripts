-- @description Insert Pitch Bend
-- @version 1.5.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
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

if not reaper.SN_FocusMIDIEditor then
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx()
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local title = ""
local captions_csv = ""
local msg = ""
local err = ""

if language == "简体中文" then
  title = "插入弯音"
  captions_csv = "值"
  msg = "请输入一个介于 -8192 到 8191 之间的值"
  err = "错误"
elseif language == "繁体中文" then
  title = "插入彎音"
  captions_csv = "值"
  msg = "請輸入一個介於 -8192 到 8191 之間的值"
  err = "錯誤"
else
  title = "'Insert Pitch Bend"
  captions_csv = "Value"
  msg = "Please enter a value between -8192 and 8191"
  err = "Error"
end

local pitchbend = reaper.GetExtState("InsertPitchBend", "Pitch")
if (pitchbend == "") then pitchbend = "0" end

local uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, pitchbend)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitchbend = uinput:match("(.*)")
if not tonumber(pitchbend) then return reaper.SN_FocusMIDIEditor() end
pitchbend = tonumber(pitchbend)

reaper.SetExtState("InsertPitchBend", "Pitchbend", pitchbend, false)

if pitchbend < -8192 or pitchbend > 8191 then
  return reaper.MB(msg, err, 0), reaper.SN_FocusMIDIEditor()
end

reaper.Undo_BeginBlock()
local LSB = pitchbend & 0x7F
local MSB = (pitchbend >> 7) + 64
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()