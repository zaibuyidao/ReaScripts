--[[
 * ReaScript Name: Random Velocity
 * Version: 1.6
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_inlineeditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    local diff = 127
    if window == "midi_editor" then
        if not inline_editor then
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        else
            take = reaper.BR_GetMouseCursorContext_Take()
        end
        reaper.MIDI_DisableSort(take)
        _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        for i = 1, notecnt do
            _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
            vel = tonumber(math.random(diff))
            if selected == true then
                reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, endppqpos, chan, pitch, vel, false)
            end
        end
        if not inline_editor then reaper.SN_FocusMIDIEditor() end
        reaper.MIDI_Sort(take)
    else
        count_sel_items = reaper.CountSelectedMediaItems(0)
        if count_sel_items == 0 then return end
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
                for i = 1, notecnt do
                    _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                    vel = tonumber(math.random(diff))
                    reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, endppqpos, chan, pitch, vel, false)
                end
            end
            reaper.MIDI_Sort(take)
        end
    end
end
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Velocity", 0)
reaper.UpdateArrange()