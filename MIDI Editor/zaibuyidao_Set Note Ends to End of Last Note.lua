-- @description Set Note Ends to End of Last Note
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

function table_max(t)
  local mn = nil
  for k, v in pairs(t) do
    if (mn == nil) then mn = v end
    if mn < v then mn = v end
  end
  return mn
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
  reaper.MIDI_DisableSort(take)
  local curpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
  local fng_take = reaper.FNG_AllocMidiTake(take)

  note_cnt, note_idx = 0, {}
  note_val = reaper.MIDI_EnumSelNotes(take, -1)
  while note_val ~= -1 do
    note_cnt = note_cnt + 1
    note_idx[note_cnt] = note_val
    note_val = reaper.MIDI_EnumSelNotes(take, note_val)
  end

  end_ppq = {}
  for i = 1, #note_idx do
    local cur_note = reaper.FNG_GetMidiNote(fng_take, note_idx[i])
    local start_ppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION")
    local length = reaper.FNG_GetMidiNoteIntProperty(cur_note, "LENGTH")
    end_ppq[i] = start_ppq+length
  end
  max_endppq = table_max(end_ppq)

  for i = 1, #note_idx do
    local cur_note = reaper.FNG_GetMidiNote(fng_take, note_idx[i])
    local start_ppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION")
    local endpos = max_endppq - start_ppq
    reaper.FNG_SetMidiNoteIntProperty(cur_note, "LENGTH", endpos)
  end

  reaper.FNG_FreeMidiTake(fng_take)
  reaper.MIDI_Sort(take)
end
reaper.Undo_EndBlock("Set Note Ends to End of Last Note", -1)
reaper.UpdateArrange()