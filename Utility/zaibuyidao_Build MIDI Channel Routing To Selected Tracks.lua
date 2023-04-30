-- @description Build MIDI Channel Routing To Selected Tracks
-- @version 1.0.1
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

function getSystemLanguage()
    local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
    local os = reaper.GetOS()
    local lang
  
    if os == "Win32" or os == "Win64" then -- Windows
        if locale == 936 then -- Simplified Chinese
            lang = "简体中文"
        elseif locale == 950 then -- Traditional Chinese
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "OSX32" or os == "OSX64" then -- macOS
        local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
        if lang == "zh-CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh-TW" then -- 繁体中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "Linux" then -- Linux
        local handle = io.popen("echo $LANG")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
        if lang == "zh_CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh_TW" then -- 繁體中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    end

    return lang
end

local language = getSystemLanguage()

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track == 0 then return end

sel_track_name = {}
for i = 0, count_sel_track-1 do
    local select_track = reaper.GetSelectedTrack(0, i)
    local _, get_track_name = reaper.GetTrackName(select_track, "")
    sel_track_name[#sel_track_name+1] = get_track_name
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

for i = 0, count_sel_track-1 do
    local select_track = reaper.GetSelectedTrack(0, i)
    local select_track_num = reaper.GetMediaTrackInfo_Value(select_track,'IP_TRACKNUMBER')
    local isVSTi = reaper.TrackFX_GetInstrument(select_track) -- 判斷是否為VSTi
    if isVSTi == -1 then goto continue end

    local channel_total = reaper.GetExtState("BuildMIDIChannelRouting", "Total")
    if (channel_total == "") then channel_total = "16" end
    local channel_ordinal = reaper.GetExtState("BuildMIDIChannelRouting", "Ordinal")
    if (channel_ordinal == "") then channel_ordinal = "1" end
    
    if language == "简体中文" then
        title = "建立MIDI通道路由到选定轨道"
        utitle = "建立MIDI通道路由到 "
        captions_csv = "通道总数,通道顺序"
    elseif language == "繁体中文" then
        title = "建立MIDI通道路由到選定軌道"
        utitle = "建立MIDI通道路由到 "
        captions_csv = "通道總數,通道順序"
    else
        title = "Build MIDI Channel Routing To Selected Tracks"
        utitle = "Build MIDI Routing To "
        captions_csv = "Total number of channels,Channel ordinal"
    end

    local uok, uinput = reaper.GetUserInputs(utitle .. sel_track_name[i+1], 2, captions_csv, channel_total ..','.. channel_ordinal)

    channel_total, channel_ordinal = uinput:match("(.*),(.*)")
    if not uok or not tonumber(channel_total) or not tonumber(channel_ordinal) then return end
    channel_total, channel_ordinal = tonumber(channel_total), tonumber(channel_ordinal)

    reaper.SetExtState("BuildMIDIChannelRouting", "Total", channel_total, false)
    reaper.SetExtState("BuildMIDIChannelRouting", "Ordinal", channel_ordinal, false)

    for j = 1, channel_total do
        reaper.InsertTrackAtIndex((select_track_num-1)+j, false) -- 插入軌道
        track_to_send = reaper.GetTrack(0,(select_track_num-1)+j) -- 建立MIDI路由軌道
        name_ok, track_name = reaper.GetSetMediaTrackInfo_String(select_track, 'P_NAME', '', 0) -- 獲取軌道名稱
        if track_name ~= '' then track_name = track_name .. ' ' end
        
        local channel = (channel_ordinal-1)+j
        reaper.GetSetMediaTrackInfo_String(track_to_send, 'P_NAME', track_name ..'MIDI '.. channel, true) -- 設置軌道名稱
        reaper.SetMediaTrackInfo_Value(track_to_send, "B_MAINSEND", 0) -- 禁用主/父發送
        reaper.CreateTrackSend(track_to_send, select_track)

        reaper.SetTrackSendInfo_Value(track_to_send, 0, 0, 'I_SRCCHAN', -1)

        if channel < 1 or channel > 16 then channel = 0 end
        if channel == '0' then channel = 'All' end
        reaper.SetTrackSendInfo_Value(track_to_send, 0, 0, 'I_MIDIFLAGS', channel << 5)
    end

    ::continue::
end
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()