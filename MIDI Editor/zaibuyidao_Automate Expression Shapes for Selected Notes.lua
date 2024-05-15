-- @description Automate Expression Shapes for Selected Notes
-- @version 1.0.2
-- @author zaibuyidao, YS
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   This script is used to automate the expression of selected notes in REAPER by inserting Control Change (CC) messages into the MIDI data of the notes.
--   The script automatically inserts CC messages based on the length and position of the notes at specified intervals, thereby automating the dynamic expression of the notes.
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
local getTakes = getAllTakes()
if not checkMidiNoteSelected() then return end

-- dangguidan的速度代码优化版
function bpm_average()
  local minPPQ = math.huge
  local maxPPQ = -1
  local editor = reaper.MIDIEditor_GetActive()

  if not editor then
    reaper.ShowMessageBox("No active MIDI editor found.", "Error", 0)
    return
  end

  local takeIndex = 0
  local take = reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)
  local validTake = nil  -- 用于存储最后一个有效的 take

  while take do
    reaper.MIDI_DisableSort(take)
    local noteIndex = -1
    local note = reaper.MIDI_EnumSelNotes(take, noteIndex)
    while note ~= -1 do
      local _, _, _, startPPQ, endPPQ = reaper.MIDI_GetNote(take, note)
      minPPQ = math.min(minPPQ, startPPQ)
      maxPPQ = math.max(maxPPQ, endPPQ)
      noteIndex = note
      note = reaper.MIDI_EnumSelNotes(take, noteIndex)
    end
    reaper.MIDI_Sort(take)

    validTake = take  -- 更新最后一个有效的 take
    takeIndex = takeIndex + 1
    take = reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)
  end

  if not validTake or maxPPQ == -1 then
    reaper.ShowMessageBox("No valid take or selected notes found.", "Error", 0)
    return
  end

  local firstQN = reaper.MIDI_GetProjQNFromPPQPos(validTake, minPPQ)
  local endTime = reaper.MIDI_GetProjTimeFromPPQPos(validTake, maxPPQ)

  local totalBPM = 0
  local qnCount = 0
  local pos = reaper.TimeMap_QNToTime(firstQN)
  local ptIdx = reaper.FindTempoTimeSigMarker(0, pos)
  local retval, _, _, _, bpm = reaper.GetTempoTimeSigMarker(0, ptIdx)

  if bpm == 0 then
    bpm = reaper.Master_GetTempo()  -- 直接获取工程的全局BPM
  end

  while pos < endTime do
    totalBPM = totalBPM + bpm
    qnCount = qnCount + 1
    firstQN = firstQN + 1
    pos = reaper.TimeMap_QNToTime(firstQN)
    ptIdx = reaper.FindTempoTimeSigMarker(0, pos)
    retval, _, _, _, bpm = reaper.GetTempoTimeSigMarker(0, ptIdx)

    if bpm == 0 then
      bpm = reaper.Master_GetTempo()  -- 如果标尺上没有速度变化，使用全局BPM
    end
  end

  local averageBPM = totalBPM / qnCount
  return averageBPM
end

bpm_average = bpm_average()

if language == "简体中文" then
  title = "自动表情形狀 (平均速度: " .. bpm_average ..")"
  captions_csv = "CC编号,最小值,最大值,速度 (1=慢速 2=快速 3=自动),开始弧度 (-100 至 100),结束弧度 (-100 至 100),extrawidth=20"
elseif language == "繁体中文 " then
  title = "自動表情形狀 (平均速度: " .. bpm_average ..")"
  captions_csv = "CC編號,最小值,最大值,速度 (1=慢速 2=快速 3=自動),開始弧度 (-100 至 100),結束弧度 (-100 至 100),extrawidth=20"
else
  title = "Automate Expression Shapes (BPM: " .. bpm_average ..")"
  captions_csv = "CC number,Minimum,Maximum,Speed (1=alow 2=fast 3=auto),Bezier in (-100 to 100),Bezier out (-100 to 100),extrawidth=20"
end

local cc_num = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "CC")
if (cc_num == "") then cc_num = "11" end
local val_01 = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "Val1")
if (val_01 == "") then val_01 = "88" end
local val_02 = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "Val2")
if (val_02 == "") then val_02 = "127" end
local speed = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "Speed")
if (speed == "") then speed = "3" end
local bezier_in = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "BezierIn")
if (bezier_in == "") then bezier_in = "-25" end
local bezier_out = reaper.GetExtState("AutomateExpressionShapesforSelectedNotes", "BezierOut")
if (bezier_out == "") then bezier_out = "40" end
local flag = 0

local uok, uinput_csv = reaper.GetUserInputs(title, 6, captions_csv, cc_num..','..val_01..','.. val_02..','.. speed..','..bezier_in..','.. bezier_out)
if not uok then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = uinput_csv:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(val_01) or not tonumber(val_02)  or not tonumber(speed) or not tonumber(bezier_in) or not tonumber(bezier_out) then return reaper.SN_FocusMIDIEditor() end
cc_num, val_01, val_02, speed, bezier_in, bezier_out = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(speed), tonumber(bezier_in), tonumber(bezier_out)

reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "CC", cc_num, false)
reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "Val1", val_01, false)
reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "Val2", val_02, false)
reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "Speed", speed, false)
reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "BezierIn", bezier_in, false)
reaper.SetExtState("AutomateExpressionShapesforSelectedNotes", "BezierOut", bezier_out, false)

function StartInsert(take)
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  quaver = false
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    if speed == 1 then
      if len >= (tick / 2) and len < tick then -- 如果长度大于等于 240 并且 长度小于 480
        if quaver == false then
          reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
          quaver = true
        else
          reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, math.modf(val_01 + ((val_02 - val_01) / 3)))
        end
        reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.4), 0xB0, chan, cc_num, val_02)
      else
        quaver = false
      end
    elseif speed == 3 then
      if bpm_average < 96 then
        if len >= (tick / 2) and len < tick then -- 如果长度大于等于 240 并且 长度小于 480
          if quaver == false then
            reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
            quaver = true
          else
            reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, math.modf(val_01 + ((val_02 - val_01) / 3)))
          end
          reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.4), 0xB0, chan, cc_num, val_02)
        else
          quaver = false
        end
      end
    end

    if len >= tick and len < tick * 2 then -- 如果长度大于等于 480 并且 长度小于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 0.75), 0xB0, chan, cc_num, val_02)
    end
    if len == tick * 2 then -- 如果长度等于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + tick, 0xB0, chan, cc_num, val_02)
    end
    if len > tick * 2 then -- 如果长度大于 960
      reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, cc_num, val_01)
      reaper.MIDI_InsertCC(take, false, muted, startppqpos + (tick * 1.5), 0xB0, chan, cc_num, val_02)
    end
    if speed == 1 then speed_note = (tick / 2) else speed_note = tick end
    if len > 0 and len < speed_note then -- 如果长度大于0 并且小于 240
      if flag == 0 then
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, cc_num, val_02)
        flag = 1
      end
    else
      flag = 0
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_in / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

function EndInsert(take)
  reaper.MIDI_DisableSort(take)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local len = endppqpos - startppqpos
    local val_03 = math.modf(((val_02-val_01)/val_02)*65) + val_01
    if len >= tick * 2 then -- 如果长度大于等于 960
      reaper.MIDI_InsertCC(take, true, muted, endppqpos - (tick * 0.75), 0xB0, chan, cc_num, val_02)
      reaper.MIDI_InsertCC(take, false, muted, endppqpos - (tick / 24), 0xB0, chan, cc_num, val_03)
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 5, bezier_out / 100, true)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
    j = reaper.MIDI_EnumSelCC(take, j)
  end

  reaper.MIDI_Sort(take)
end

tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 支持多轨编辑的旧式写法
-- count_sel_items = reaper.CountSelectedMediaItems(0)
-- if count_sel_items > 0 then
--   for i = 1, count_sel_items do
--     item = reaper.GetSelectedMediaItem(0, i - 1)
--     take = reaper.GetTake(item, 0)
--     if not take or not reaper.TakeIsMIDI(take) then return end
--     StartInsert()
--     EndInsert()
--   end
-- else
--   take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
--   if not take or not reaper.TakeIsMIDI(take) then return end
--   StartInsert()
--   EndInsert()
-- end

for take, _ in pairs(getTakes) do
  reaper.MIDI_DisableSort(take)
  StartInsert(take)
  EndInsert(take)
  reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()