--[[
 * ReaScript Name: 建立MIDI通道路由到選定軌道
 * Version: 1.0
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

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function main()
    count_sel_track = reaper.CountSelectedTracks(0)
    if count_sel_track == 0 then return end

    sel_track_name = {}
    for i = 0, count_sel_track-1 do
        local select_track = reaper.GetSelectedTrack(0, i)
        local _, get_track_name = reaper.GetTrackName(select_track, "")
        sel_track_name[#sel_track_name+1] = get_track_name
    end

    for i = 0, count_sel_track-1 do
        local select_track = reaper.GetSelectedTrack(0, i)
        local select_track_num = reaper.GetMediaTrackInfo_Value(select_track,'IP_TRACKNUMBER')
        local isVSTi = reaper.TrackFX_GetInstrument(select_track) -- 判斷是否為VSTi
        if isVSTi == -1 then goto continue end

        local channel_total = reaper.GetExtState("BuildMIDIRoutingChannel", "Total")
        if (channel_total == "") then channel_total = "16" end
        local channel_ordinal = reaper.GetExtState("BuildMIDIRoutingChannel", "Ordinal")
        if (channel_ordinal == "") then channel_ordinal = "1" end
        
        user_ok, user_input_csv = reaper.GetUserInputs("建立MIDI通道路由到 " .. sel_track_name[i+1], 2, "通道總數,通道順序", channel_total ..','.. channel_ordinal)
        channel_total, channel_ordinal = user_input_csv:match("(.*),(.*)")
        if not user_ok or not tonumber(channel_total) or not tonumber(channel_ordinal) then return end
        channel_total, channel_ordinal = tonumber(channel_total), tonumber(channel_ordinal)

        reaper.SetExtState("BuildMIDIRoutingChannel", "Total", channel_total, false)
        reaper.SetExtState("BuildMIDIRoutingChannel", "Ordinal", channel_ordinal, false)

        reaper.Undo_BeginBlock()
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
        reaper.Undo_EndBlock("建立MIDI通道路由到選定軌道", 0)
        ::continue::
    end
end
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()