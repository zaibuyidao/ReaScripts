-- @description Remove Duplicate Zero Pitch Bends
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
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

function RemoveDuplicateZeroPitchBends(take)
  if not take then return end

  reaper.MIDI_DisableSort(take)

  -- 收集所有 pitch bend 0 事件
  local _, _, cc_cnt, _ = reaper.MIDI_CountEvts(take)
  local del = {}
  local lastWasZero = false

  -- 所有事件扫一遍, 收集pitch bend 0的顺序
  local pb_idx = {}
  for i = 0, cc_cnt - 1 do
    local _, _, _, _, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if chanmsg == 224 then
      local pitchbend = msg2 + msg3 * 128
      table.insert(pb_idx, {idx = i, val = pitchbend})
    end
  end

  -- 找到所有连续的8192, 并记录要删的index
  for i = 2, #pb_idx do
    if pb_idx[i].val == 8192 and pb_idx[i-1].val == 8192 then
      table.insert(del, pb_idx[i].idx)
    end
  end

  -- 从大到小删
  table.sort(del, function(a, b) return a > b end)
  for _, idx in ipairs(del) do
    reaper.MIDI_DeleteCC(take, idx)
  end

  reaper.MIDI_Sort(take)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local editor = reaper.MIDIEditor_GetActive()
if editor then
  local take = reaper.MIDIEditor_GetTake(editor)
  RemoveDuplicateZeroPitchBends(take)
end
reaper.Undo_EndBlock("Remove Duplicate Zero Pitch Bends", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()