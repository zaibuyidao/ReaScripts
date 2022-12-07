-- @description Random Note Position By Grid (Within Time Selection)
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

-- USER AREA
-- Settings that the user can customize.

midi_grid = 1 -- 1 is the default MIDI grid. Random intervals are based on the MIDI grid, where you can set multiples of the grid.

-- End of USER AREA

function main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
    local grid_qn = reaper.MIDI_GetGrid(take)
    local grid = math.floor(midi_tick*grid_qn)*midi_grid
    local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
    local loop_start = math.floor(0.5+reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
    local loop_end = math.floor(0.5+reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
    local loop_len = math.floor(loop_end-loop_start)
    local times = math.floor(loop_len/grid) -- Get all the intervals in the loop length
    local new_loop_start = loop_start-loop_start%grid -- Get the start grid position
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    reaper.MIDI_DisableSort(take)
    sel = reaper.MIDI_EnumSelNotes(take, -1)
    if sel ~= -1 then sel_note = true end
    if loop_len == 0  then return reaper.SN_FocusMIDIEditor() end
    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
        flag = true
    end
    for i = 1, notecnt do
        _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
        notelen = endppqpos - startppqpos
        if selected then
            local rand_grid = math.random(times)*grid
            local rand_pos = new_loop_start+rand_grid-grid
            reaper.MIDI_SetNote(take, i - 1, nil, nil, rand_pos, rand_pos+notelen, nil, nil, nil, false)
        end
    end
    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Position By Grid", -1)
reaper.UpdateArrange()