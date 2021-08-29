--[[
 * ReaScript Name: MIDI File Track Name Fix
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: Track Name Fix.lua (dangguidan)
 * REAPER: 6.0 or newer recommended
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-22)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
local count_item = reaper.CountMediaItems(0)
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if count_sel_items > 0 then
    idx = 0
    while idx < count_sel_items do
        item = reaper.GetSelectedMediaItem(0, idx)
        idx = idx + 1
        take = reaper.GetTake(item, 0)
        reaper.MIDI_DisableSort(take)
    
        local retval, selected, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, 0, nil, nil, nil, 0, '')
        if type == 3 then
            track  = reaper.GetMediaItem_Track(item)
            reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', msg, true)
            reaper.MIDI_DeleteTextSysexEvt(take, 0)
        end

        i = 1
        idx2 = 0
        pcpos = {}
        repeat
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx2)
            if chanmsg == 192  then
                pcpos[i] = ppqpos
                i = i + 1
            end 
            idx2 = idx2 + 1
        until retval == false
    
        j = 1
        idx3 = 0
        repeat
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx3)
            if chanmsg == 176 then
                if msg2 == 0 or msg2 == 32 then
                    for j, v in ipairs(pcpos) do
                        if v - ppqpos <= 2 then 
                            reaper.MIDI_SetCC(take, idx3, nil, nil, pcpos[j], nil, nil, nil, nil, false)
                        end
                    end
                end  
            end 
            idx3 = idx3 + 1
        until retval == false
    
        reaper.MIDI_Sort(take)
    end
else
    idx = 0
    while idx < count_item do
        item = reaper.GetMediaItem(0, idx)
        idx = idx + 1
        take = reaper.GetTake(item, 0)
        reaper.MIDI_DisableSort(take)
    
        local retval, selected, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, 0, nil, nil, nil, 0, '')
        if type == 3 then
            track  = reaper.GetMediaItem_Track(item)
            reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', msg, true)
            reaper.MIDI_DeleteTextSysexEvt(take, 0)
        end

        i = 1
        idx2 = 0
        pcpos = {}
        repeat
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx2)
            if chanmsg == 192  then
                pcpos[i] = ppqpos
                i = i + 1
            end 
            idx2 = idx2 + 1
        until retval == false
    
        j = 1
        idx3 = 0
        repeat
            retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, idx3)
            if chanmsg == 176 then
                if msg2 == 0 or msg2 == 32 then
                    for j, v in ipairs(pcpos) do
                        if v - ppqpos <= 2 then
                            reaper.MIDI_SetCC(take, idx3, nil, nil, pcpos[j], nil, nil, nil, nil, false)
                        end
                    end
                end  
            end 
            idx3 = idx3 + 1
        until retval == false
    
        reaper.MIDI_Sort(take)
    end
end

reaper.Undo_EndBlock("MIDI File Track Name Fix", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()