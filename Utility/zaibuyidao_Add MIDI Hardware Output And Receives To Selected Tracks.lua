--[[
 * ReaScript Name: Add MIDI Hardware Output And Receives To Selected Tracks
 * Version: 1.1
 * Author: zaibuyidao
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
    if (output_device == "") then output_device = "1" end
    local ordinal = reaper.GetExtState("AddMIDIHardwareOutput", "Ordinal")
    if (ordinal == "") then ordinal = "1" end
    local track_num = reaper.GetExtState("AddMIDIHardwareOutput", "Track")
    if (track_num == "") then track_num = "1" end
    local toggle = reaper.GetExtState("AddMIDIHardwareOutput", "Toggle")
    if (toggle == "") then toggle = "0" end
    user_ok, input_cav = reaper.GetUserInputs("选定轨道添加MIDI硬件输出和接收到选定的轨道", 4, "MIDI硬件输出,MIDI通道序数,接收轨道编号,0=默认1=通道2=接收3=移除", output_device ..','.. ordinal ..','.. track_num ..','.. toggle)
    output_device, ordinal, track_num, toggle = input_cav:match("(.*),(.*),(.*),(.*)")
    if not user_ok or not tonumber(output_device) or not tonumber(ordinal) or not tonumber(track_num) or not tonumber(toggle) then return end
    reaper.SetExtState("AddMIDIHardwareOutput", "Device", output_device, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Ordinal", ordinal, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Track", track_num, false)
    reaper.SetExtState("AddMIDIHardwareOutput", "Toggle", toggle, false)
    ordinal = ordinal - 1
    reaper.Undo_BeginBlock()
    if toggle == "0" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
            commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
            reaper.Main_OnCommand(commandID_01, 0)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
            commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
            reaper.Main_OnCommand(commandID_02, 0)
        end
    elseif toggle == "1" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            channel = i + ordinal
            if channel < 1 or channel > 16 then channel = 0 end
            number = channel | output_device << 5
            reaper.SetMediaTrackInfo_Value(select_track,"I_MIDIHWOUT", number)
        end
    elseif toggle == "2" then
        for i = 1, count_sel_track do
            select_track = reaper.GetSelectedTrack(0, i - 1)
            commandID_01 = reaper.NamedCommandLookup("_SWS_DISMPSEND") -- SWS: Disable master/parent send on selected track(s)
            reaper.Main_OnCommand(commandID_01, 0)
            track_to_receive = reaper.GetTrack(0, track_num - 1)
            reaper.CreateTrackSend(track_to_receive, select_track)
            commandID_02 = reaper.NamedCommandLookup("_SWS_MUTERECVS") -- SWS: Mute all receives for selected track(s)
            reaper.Main_OnCommand(commandID_02, 0)
        end
    else
        commandID_03 = reaper.NamedCommandLookup("_S&M_SENDS5") -- SWS/S&M: Remove receives from selected tracks
        reaper.Main_OnCommand(commandID_03, 0)
    end
    reaper.Undo_EndBlock("Add MIDI Hardware Output And Receives To Selected Tracks", 0)
end
main()