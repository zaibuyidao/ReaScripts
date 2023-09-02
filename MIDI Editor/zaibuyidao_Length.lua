-- @description Length
-- @version 2.2
-- @author zaibuyidao
-- @changelog Optimize code.
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local HWND =  reaper.MIDIEditor_GetActive()
if not HWND then return end
local take =  reaper.MIDIEditor_GetTake(HWND)
if not take or not reaper.TakeIsMIDI(take) then return end

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

function Length1(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[2] do
    local note_t = ({reaper.MIDI_GetNote( take, i-1 )})
    if note_t[2] then
      id = id + 1
      if id == 1 then strtppq = note_t[4] end
      reaper.MIDI_SetNote(
        take,
        i-1,
        note_t[2],
        note_t[3],
        math.floor(f(note_t[4]-strtppq,id)+strtppq),
        math.floor(f(note_t[4]-strtppq,id)+strtppq)+(note_t[5]-note_t[4]),
        note_t[6],
        note_t[7],
        note_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

function Length2(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[2] do
    local note_t = ({reaper.MIDI_GetNote( take, i-1 )})
    if note_t[2] then
      id = id + 1
      if id == 1 then strtppq = note_t[5] end
      reaper.MIDI_SetNote(
        take,
        i-1,
        note_t[2],
        note_t[3],
        note_t[4],
        math.floor(note_t[4]+f(note_t[5]-note_t[4]),id),
        note_t[6],
        note_t[7],
        note_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

function StretchSelectedNotes(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[2] do
    local note_t = ({reaper.MIDI_GetNote( take, i-1 )})
    if note_t[2] then
      id = id + 1
      if id == 1 then strtppq = note_t[4] end
      reaper.MIDI_SetNote(
        take,
        i-1,
        note_t[2],
        note_t[3],
        math.floor(f(note_t[4]-strtppq,id)+strtppq),
        math.floor(f(note_t[4]-strtppq,id)+strtppq+f(note_t[5]-note_t[4]),id),
        note_t[6],
        note_t[7],
        note_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

function StretchSelectedCCs(f)
  local id = 0
  for i = 1, ({reaper.MIDI_CountEvts( take )})[3] do
    local cc_t = ({reaper.MIDI_GetCC( take, i-1 )})
    if cc_t[2] then
      id = id + 1
      if id == 1 then ppqpos = cc_t[4] end
      reaper.MIDI_SetCC(
        take,
        i-1,
        cc_t[2],
        cc_t[3],
        math.floor(f(cc_t[4]-ppqpos,id)+ppqpos),
        cc_t[5],
        cc_t[6],
        cc_t[7],
        cc_t[8],
        true
      )
    end
  end
  reaper.MIDI_Sort(take)
end

if language == "简体中文" then
  title = "长度"
  lable = "百分比,0=起始+持续 1=起始 2=持续"
elseif language == "繁体中文" then
  title = "長度"
  lable = "百分比,0=起始+持續 1=起始 2=持續"
else
  title = "Length"
  lable = "Percent,0=Start+Dur 1=Start 2=Durations"
end

local percent = reaper.GetExtState("LENGTH", "Percent")
if (percent == "") then percent = "200" end
local toggle = reaper.GetExtState("LENGTH", "Toggle")
if (toggle == "") then toggle = "0" end

local retval, retvals_csv = reaper.GetUserInputs(title, 2, lable, percent .. ',' .. toggle)
if not retval or not tonumber(percent) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
percent, toggle = retvals_csv:match("(%d*),(%d*)")

reaper.SetExtState("LENGTH", "Percent", percent, false)
reaper.SetExtState("LENGTH", "Toggle", toggle, false)

local func
if not percent:match('[%d%.]+') or not tonumber(percent:match('[%d%.]+')) or not toggle:match('[%d%.]+') or not tonumber(toggle:match('[%d%.]+')) then return end
func = load("local x = ... return x*"..tonumber(percent:match('[%d%.]+')) / 100)
if not func then return end
reaper.Undo_BeginBlock()
if toggle == "2" then
  Length2(func)
elseif toggle == "1" then
  Length1(func)
else
  StretchSelectedNotes(func)
  StretchSelectedCCs(func)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()