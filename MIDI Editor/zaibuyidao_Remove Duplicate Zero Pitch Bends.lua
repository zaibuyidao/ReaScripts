-- @description Remove Duplicate Zero Pitch Bends
-- @version 1.0
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

  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= -1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  local idx = -1
  local lastWasZero = false

  reaper.MIDI_DisableSort(take)

  for i = 1, #index do
    index[i] = reaper.MIDI_EnumSelCC(take, idx)
    local _, _, _, _, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    if chanmsg == 224 then
      local pitchbend = msg2 + msg3 * 128
      if pitchbend == 8192 then
        if lastWasZero then
          reaper.MIDI_DeleteCC(take, index[i])
        else
          lastWasZero = true
          idx = index[i]
        end
      else
        lastWasZero = false
        idx = index[i]
      end
    else
      idx = index[i]
    end
  end

  reaper.MIDI_Sort(take)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
RemoveDuplicateZeroPitchBends()
reaper.Undo_EndBlock("Remove Duplicate Zero Pitch Bends", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()