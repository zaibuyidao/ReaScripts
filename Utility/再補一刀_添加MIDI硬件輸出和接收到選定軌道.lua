--[[
 * ReaScript Name: 添加MIDI硬件輸出和接收到選定軌道
 * Version: 1.5
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-04-15)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
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
    local user_ok, user_input_CSV = reaper.GetUserInputs("添加MIDI硬件輸出和接收到選定軌道", 5, "MIDI硬件輸出,MIDI通道開始,MIDI通道結束,接收軌道編號,0=默認 1=通道 2=接收 3=移除", output_device ..','.. ordinal ..','.. maxval ..','.. track_num ..','.. toggle)
    output_device, ordinal, maxval, track_num, toggle = user_input_CSV:match("(.*),(.*),(.*),(.*),(.*)")
    if not user_ok or not tonumber(output_device) or not tonumber(ordinal) or not tonumber(maxval) or not tonumber(track_num) or not tonumber(toggle) then return end
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
    reaper.Undo_EndBlock("添加MIDI硬件輸出和接收到選定軌道", 0)
end
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()