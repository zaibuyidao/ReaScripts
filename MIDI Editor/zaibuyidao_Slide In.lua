-- @description Slide In
-- @version 1.4.4
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

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end

if language == "简体中文" then
  title = "弯音滑入"
  captions_csv = "弯音间隔,弯音范围,贝塞尔 (-100,100),0=SMO 1=LIN 2=FRE 3=REV"
elseif language == "繁体中文" then
  title = "彎音滑入"
  captions_csv = "彎音間隔,彎音範圍,貝塞爾 (-100,100),0=SMO 1=LIN 2=FRE 3=REV"
else
  title = "Slide In"
  captions_csv = "Pitch interval,Pitch Range,Bezier (-100,100),0=SMO 1=LIN 2=FRE 3=REV"
end

local pitch = reaper.GetExtState("SLIDE_IN", "Pitch")
if (pitch == "") then pitch = "-7" end
local range = reaper.GetExtState("SLIDE_IN", "Range")
if (range == "") then range = "12" end
local bezier = reaper.GetExtState("SLIDE_IN", "Bezier")
if (bezier == "") then bezier = "20" end
local toggle = reaper.GetExtState("SLIDE_IN", "Toggle")
if (toggle == "") then toggle = "2" end

uok, uinput = reaper.GetUserInputs(title, 4, captions_csv, pitch ..','.. range ..','.. bezier ..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, range, bezier, toggle = uinput:match("(.*),(.*),(.*),(.*)")

if not tonumber(pitch) or not tonumber(range) or not tonumber(bezier) or not tonumber(toggle) or tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 or tonumber(bezier) < -100 or tonumber(bezier) > 100 or tonumber(toggle) > 3 then
  return reaper.SN_FocusMIDIEditor()
end

pitch, range, bezier, toggle = tonumber(pitch), tonumber(range),tonumber(bezier), tonumber(toggle)

reaper.SetExtState("SLIDE_IN", "Pitch", pitch, false)
reaper.SetExtState("SLIDE_IN", "Range", range, false)
reaper.SetExtState("SLIDE_IN", "Bezier", bezier, false)
reaper.SetExtState("SLIDE_IN", "Toggle", toggle, false)

function getSegments(n)
  local x = 8192
  local p = math.floor((x / n) + 0.5) -- 四舍五入
  local arr = {}
  local cur = 0
  for i = 1, n do
    cur = cur + p
    table.insert(arr, math.min(cur, x))
  end
  local res = {}
  for i = #arr, 1, -1 do
    table.insert(res, -arr[i])
  end
  table.insert(res, 0)
  for i = 1, #arr do
    table.insert(res, arr[i])
  end
  res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
  return res
end

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
    return targets[p + (range + 1)]
  end
end

local function set_cc_shape(take, bezier, shape)
  local i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

reaper.Undo_BeginBlock()
if toggle == 0 then
  local seg = getSegments(range)
  if pitch > 0 then
    pitchbend = pitchUp(pitch, seg)
  else
    pitchbend = pitchDown(pitch, seg)
  end

  LSB = pitchbend & 0x7F
  MSB = (pitchbend >> 7) + 64
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, LSB, MSB)
  set_cc_shape(take, bezier, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64) -- 在LOOP结尾插入弯音值归零
elseif toggle == 1 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchDown(math.abs(pitch)-i, seg)
    else
      pitchbend = pitchUp(i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + (loop_end-loop_start) * (i/(math.abs(pitch))), 224, 0, LSB, MSB)
  end
elseif toggle == 2 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchDown(math.abs(pitch)-i, seg)
    else
      pitchbend = pitchUp(i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + (loop_end-loop_start) * ((i+i)/(math.abs(pitch)+i)), 224, 0, LSB, MSB)
  end
elseif toggle == 3 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchUp((i-math.abs(pitch))+math.abs(pitch), seg)
    else
      pitchbend = pitchDown((math.abs(pitch)-i)-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_end + (loop_end-loop_start) * ((i+i)/-(math.abs(pitch)+i)), 224, 0, LSB, MSB)
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()