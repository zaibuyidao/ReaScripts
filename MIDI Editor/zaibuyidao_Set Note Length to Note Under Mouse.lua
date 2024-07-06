-- @description Set Note Length to Note Under Mouse
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local selected_note_count, selected_note_indices = 0, {}
local has_selected_notes = false
local note_index = reaper.MIDI_EnumSelNotes(take, -1)
if note_index ~= -1 then has_selected_notes = true end
while note_index ~= -1 do
    selected_note_count = selected_note_count + 1
    selected_note_indices[selected_note_count] = note_index
    note_index = reaper.MIDI_EnumSelNotes(take, note_index)
end

local window, segment, details = reaper.BR_GetMouseCursorContext()
local _, _, mouse_note_pitch, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
local mouse_ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.BR_GetMouseCursorContext_Position())
local _, total_notes, _, _ = reaper.MIDI_CountEvts(take)
reaper.Undo_BeginBlock()

local mouse_note_length = nil
local mouse_note_index = nil

for i = 0, total_notes - 1 do
    local _, _, _, start_ppq_pos, end_ppq_pos, _, pitch, _ = reaper.MIDI_GetNote(take, i)
    if start_ppq_pos <= mouse_ppq_pos and end_ppq_pos >= mouse_ppq_pos and mouse_note_pitch == pitch then
        mouse_note_length = end_ppq_pos - start_ppq_pos
        mouse_note_index = i
        -- reaper.MB(string.format(
        --     "Mouse Info: Window: %s, Segment: %s, Details: %s\n",
        --     tostring(window), tostring(segment), tostring(details)
        -- ))
        -- reaper.MB(string.format(
        --     "Note Index: %d\nStart PPQ: %d\nEnd PPQ: %d\nMouse PPQ: %d\nNote Length: %d\n",
        --     i,
        --     math.floor(start_ppq_pos),
        --     math.floor(end_ppq_pos),
        --     math.floor(mouse_ppq_pos),
        --     math.floor(mouse_note_length)
        -- ))
        break -- 找到一个匹配的音符后立即退出循环
    end
end

if not mouse_note_length then
    reaper.MB("Unable to get the length of the note under the mouse", "Error", 0)
    reaper.Undo_EndBlock("Set Note Length to Note Under Mouse", -1)
    return
end

reaper.MIDI_DisableSort(take)
if #selected_note_indices > 0 then
    for i = 1, #selected_note_indices do
        local _, _, _, start_ppq_pos, _, _, _, _ = reaper.MIDI_GetNote(take, selected_note_indices[i])
        reaper.MIDI_SetNote(take, selected_note_indices[i], nil, nil, start_ppq_pos, start_ppq_pos + mouse_note_length, nil, nil, nil, false)
    end
else
    for i = 0, total_notes - 1 do
        local _, _, _, start_ppq_pos, _, _, _, _ = reaper.MIDI_GetNote(take, i)
        reaper.MIDI_SetNote(take, i, false, nil, start_ppq_pos, start_ppq_pos + mouse_note_length, nil, nil, nil, false)
    end
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Set Note Length to Note Under Mouse", -1)
reaper.UpdateArrange()
