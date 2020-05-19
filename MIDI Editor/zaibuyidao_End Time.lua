--[[
 * ReaScript Name: End Time
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-4-24)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
            take = reaper.GetTake(item, 0)
            cur_pos = reaper.GetCursorPositionEx(0)
            dur = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
            _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
            for i = 1, notecnt do
                _, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                if sel == true then
                  reaper.MIDI_SetNote(take, i - 1, sel, muted, startppqpos, dur, chan, pitch, vel, true)
                end
            end
        end
    else
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        if take == nil then return end
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40791)
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)
    end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("End Time", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)