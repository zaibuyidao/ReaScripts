-- @description Insert Pitch Bend
-- @version 1.5.3
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
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

if language == "简体中文" then
  swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
  swserr = "警告"
  jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
  jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁体中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
end

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

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
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
  msg = "Please enter a value between -8192 and 8191."
  err = "Error"
end

local pitchbend = reaper.GetExtState("INSERT_PITCHBEND", "Pitchbend")
if (pitchbend == "") then pitchbend = "0" end

local uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, pitchbend)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitchbend = uinput:match("(.*)")
if not tonumber(pitchbend) then return reaper.SN_FocusMIDIEditor() end
pitchbend = tonumber(pitchbend)

reaper.SetExtState("INSERT_PITCHBEND", "Pitchbend", pitchbend, false)

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