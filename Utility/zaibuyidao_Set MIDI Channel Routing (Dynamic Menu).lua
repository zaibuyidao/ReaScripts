-- @description Set MIDI Channel Routing (Dynamic Menu)
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

if not reaper.APIExists("JS_Localize") then
    reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, "錯誤", 0)
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