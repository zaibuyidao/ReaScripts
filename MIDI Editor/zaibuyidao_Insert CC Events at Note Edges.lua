-- @description Insert CC Events at Note Edges
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

reaper.Undo_BeginBlock()
local midiEditor = reaper.MIDIEditor_GetActive()
if not midiEditor then return end
local take = reaper.MIDIEditor_GetTake(midiEditor)
if not take then return end

local item = reaper.GetMediaItemTake_Item(take)
local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)

local selectedNotes = {}
local noteIndex = reaper.MIDI_EnumSelNotes(take, -1)
while noteIndex ~= -1 do
  table.insert(selectedNotes, noteIndex)
  noteIndex = reaper.MIDI_EnumSelNotes(take, noteIndex)
end

-- 从扩展状态中获取值或使用默认值
local function getExtStateOrDefault(section, key, default)
  local state = reaper.GetExtState(section, key)
  if state == "" then
    return default
  end
  return state
end

local section = "InsertCCEventsAtNoteEdges"
local ccNumDefault      = "64"
local ccValueOnDefault  = "127"
local ccValueOffDefault = "0"
local firstOffsetDefault  = "10"
local secondOffsetDefault = "-10"

local ccNum      = getExtStateOrDefault(section, "Msg2", ccNumDefault)
local ccValueOn  = getExtStateOrDefault(section, "Msg3", ccValueOnDefault)
local ccValueOff = getExtStateOrDefault(section, "Msg4", ccValueOffDefault)
local firstOffset  = getExtStateOrDefault(section, "FirstOffset", firstOffsetDefault)
local secondOffset = getExtStateOrDefault(section, "SecondOffset", secondOffsetDefault)

if language == "简体中文" then
  scriptTitle = "在音符边缘插入CC事件"
  captionsCsv = "CC编号:,起始数值:,结束数值:,起始偏移:,结束偏移:"
elseif language == "繁體中文" then
  scriptTitle = "在音符邊緣插入CC事件"
  captionsCsv = "CC編號:,起始數值:,結束數值:,起始偏移:,結束偏移:"
else
  scriptTitle = "Insert CC Events at Note Edges"
  captionsCsv = "CC number:,Start value:,End value:,Start offset:,End offset:"
end

local uOK, uInput = reaper.GetUserInputs(scriptTitle, 5, captionsCsv, ccNum .. "," .. ccValueOn .. "," .. ccValueOff .. "," .. firstOffset .. "," .. secondOffset)
if not uOK then 
  reaper.SN_FocusMIDIEditor()
  return 
end

ccNum, ccValueOn, ccValueOff, firstOffset, secondOffset = uInput:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
if not (tonumber(ccNum) and tonumber(ccValueOn) and tonumber(ccValueOff) and tonumber(firstOffset) and tonumber(secondOffset)) then
  reaper.SN_FocusMIDIEditor()
  return
end

reaper.SetExtState(section, "Msg2", ccNum, false)
reaper.SetExtState(section, "Msg3", ccValueOn, false)
reaper.SetExtState(section, "Msg4", ccValueOff, false)
reaper.SetExtState(section, "FirstOffset", firstOffset, false)
reaper.SetExtState(section, "SecondOffset", secondOffset, false)

reaper.MIDIEditor_OnCommand(midiEditor, 40671) -- Unselect all CC events

-- 在指定音符上插入CC事件
local function insertCCForNote(noteIdx)
  local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, noteIdx)
  if retval then
    reaper.MIDI_InsertCC(take, selected, muted, startppq + tonumber(firstOffset), 0xB0, chan, tonumber(ccNum), tonumber(ccValueOn))
    reaper.MIDI_InsertCC(take, selected, muted, endppq + tonumber(secondOffset), 0xB0, chan, tonumber(ccNum), tonumber(ccValueOff))
  end
end

-- 根据是否有选中的音符来决定处理范围
if #selectedNotes > 0 then
  for _, noteIdx in ipairs(selectedNotes) do
    insertCCForNote(noteIdx)
  end
else
  for i = 0, noteCount - 1 do
    insertCCForNote(i)
  end
end

local j = reaper.MIDI_EnumSelCC(take, -1)
while j ~= -1 do
  reaper.MIDI_SetCCShape(take, j, 0, 0, true)
  reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
  j = reaper.MIDI_EnumSelCC(take, j)
end

reaper.UpdateItemInProject(item)
reaper.Undo_EndBlock(scriptTitle, -1)
reaper.SN_FocusMIDIEditor()
