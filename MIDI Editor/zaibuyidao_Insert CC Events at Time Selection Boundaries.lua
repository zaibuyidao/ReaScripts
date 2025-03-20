-- @description Insert CC Events at Time Selection Bounds
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

local selected = true           -- 是否选中插入的CC事件
local chan = 0                  -- MIDI 通道(0代表通道1)
local muted = false             -- 插入的事件是否静音

if language == "简体中文" then
  title = "在时间选区边界处插入CC事件"
  captionsCsv = "CC编号,起始值,结束值"
  TXT_1 = "请先设置时间选区范围"
  TXT_2 = "错误"
elseif language == "繁體中文" then
  title = "在時間選區邊界處插入CC事件"
  captionsCsv = "CC編號,起始值,結束值"
  TXT_1 = "請先設置時間選區範圍"
  TXT_2 = "錯誤"
else
  title = "Insert CC Events at Time Selection Bounds"
  captionsCsv = "CC Number,Value at Start,Value at End"
  TXT_1 = "Please set the time selection range first."
  TXT_2 = "Error"
end

reaper.Undo_BeginBlock()
local midiEditor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(midiEditor)
local loopStart, loopEnd = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local ppqStart = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, loopStart))
local ppqEnd   = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, loopEnd))
local ppqRange = ppqEnd - ppqStart

if ppqRange == 0 then
  reaper.MB(TXT_1, TXT_2, 0)
  reaper.SN_FocusMIDIEditor()
  return
end

local extStateSection = "InsertCCEventsAtTimeSelectionBounds"
local ccNumber = reaper.GetExtState(extStateSection, "Msg2")
if ccNumber == "" then ccNumber = "11" end
local valueAtStart = reaper.GetExtState(extStateSection, "Msg3")
if valueAtStart == "" then valueAtStart = "100" end
local valueAtEnd = reaper.GetExtState(extStateSection, "Msg4")
if valueAtEnd == "" then valueAtEnd = "0" end

local uOK, uInput = reaper.GetUserInputs(title, 3, captionsCsv, ccNumber .. ',' .. valueAtStart .. ',' .. valueAtEnd)
if not uOK then
  reaper.SN_FocusMIDIEditor()
  return
end

local ccNumberStr, valueStartStr, valueEndStr = uInput:match("(.*),(.*),(.*)")
if not tonumber(ccNumberStr) or not tonumber(valueStartStr) or not tonumber(valueEndStr) then
  reaper.SN_FocusMIDIEditor()
  return
end

reaper.SetExtState(extStateSection, "Msg2", ccNumberStr, false)
reaper.SetExtState(extStateSection, "Msg3", valueStartStr, false)
reaper.SetExtState(extStateSection, "Msg4", valueEndStr, false)

local ccNumber = tonumber(ccNumberStr)
local ccValueAtStart = tonumber(valueStartStr)
local ccValueAtEnd = tonumber(valueEndStr)

reaper.MIDIEditor_OnCommand(midiEditor, 40214) -- Unselect all events
reaper.MIDI_InsertCC(take, selected, muted, ppqStart, 0xB0, chan, ccNumber, ccValueAtStart)
reaper.MIDI_InsertCC(take, selected, muted, ppqEnd,   0xB0, chan, ccNumber, ccValueAtEnd)

local j = reaper.MIDI_EnumSelCC(take, -1)
while j ~= -1 do
  reaper.MIDI_SetCCShape(take, j, 0, 0, true)
  reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
  j = reaper.MIDI_EnumSelCC(take, j)
end

reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()