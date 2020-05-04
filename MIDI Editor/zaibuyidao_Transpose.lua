--[[
 * ReaScript Name: Transpose
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or MIDI Takes. Run.
 * Version: 1.2
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
 * v1.0 (2020-4-9)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    amount = reaper.GetExtState("TransposeMIDI", "Transpose")
    if (amount == "") then amount = "0" end
    user_ok, amount = reaper.GetUserInputs("Transpose", 1, "Amount", amount)
    reaper.SetExtState("TransposeMIDI", "Transpose", amount, false)
    if window == "midi_editor" then
        if not inline_editor then
            if not user_ok or not tonumber(amount) then return reaper.SN_FocusMIDIEditor() end
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        else
            take = reaper.BR_GetMouseCursorContext_Take()
        end
        reaper.MIDI_Sort(take)
        i = reaper.MIDI_EnumSelNotes(take, -1)
        while i ~= -1 do
            local note = {}
            note[i] = {}
            note[i].ret,
            note[i].sel,
            note[i].muted,
            note[i].startppqpos,
            note[i].endppqpos,
            note[i].chan,
            note[i].pitch,
            note[i].vel = reaper.MIDI_GetNote(take, i)
            if note[i].sel then
                reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, note[i].pitch + amount, nil, true)
            end
            i = reaper.MIDI_EnumSelNotes(take, i)
        end
        reaper.MIDI_Sort(take)
        if not inline_editor then reaper.SN_FocusMIDIEditor() end
    else
        if not user_ok or not tonumber(amount) then return end
        count_sel_items = reaper.CountSelectedMediaItems(0)
        if count_sel_items == 0 then return end
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
                local note = {}
                for i = 1, notecnt do
                    note[i] = {}
                    note[i].ret, 
                    note[i].sel, 
                    note[i].muted,  
                    note[i].startppqpos,
                    note[i].endppqpos,
                    note[i].chan, 
                    note[i].pitch,
                    note[i].vel = reaper.MIDI_GetNote(take, i - 1)
                end
                for i = 1, notecnt do
                    reaper.MIDI_DeleteNote(take, 0)
                end
                for i = 1, notecnt do
                    reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch + amount, note[i].vel, false)
                end
            end
            reaper.MIDI_Sort(take)
        end
    end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Transpose", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)