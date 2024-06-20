-- @description Linear Ramp Pitch Bend Within Time Selection
-- @version 1.0.1
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

step = 128
selected = true
muted = false
chan = 0

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_end <= loop_start then return reaper.SN_FocusMIDIEditor() end
local loop_len = loop_end - loop_start
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

local bend_start = reaper.GetExtState("Bend", "Start")
if (bend_start == "") then bend_start = "0" end
local bend_end = reaper.GetExtState("Bend", "End")
if (bend_end == "") then bend_end = "1408" end

if language == "简体中文" then
  title = "线性斜坡时间选区内的弯音"
  captions_csv = "开始:,结束:"
elseif language == "繁體中文" then
  title = "綫性斜坡時間選區内的彎音"
  captions_csv = "開始:,結束:"
else
  title = "Linear Ramp Pitch Bend Within Time Selection"
  captions_csv = "Start:,End:"
end

local uok, uinput = reaper.GetUserInputs(title, 2, captions_csv, bend_start..','..bend_end)
if not uok then return reaper.SN_FocusMIDIEditor() end
bend_start, bend_end = uinput:match("(.*),(.*)")
if not tonumber(bend_start) or not tonumber(bend_end) then return reaper.SN_FocusMIDIEditor() end
bend_start, bend_end = tonumber(bend_start), tonumber(bend_end)

if bend_start < -8192 or bend_start > 8191 or bend_end < -8192 or bend_end > 8191 then
  return reaper.MB("Please enter a value from -8192 through 8191", "Error", 0), reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("Bend", "Start", bend_start, false)
reaper.SetExtState("Bend", "End", bend_end, false)

local t = {}
if bend_start < bend_end then
  for j = bend_start - 1, bend_end, step do
    j = j + 1
    table.insert(t, j)
  end
end

if bend_start > bend_end then
  for y = bend_end - 1, bend_start, step do
    y = y + 1
    table.insert(t, y)
    table.sort(t,function(bend_start,bend_end) return bend_start > bend_end end)
  end
end

reaper.Undo_BeginBlock()
for k, v in pairs(t) do
  local value = v + 8192
  local LSB = value & 0x7f
  local MSB = value >> 7 & 0x7f
  local interval = math.floor(loop_len/#t)
  reaper.MIDI_InsertCC(take, selected, muted, loop_start+(k-1)*(interval*0.40), 224, chan, LSB, MSB)
  local interval = math.floor(loop_len/-#t)
  reaper.MIDI_InsertCC(take, selected, muted, loop_end+(k-1)*(interval*0.40), 224, chan, LSB, MSB)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()