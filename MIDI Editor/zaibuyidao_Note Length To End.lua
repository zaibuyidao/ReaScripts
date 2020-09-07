--[[
 * ReaScript Name: Note Length To End
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Extensions: SWS
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-5)
  + Initial release
--]]

function Msg(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

function table_max(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

function Main()
    reaper.Undo_BeginBlock()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if take == nil then return end

    local curpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
    local fng_take = reaper.FNG_AllocMidiTake(take)

    note_cnt, note_idx = 0, {}
    note_val = reaper.MIDI_EnumSelNotes(take, -1)
    while note_val ~= -1 do
        note_cnt = note_cnt + 1
        note_idx[note_cnt] = note_val
        note_val = reaper.MIDI_EnumSelNotes(take, note_val)
    end

    end_ppq = {}
    for i = 1, #note_idx do
        local cur_note = reaper.FNG_GetMidiNote(fng_take, note_idx[i])
        local start_ppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION")
        local length = reaper.FNG_GetMidiNoteIntProperty(cur_note, "LENGTH")
        end_ppq[i] = start_ppq+length
    end
    max_endppq = table_max(end_ppq)

    for i = 1, #note_idx do
        local cur_note = reaper.FNG_GetMidiNote(fng_take, note_idx[i])
        local start_ppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION")
        local endpos = max_endppq - start_ppq
        reaper.FNG_SetMidiNoteIntProperty(cur_note, "LENGTH", endpos)
    end

    reaper.FNG_FreeMidiTake(fng_take)
    reaper.Undo_EndBlock("Note Length To End", -1)
    reaper.UpdateArrange()
end

Main()