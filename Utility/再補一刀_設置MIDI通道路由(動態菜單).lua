--[[
 * ReaScript Name: 設置MIDI通道路由(動態菜單)
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-19)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

if not reaper.APIExists("JS_Window_Find") then
    reaper.MB("請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'. 然後重新啟動 REAPER 並再次運行腳本. 謝謝!", "你必須安裝 JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, "出了些問題...", 0)
    end
    return reaper.defer(function() end)
end

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track > 1 then return end

for i = 0, count_sel_track-1 do
    select_track = reaper.GetSelectedTrack(0, i)
    select_track_num = reaper.GetMediaTrackInfo_Value(select_track,'IP_TRACKNUMBER')
    isVSTi = reaper.TrackFX_GetInstrument(select_track) -- 判斷是否為VSTi
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

local menu = "" -- #Channel|| -- 標題
for r = 1, #routing do
    menu = menu .. (routing[r].cur and "!" or "") .. 'Channel ' .. routing[r].idx .. "|"
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
    selection = selection - 0 -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2
    for i = 1, 17 do
        for s = 0, track_unm_send-1 do
            if selection == i then reaper.SetTrackSendInfo_Value(select_track, 0, s, 'I_MIDIFLAGS', (i - 1) << 5) end
        end
    end
end

reaper.defer(function() end)