-- @description Set Note Length by Percentage (Legacy)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
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
local getTakes = getAllTakes()

function Length1(take, f)
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

function Length2(take, f)
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

function StretchSelectedNotes(take, f)
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

function StretchSelectedCCs(take, f)
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
  title = "设置音符长度"
  lable = "输入百分比:,1=起始+持续 2=起始 3=持续"
elseif language == "繁體中文" then
  title = "設置音符長度"
  lable = "輸入百分比:,1=起始+持續 2=起始 3=持續"
else
  title = "Set Note Length"
  lable = "Enter percentage:,1=Start+Dur 2=Start 3=Durations"
end

local percent = reaper.GetExtState("SET_NOTE_LENGTH_PERCENT", "Percent")
if (percent == "") then percent = "200" end
local toggle = reaper.GetExtState("SET_NOTE_LENGTH_PERCENT", "Toggle")
if (toggle == "") then toggle = "1" end

local retval, retvals_csv = reaper.GetUserInputs(title, 2, lable, percent .. ',' .. toggle)
if not retval or not tonumber(percent) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
percent, toggle = retvals_csv:match("(%d*),(%d*)")
if tonumber(toggle) < 1 and tonumber(toggle) > 3 then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("SET_NOTE_LENGTH_PERCENT", "Percent", percent, false)
reaper.SetExtState("SET_NOTE_LENGTH_PERCENT", "Toggle", toggle, false)

local func
if not percent:match('[%d%.]+') or not tonumber(percent:match('[%d%.]+')) or not toggle:match('[%d%.]+') or not tonumber(toggle:match('[%d%.]+')) then return end
func = load("local x = ... return x*"..tonumber(percent:match('[%d%.]+')) / 100)
if not func then return end
reaper.Undo_BeginBlock()

for take, _ in pairs(getTakes) do
  if toggle == "3" then
    Length2(take, func)
  elseif toggle == "2" then
    Length1(take, func)
  elseif toggle == "1" then
    StretchSelectedNotes(take, func)
    StretchSelectedCCs(take, func)
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()