--[[
 * ReaScript Name: Set Velocity
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or MIDI Takes. Run.
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
 * v1.0 (2019-12-15)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    velo = reaper.GetExtState("SetVelocity", "Velocity")
    if (velo == "") then velo = "100" end
    user_ok, velo = reaper.GetUserInputs("Set Velocity", 1, "Value", velo)
    reaper.SetExtState("SetVelocity", "Velocity", velo, false)
    if not user_ok or not tonumber(velo) then return end
    velo = tonumber(velo)
    if velo > 127 or velo < 1 then
        return reaper.MB("Please enter a value from 1 through 127", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end
    if window == "midi_editor" then
        if not inline_editor then
            if not user_ok or not tonumber(velo) then return reaper.SN_FocusMIDIEditor() end
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        else
            take = reaper.BR_GetMouseCursorContext_Take()
        end
        reaper.MIDI_DisableSort(take)
        _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        for i = 1, notecnt do
            _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
            if selected == true then
              reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, endppqpos, chan, pitch, velo, false)
            end
        end
        if not inline_editor then reaper.SN_FocusMIDIEditor() end
        reaper.MIDI_Sort(take)
    else
        if not user_ok or not tonumber(velo) then return end
        count_sel_items = reaper.CountSelectedMediaItems(0)
        if count_sel_items == 0 then return end
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
                for i = 1, notecnt do
                    _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                    reaper.MIDI_SetNote(take, i - 1, selected, muted, startppqpos, endppqpos, chan, pitch, velo, false)
                end
            end
            reaper.MIDI_Sort(take)
        end
    end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Set Velocity", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)