-- @description Insert CC Events for Selected Notes
-- @version 1.0.1
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

local curPos = reaper.GetCursorPositionEx(0)
local ppqPos = reaper.MIDI_GetPPQPosFromProjTime(take, curPos)

local index = {}
local noteIndex = reaper.MIDI_EnumSelNotes(take, -1)
while noteIndex ~= -1 do
  table.insert(index, noteIndex)
  noteIndex = reaper.MIDI_EnumSelNotes(take, noteIndex)
end

local function getDefaultExtState(section, key, default)
  local value = reaper.GetExtState(section, key)
  if value == "" then
    return default
  end
  return value
end

local extSection   = "InsertCCEventsForSelectedNotes"
local defaultValue = "100"
local defaultCCNum = "11"

local valueStr = getDefaultExtState(extSection, "Value", defaultValue)
local ccNumStr = getDefaultExtState(extSection, "CC_Num", defaultCCNum)

if language == "简体中文" then
  promptTitle = "为选定音符插入CC事件"
  promptCaption = "数值:,CC编号:"
elseif language == "繁體中文" then
  promptTitle = "為選定音符插入CC事件"
  promptCaption = "數值:,CC編號:"
else
  promptTitle = "Insert CC Events for Selected Notes"
  promptCaption = "Value:,CC number:"
end

local uOK, uInput = reaper.GetUserInputs(promptTitle, 2, promptCaption, valueStr .. "," .. ccNumStr)
if not uOK then
  reaper.SN_FocusMIDIEditor()
  return
end

local valueInput, ccNumInput = uInput:match("([^,]+),([^,]+)")
valueInput = tonumber(valueInput)
ccNumInput = tonumber(ccNumInput)
if not (valueInput and ccNumInput) then
  reaper.SN_FocusMIDIEditor()
  return
end

reaper.SetExtState(extSection, "Value", tostring(valueInput), false)
reaper.SetExtState(extSection, "CC_Num", tostring(ccNumInput), false)

reaper.MIDIEditor_OnCommand(midiEditor, 40671) -- Unselect all CC events

if #index > 0 then
  -- 在选定音符起始位置插入CC事件
  for _, i in ipairs(index) do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if retval and selected then
      reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, ccNumInput, valueInput)
    end
  end
else
  -- 如果没有选中的音符则在当前光标处插入一个 CC 事件
  reaper.MIDI_InsertCC(take, true, false, ppqPos, 0xB0, 0, ccNumInput, valueInput)
end

local j = reaper.MIDI_EnumSelCC(take, -1)
while j ~= -1 do
  reaper.MIDI_SetCCShape(take, j, 0, 0, true)
  reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, true)
  j = reaper.MIDI_EnumSelCC(take, j)
end

reaper.UpdateArrange()
reaper.Undo_EndBlock(promptTitle, -1)
reaper.SN_FocusMIDIEditor()
