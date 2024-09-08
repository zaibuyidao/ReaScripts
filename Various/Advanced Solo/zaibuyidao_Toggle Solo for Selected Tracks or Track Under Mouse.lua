-- NoIndex: true
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

local function unselect_all_tracks()
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

local selected_track_count = reaper.CountSelectedTracks(0)
local screen_x, screen_y = reaper.GetMousePosition()
local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

if selected_track_count <= 1 then
    if track_ret then
        if reaper.GetMediaTrackInfo_Value(track_ret, 'I_SOLO') == 2 then
            return
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        end
        unselect_all_tracks()
        reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
        reaper.SetTrackSelected(track_ret, true)
        reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
    end
else
    for i = 0, selected_track_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        if reaper.GetMediaTrackInfo_Value(track, 'I_SOLO') == 2 then return reaper.Main_OnCommand(40340,0) end
    end
    
    reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
    
    for i = 0, selected_track_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        reaper.SetTrackSelected(track, true)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)