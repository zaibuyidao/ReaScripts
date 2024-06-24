-- @description Automatic Load VSTi for MIDI Playback
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

local section = "AutomaticLoadVSTiForMIDIPlayback"
local key = "VSTiName"

-- 尝试获取保存的 VSTi 名称
local vstiName = reaper.GetExtState(section, key)

if vstiName == "" then
    vstiName = "SOUND Canvas VA"
end

reaper.PreventUIRefresh(1) -- 防止界面更新
reaper.Undo_BeginBlock() -- 撤销块开始
-- 插入一条新的音轨
local new_track_idx = reaper.CountTracks(0)
reaper.InsertTrackAtIndex(new_track_idx, true)
local new_track = reaper.GetTrack(0, new_track_idx)

if language == "简体中文" then
    title = "自动加载 VSTi 以进行 MIDI 回放"
    msgset = "无法找到指定的 VSTi 插件。\n\n请通过脚本 'zaibuyidao_Automatic Load VSTi For MIDI Playback (Settings).lua' 设置 VSTi 名称。"
    msgerr = "错误"
elseif language == "繁體中文" then
    title = "自動加載 VSTi 以進行 MIDI 回放"
    msgset = "無法找到指定的 VSTi 插件。\n\n請通過腳本 'zaibuyidao_Automatic Load VSTi For MIDI Playback (Settings).lua' 設置 VSTi 名稱。"
    msgerr = "錯誤"
else
    title = "Automatic Load VSTi for MIDI Playback"
    msgset = "Unable to find the specified VSTi plugin.\n\nPlease set the VSTi name through the script 'zaibuyidao_Automatic Load VSTi For MIDI Playback (Settings).lua'."
    msgerr = "Error"
end

-- 在新音轨上添加 VSTi 插件
local fxIdx = reaper.TrackFX_AddByName(new_track, vstiName, false, 1)

if fxIdx == -1 then
    reaper.ShowMessageBox(msgset, msgerr, 0)
else
    -- 去除名称中的 "VSTi: " 前缀并设置为轨道名称
    local trackName = string.gsub(vstiName, "VSTi: ", "")
    reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", trackName, true)
    -- 为除新音轨外的所有音轨添加接收
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        if track ~= new_track then
            reaper.SNM_AddReceive(track, new_track, -1) -- 添加接收，类型为默认
        end
    end
end
reaper.Undo_EndBlock(title, -1) -- 撤销块结束
reaper.PreventUIRefresh(-1) -- 恢复界面更新
reaper.UpdateArrange() -- 更新界面显示