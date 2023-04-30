-- @description Add MIDI Hardware Output And Receives To Selected Tracks
-- @version 1.5.1
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

function main()
    count_sel_track = reaper.CountSelectedTracks(0)
    if count_sel_track == 0 then return end
    local output_device = reaper.GetExtState("AddMIDIHardwareOutput", "Device")
    if (output_device == "") then output_device = "0" end
    local ordinal = reaper.GetExtState("AddMIDIHardwareOutput", "Ordinal")
    if (ordinal == "") then ordinal = "1" end
    local maxval = reaper.GetExtState("AddMIDIHardwareOutput", "MaxVal")
    if (maxval == "") then maxval = "16" end
    local track_num = reaper.GetExtState("AddMIDIHardwareOutput", "Track")
    if (track_num == "") then track_num = "1" end
    local toggle = reaper.GetExtState("AddMIDIHardwareOutput", "Toggle")
    if (toggle == "") then toggle = "0" end

    if language == "简体中文" then
        title = "添加MIDI硬件输出和接收到选定轨道"
        captions_csv = "MIDI硬件输出,MIDI通道开始,MIDI通道结束,接收轨道编号,0=默认 1=通道 2=接收 3=移除"
    elseif language == "繁体中文" then
        title = "添加MIDI硬件輸出和接收到選定軌道"
        captions_csv = "MIDI硬件輸出,MIDI通道開始,MIDI通道結束,接收軌道編號,0=默認 1=通道 2=接收 3=移除"
    else
        title = "Add MIDI Hardware Output And Receives To Selected Tracks"
        captions_csv = "MIDI Hardware Output,Send To Min Channel,Send To Max Channel,Receive From Track,0=DEF 1=CH 2=RECV 3=RMV"
    end

    uok, uinput = reaper.GetUserInputs(title, 5, captions_csv, output_device ..','.. ordinal ..','.. maxval ..','.. track_num ..','.. toggle)
    output_device, ordinal, maxval, track_num, toggle = uinput:match("(.*),(.*),(.*),(.*),(.*)")
    if not uok or not tonumber(output_device) or not tonumber(ordinal) or not tonumber(maxval) or not tonumber(track_num) or not tonumber(toggle) then return end

    reaper.SetExtState("AddMIDIHardwareOutput", "Device", output_device, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Ordinal", ordinal, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "MaxVal", maxval, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Track", track_num, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Toggle", toggle, false)

    maxval = tonumber(maxval)
    ordinal = ordinal - 1
    reaper.Undo_BeginBlock()
    if toggle == "0" then
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel >= maxval then channel = maxval end
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
            commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
            reaper.Main_OnCommand(commandID_02, 0)
            commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
            reaper.Main_OnCommand(commandID_01, 0)
        end
    elseif toggle == "1" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel >= maxval then channel = maxval end
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
        end
        -- commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
        -- reaper.Main_OnCommand(commandID_01, 0)
    elseif toggle == "2" then
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
        end
        commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
        reaper.Main_OnCommand(commandID_02, 0)
        -- commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
        -- reaper.Main_OnCommand(commandID_01, 0)
    else
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            number = 0 | -1 << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
        end
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
        commandID_04 = reaper.NamedCommandLookup("_SWS_ENMPSEND") -- SWS: Enable master/parent send on selected track(s)
        reaper.Main_OnCommand(commandID_04, 0)
    end
    reaper.Undo_EndBlock(title, -)
end
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()