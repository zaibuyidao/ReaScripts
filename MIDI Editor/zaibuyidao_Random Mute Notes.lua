--[[
 * ReaScript Name: Random Mute Notes
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-5-14)
  + Initial release
--]]

function Main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    reaper.MIDI_Sort(take)
    i = reaper.MIDI_EnumSelNotes(take, -1)
    if i ~= -1 then sel_note = true end
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
            bool = math.random(2)
            if bool == 1 then
                reaper.MIDI_SetNote(take, i, nil, true, nil, nil, nil, nil, nil, true)
            else
                reaper.MIDI_SetNote(take, i, nil, false, nil, nil, nil, nil, nil, true)
            end
        end
        i = reaper.MIDI_EnumSelNotes(take, i)
    end
    for i = 1, notecnt do
        _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
        if not sel_note then
            bool = math.random(2)
            if bool == 1 then
                reaper.MIDI_SetNote(take, i - 1, nil, true, nil, nil, nil, nil, nil, true)
            else
                reaper.MIDI_SetNote(take, i - 1, nil, false, nil, nil, nil, nil, nil, true)
            end
        end
    end
    reaper.MIDI_Sort(take)
end
local title = "Random Mute Notes"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(title, 0)
reaper.SN_FocusMIDIEditor()
