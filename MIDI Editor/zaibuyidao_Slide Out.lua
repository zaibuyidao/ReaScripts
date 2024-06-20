-- @description Slide Out
-- @version 1.5.2
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Pitch Bend Script Series, filter "zaibuyidao pitch bend" in ReaPack or Actions to access all scripts.
--   Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end

if language == "简体中文" then
  title = "弯音滑出"
  captions_csv = "弯音间隔:,弯音范围:,贝塞尔(-100 至 100):,1=SMO 2=LIN 3=FRE 4=REV"
elseif language == "繁體中文" then
  title = "彎音滑出"
  captions_csv = "彎音間隔:,彎音範圍:,貝塞爾(-100 至 100):,1=SMO 2=LIN 3=FRE 4=REV"
else
  title = "Slide Out"
  captions_csv = "Pitch Interval:,Pitchwheel Range:,Bezier (-100 to 100):,1=SMO 2=LIN 3=FRE 4=REV"
end

local pitch = reaper.GetExtState("SLIDE_OUT", "Pitch")
if (pitch == "") then pitch = "-7" end
local range = reaper.GetExtState("SLIDE_OUT", "Range")
if (range == "") then range = "12" end
local bezier = reaper.GetExtState("SLIDE_OUT", "Bezier")
if (bezier == "") then bezier = "-20" end
local toggle = reaper.GetExtState("SLIDE_OUT", "Toggle")
if (toggle == "") then toggle = "3" end

uok, uinput = reaper.GetUserInputs(title, 4, captions_csv, pitch ..','.. range ..','.. bezier ..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, range, bezier, toggle = uinput:match("(.*),(.*),(.*),(.*)")

if not tonumber(pitch) or not tonumber(range) or not tonumber(bezier) or not tonumber(toggle) or tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 or tonumber(bezier) < -100 or tonumber(bezier) > 100 or tonumber(toggle) > 4 then
  return reaper.SN_FocusMIDIEditor()
end

pitch, range, bezier, toggle = tonumber(pitch), tonumber(range),tonumber(bezier), tonumber(toggle)

reaper.SetExtState("SLIDE_OUT", "Pitch", pitch, false)
reaper.SetExtState("SLIDE_OUT", "Range", range, false)
reaper.SetExtState("SLIDE_OUT", "Bezier", bezier, false)
reaper.SetExtState("SLIDE_OUT", "Toggle", toggle, false)

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
if toggle == 1 then
  local seg = getSegments(range)
  if pitch > 0 then
    pitchbend = pitchUp(pitch, seg)
  else
    pitchbend = pitchDown(pitch, seg)
  end

  LSB = pitchbend & 0x7F
  MSB = (pitchbend >> 7) + 64
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, bezier, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_start+(loop_end-loop_start)*0.96, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 2 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchUp(i-math.abs(pitch)+math.abs(pitch), seg)
    else
      pitchbend = pitchDown(math.abs(pitch)-i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + ((loop_end-loop_start)*0.96) * (i/(math.abs(pitch))), 224, 0, LSB, MSB)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 3 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchUp(i-math.abs(pitch)+math.abs(pitch), seg)
    else
      pitchbend = pitchDown(math.abs(pitch)-i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + ((loop_end-loop_start)*0.96) * ((i+i)/(math.abs(pitch)+i)), 224, 0, LSB, MSB)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 4 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchDown((math.abs(pitch)-i), seg)
    else
      pitchbend = pitchUp((i-math.abs(pitch)), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    diff = math.floor(0.5 + (loop_end-loop_start) - ((loop_end-loop_start)*0.96))
    reaper.MIDI_InsertCC(take, false, false, loop_end + math.floor(0.5 + ((loop_end-loop_start)*0.96) * ((i+i)/-(math.abs(pitch)+i)) - diff), 224, 0, LSB, MSB)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()