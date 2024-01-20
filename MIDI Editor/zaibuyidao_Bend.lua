-- @description Bend
-- @version 1.0.2
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
if loop_end <= loop_start then return reaper.SN_FocusMIDIEditor() end
local loop_len = loop_end - loop_start

if language == "简体中文" then
  title = "推弦"
  captions_csv = "弯音间隔,弯音范围,1=保持 2=立即 3=反向"
  msgint = "弯音间隔不能大于弯音范围"
  msgerr = "错误"
elseif language == "繁体中文" then
  title = "推弦"
  captions_csv = "彎音間隔,彎音範圍,1=保持 2=立即 3=反向"
  msgint = "彎音間隔不能大於彎音範圍"
  msgerr = "錯誤"
else
  title = "Bend"
  captions_csv = "Bend interval,Bend Range,1=Hold 2=Immediate 3=Reverse"
  msgint = "The pitch bend interval cannot exceed the pitch bend range."
  msgerr = "Error"
end

local interval = reaper.GetExtState("Bend", "Interval")
if (interval == "") then interval = "2" end
local bend_range = reaper.GetExtState("Bend", "PitchRange")
if (bend_range == "") then bend_range = "2" end
local toggle = reaper.GetExtState("Bend", "Toggle")
if (toggle == "") then toggle = "1" end

uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, interval ..','.. bend_range ..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
interval, bend_range, toggle = uinput:match("(.*),(.*),(.*)")
interval, bend_range, toggle = tonumber(interval), tonumber(bend_range), tonumber(toggle)

if interval > bend_range then
  return reaper.MB(msgint, msgerr, 0), reaper.SN_FocusMIDIEditor()
end

if bend_range < -12 or bend_range > 12 or bend_range == 0 or toggle > 3 or toggle < 0 then
  return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("Bend", "Interval", interval, false)
reaper.SetExtState("Bend", "PitchRange", bend_range, false)
reaper.SetExtState("Bend", "Toggle", toggle, false)

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

local seg = getSegments(bend_range)

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (bend_range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
      return targets[p + (bend_range + 1)]
  end
end

local function set_cc_shape(take, bezier, shape)
  i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

if interval > 0 then
  pitch = pitchUp(interval, seg)
else
  pitch = pitchDown(interval, seg)
end

LSB = pitch & 0x7F
MSB = (pitch >> 7) + 64

reaper.Undo_BeginBlock()
if toggle == 1 then
  local p1 = loop_start + loop_len*0.25
  local p2 = loop_start + loop_len*0.75
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, 75, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 2 then
  local p1 = loop_start + loop_len*0.49
  local p2 = loop_start + loop_len*0.51
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, -50, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 3 then
  local p1 = loop_start + loop_len*0.125
  local p2 = loop_start + loop_len*0.25
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, -70, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, -10, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
else
  return
end

reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()