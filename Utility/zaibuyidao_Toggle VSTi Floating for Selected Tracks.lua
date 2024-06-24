-- @description Toggle VSTi Floating for Selected Tracks
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

function toggle_vsti_float()
  reaper.Undo_BeginBlock()
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    track = reaper.GetSelectedTrack(0, i)
    parent_track = reaper.GetParentTrack(track)
    vsti = reaper.TrackFX_GetInstrument(track)
    if vsti ~= -1 then
      for i = 0, reaper.TrackFX_GetCount(track) - 1 do
        float_window = reaper.TrackFX_GetFloatingWindow(track, i)
        if float_window == nil then
          reaper.TrackFX_Show(track, i, 3)
        else
          reaper.TrackFX_Show(track, i, 2)
        end
      end
    else
      if parent_track ~= nil then
        vsti_parent_track = reaper.TrackFX_GetInstrument(parent_track)
        float_parent_window = reaper.TrackFX_GetFloatingWindow(parent_track, vsti_parent_track)
        if float_parent_window == nil then
          reaper.TrackFX_Show(parent_track, vsti_parent_track, 3)
        else
          reaper.TrackFX_Show(parent_track, vsti_parent_track, 2)
        end
        if vsti_parent_track == -1 then
          reaper.Main_OnCommandEx(40271, 0, 0)
        end
      else
        if vsti == -1 then
          reaper.Main_OnCommandEx(40271, 0, 0)
        end
      end
    end
  end
  reaper.Undo_EndBlock("Toggle VSTi Floating for Selected Tracks", -1)
end

toggle_vsti_float()