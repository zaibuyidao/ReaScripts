-- @description Play from First Item Start in Selected Tracks
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

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

-- 获取选中轨道的数量
local track_count = reaper.CountSelectedTracks(0)
if track_count == 0 then
    if language == "简体中文" then
        reaper.ShowMessageBox("未选中任何轨道。", "错误", 0)
    elseif language == "繁體中文" then
        reaper.ShowMessageBox("未選中任何軌道。", "錯誤", 0)
    else
        reaper.ShowMessageBox("No tracks selected.", "Error", 0)
    end
    return
end

-- 初始化变量
local first_item_start = nil

-- 遍历所有选中的轨道
for i = 0, track_count - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    
    -- 获取轨道上的第一个item
    local item_count = reaper.CountTrackMediaItems(track)
    if item_count > 0 then
        local item = reaper.GetTrackMediaItem(track, 0)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        
        -- 更新 first_item_start，如果是第一个item或者比当前的item开始时间更早
        if not first_item_start or item_start < first_item_start then
            first_item_start = item_start
        end
    end
end

if not first_item_start then
    if language == "简体中文" then
        reaper.ShowMessageBox("选中的轨道中没有找到任何item。", "错误", 0)
    elseif language == "繁體中文" then
        reaper.ShowMessageBox("選中的軌道中沒有找到任何item。", "錯誤", 0)
    else
        reaper.ShowMessageBox("No items found in selected tracks.", "Error", 0)
    end
   
    return
end

-- 将编辑光标移动到第一个item的开始位置
reaper.SetEditCurPos(first_item_start, false, false)
reaper.Main_OnCommand(1007, 0) -- Transport: Play
reaper.PreventUIRefresh(-1)
reaper.defer(NoUndoPoint)