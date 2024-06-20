-- @description Bend
-- @version 1.0.3
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
language = ""
local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_end <= loop_start then return reaper.SN_FocusMIDIEditor() end
local loop_len = loop_end - loop_start

if language == "简体中文" then
  title = "推弦"
  captions_csv = "弯音间隔:,弯音范围:,1=保持 2=立即 3=反向"
  msgint = "弯音间隔不能大于弯音范围"
  msgerr = "错误"
elseif language == "繁體中文" then
  title = "推弦"
  captions_csv = "彎音間隔:,彎音範圍:,1=保持 2=立即 3=反向"
  msgint = "彎音間隔不能大於彎音範圍"
  msgerr = "錯誤"
else
  title = "Bend"
  captions_csv = "Bend interval:,Pitchwheel Range:,1=Hold 2=Immediate 3=Reverse"
  msgint = "The pitch bend interval cannot exceed the pitchwheel range."
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