--[[
 * ReaScript Name: MIDI Chan From Track Send
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: midi chan from track send.lua (dangguidan)
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-12)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
function main()
    count_items = reaper.CountMediaItems(0)
    if count_items == 0 then return end
    for i = 1, count_items do
        item = reaper.GetMediaItem(0, count_items - i)
        take = reaper.GetTake(item, 0)
        track = reaper.GetMediaItem_Track(item)
        hwout = reaper.GetMediaTrackInfo_Value(track, 'I_MIDIHWOUT')
        chan = math.fmod(hwout, 32) - 1
        reaper.MIDI_DisableSort(take)
        _, notecnt, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
        for i = 1, notecnt do
            reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, chan, nil, nil, false)
        end
        for i = 1, ccevtcnt do
            reaper.MIDI_SetCC(take, i - 1, nil, nil, nil, nil, chan, nil, nil, false)
        end
        reaper.MIDI_Sort(take)
    end
    reaper.MB("All MIDI channels have been mapped to track send.","Complete!",0)
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("MIDI Chan From Track Send", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)