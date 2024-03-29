-- @description Random Note End (Customize)
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

-- USER AREA
-- Settings that the user can customize.

num = 3

-- End of USER AREA

function main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
        flag = true
    end

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
        note_len = note[i].endppqpos - note[i].startppqpos
        if note_len > num then
            if note[i].sel then
                reaper.MIDI_SetNote(take, i, nil, nil, nil, (note[i].endppqpos-num-1)+math.random(num*2+1), nil, nil, nil, true)
            end
        end
        i = reaper.MIDI_EnumSelNotes(take, i)
    end
    for i = 1, notecnt do
        _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
        note_len = endppqpos - startppqpos
        if note_len > num then
            if not sel_note then
                reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, (endppqpos-num-1)+math.random(num*2+1), nil, nil, nil, true)
            end
        end
    end
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)
    reaper.MIDI_Sort(take)
    
    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note End", -1)