-- @description Select Tracks by Name
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

function UnselectAllTracks()
    firstTrack = reaper.GetTrack(0, 0)
    if firstTrack == nil then return end
    reaper.SetOnlyTrackSelected(firstTrack)
    reaper.SetTrackSelected(firstTrack, false)
end

function deleteTrackByName(findname)
    for i = reaper.CountTracks()-1, 0, -1 do 
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name == findname then
            reaper.DeleteTrack(track)   
            break -- 退出循環/僅刪除一個匹配項
        end 
    end
end

reaper.Undo_BeginBlock() -- 撤銷塊開始
reaper.PreventUIRefresh(1)

if language == "简体中文" then
    title = "按名称选择轨道"
    caption = "输入名称:"
elseif language == "繁體中文" then
    title = "按名稱選擇軌道"
    caption = "輸入名稱:"
else
    title = "Select Tracks by Name"
    caption = "Enter name:"
end

local uok, trackName = reaper.GetUserInputs(title, 1, caption, "")
if not uok then return end

UnselectAllTracks()

local countTracks = reaper.CountTracks(0)
local flagName
for i = 0, countTracks-1 do
    for j = 0, countTracks-1 do
        local track = reaper.GetTrack(0, j)
        if track ~= nil then
            reaper.SetTrackSelected(track, false)
            retval, noteName = reaper.GetTrackName(track, "")
            if retval then
                if noteName == trackName then
                    reaper.SetTrackSelected(track, true)
                end
            end
        end
    end
end

reaper.SelectAllMediaItems(0, false)

for k = 0, reaper.CountSelectedTracks(0)-1 do
    local slelTrack = reaper.GetSelectedTrack(0, k)
    local itemNum = reaper.CountTrackMediaItems(slelTrack)
    for i = 0, itemNum-1 do
        local item = reaper.GetTrackMediaItem(slelTrack, i)
        reaper.SetMediaItemSelected(item, true)
    end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()