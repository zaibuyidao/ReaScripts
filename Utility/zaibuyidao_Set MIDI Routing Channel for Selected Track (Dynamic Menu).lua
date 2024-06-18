-- @description Set MIDI Routing Channel for Selected Track (Dynamic Menu)
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

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track > 1 then return end

for i = 0, count_sel_track-1 do
    select_track = reaper.GetSelectedTrack(0, i)
    select_track_num = reaper.GetMediaTrackInfo_Value(select_track,'IP_TRACKNUMBER')
    isVSTi = reaper.TrackFX_GetInstrument(select_track) -- 判断是否为VSTi
    if isVSTi ~= -1 then return end

    track_unm_send = reaper.GetTrackNumSends(select_track, 0)
    if track_unm_send < 1 then return end

    MIDIflags = reaper.GetTrackSendInfo_Value(select_track, 0, 0, 'I_MIDIFLAGS')
    MIDIflags = MIDIflags / 32

    -- reaper.SetTrackSendInfo_Value(select_track, 0, 0, 'I_SRCCHAN', -1)
end

local routing = {}
for m = 0, 17-1 do
    if MIDIflags == m then
        routing[#routing + 1] = {cur = true, idx = m}
    else
        routing[#routing + 1] = {cur = false, idx = m}
    end
end

local menu = "" -- #MIDI||
for r = 1, #routing do
    if r == 1 then
        menu = menu .. (routing[r].cur and "!" or "") .. 'All' .. "|"
    else
        menu = menu .. (routing[r].cur and "!" or "") .. routing[r].idx .. "|"
    end
end

local title = "hidden " .. reaper.genGuid()
gfx.init( title, 0, 0, 0, 0, 0 )
local hwnd = reaper.JS_Window_Find( title, true )
if hwnd then
  reaper.JS_Window_Show( hwnd, "HIDE" )
end
gfx.x, gfx.y = gfx.mouse_x-0, gfx.mouse_y-0
local selection = gfx.showmenu(menu)
gfx.quit()

if selection > 0 then
    selection = selection - 0 -- 如果使用标题，那么将0值改为-1
    for i = 1, 17 do
        for s = 0, track_unm_send-1 do
            if selection == i then reaper.SetTrackSendInfo_Value(select_track, 0, s, 'I_MIDIFLAGS', (i - 1) << 5) end
        end
    end
end

reaper.defer(function() end)