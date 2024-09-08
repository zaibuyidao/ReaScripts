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

function CheckShortcutSetting()
    local shortcutSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Tracks Properties/zaibuyidao_Toggle Solo for Specific Track Setting.lua'

    if reaper.file_exists(shortcutSetting) then
        dofile(shortcutSetting)
    else
        reaper.MB(shortcutSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
        if reaper.APIExists('ReaPack_BrowsePackages') then
            reaper.ReaPack_BrowsePackages('zaibuyidao Toggle Solo for Specific Track Setting')
        else
            reaper.MB('ReaPack extension not found', '', 0)
        end
    end
end

function unSoloTrack(n)
    local track = reaper.GetTrack(0, n)
    if track then
        reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
    end
end

function soloTrack(n)
    local cntTracks = reaper.CountTracks(0)
    for i = 0, cntTracks - 1 do
        local track = reaper.GetTrack(0, i)
        if i == n then
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 2)
        else
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

function noUndoPoint() end
reaper.PreventUIRefresh(1)
local num = reaper.GetExtState("TOGGLE_SOLO_FOR_SPECIFIC_TRACK_SETTING", "Number")
if num == "" then
    CheckShortcutSetting()
    reaper.defer(function() end)
    num = reaper.GetExtState("TOGGLE_SOLO_FOR_SPECIFIC_TRACK_SETTING", "Number")
end
num = tonumber(num) - 1

cntTracks = reaper.CountTracks(0)
for i = 0, cntTracks - 1 do
    track = reaper.GetTrack(0, i)
    if i == num then
        iSOLO = reaper.GetMediaTrackInfo_Value(track, 'I_SOLO')
        if iSOLO == 1 or iSOLO == 2 then
            flag = true
        elseif iSOLO == 0 then
            flag = false
        end
    end
end

if flag then
    unSoloTrack(num)
else
    soloTrack(num)
end
reaper.PreventUIRefresh(-1)
reaper.defer(noUndoPoint)
reaper.UpdateArrange()