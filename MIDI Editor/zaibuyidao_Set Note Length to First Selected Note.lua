-- @description Set Note Length to First Selected Note
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

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end
  local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
  local cnt, index = 0, {}
  local enum_sel_note = false
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  if val ~= -1 then enum_sel_note = true end
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end

  if #index > 1 then
    local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local notelen = endpos - startpos
    reaper.MIDI_DisableSort(take)
    for i = 1, #index do
      local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, index[i])
      reaper.MIDI_SetNote(take, index[i], nil, nil, startppqpos, startppqpos + notelen, nil, nil, nil, false)
    end
    reaper.MIDI_Sort(take)
  elseif #index == 1 then
    local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local notelen = endpos - startpos
    reaper.MIDI_DisableSort(take)
    for i = 0, notecnt - 1 do
      local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i)
      reaper.MIDI_SetNote(take, i, false, nil, startppqpos, startppqpos + notelen, nil, nil, nil, false)
    end

    reaper.MIDI_Sort(take)
  end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Set Note Length to First Selected Note", -1)
reaper.UpdateArrange()