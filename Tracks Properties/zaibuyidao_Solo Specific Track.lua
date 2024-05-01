-- @description Solo Specific Track
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_eventlisteditor] .
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

function CheckShortcutSetting()
    local shortcutSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Items Editing/zaibuyidao_Solo Specific Track Setting.lua'

    if reaper.file_exists(shortcutSetting) then
        dofile(shortcutSetting)
    else
        reaper.MB(shortcutSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
        if reaper.APIExists('ReaPack_BrowsePackages') then
            reaper.ReaPack_BrowsePackages('zaibuyidao Solo Specific Track Setting')
        else
            reaper.MB('ReaPack extension not found', '', 0)
        end
    end
end

function unSoloTrack(n)
  track = reaper.GetTrack(0, n)
  reaper.CSurf_OnSoloChange(track, 0)
end

function soloTrack(n)
  local cntTracks = reaper.CountTracks(0)
  for i = 0, cntTracks - 1 do
    local track = reaper.GetTrack(0, i)
    if i == n then
        reaper.CSurf_OnSoloChange(track, 1)
    -- else
    --     reaper.CSurf_OnSoloChange(track, 0) -- 排除SOLO轨道
    end
  end
end

local num = reaper.GetExtState("SOLO_SPECIFIC_TRACK_SETTING", "Number")
if num == "" then
    CheckShortcutSetting()
    reaper.defer(function() end)
    num = reaper.GetExtState("SOLO_SPECIFIC_TRACK_SETTING", "Number")
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

function noUndoPoint() end
if flag then
    unSoloTrack(num)
else
    soloTrack(num)
end
reaper.defer(noUndoPoint)
reaper.UpdateArrange()
