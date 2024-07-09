-- @description Random Note Mute
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Random Note Script Series, filter "zaibuyidao random note" in ReaPack or Actions to access all scripts.

function main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    
    local _, notecnt = reaper.MIDI_CountEvts(take)
    local has_selected_notes = reaper.MIDI_EnumSelNotes(take, -1) ~= -1

    reaper.MIDI_DisableSort(take)
    
    if has_selected_notes then
        local i = reaper.MIDI_EnumSelNotes(take, -1)
        while i ~= -1 do
            local _, sel = reaper.MIDI_GetNote(take, i)
            if sel then
                local mute_state = math.random(2) == 1
                reaper.MIDI_SetNote(take, i, nil, mute_state, nil, nil, nil, nil, nil, true)
            end
            i = reaper.MIDI_EnumSelNotes(take, i)
        end
    else
        -- 如果没有选中的音符，则处理所有音符
        for i = 0, notecnt - 1 do
            local mute_state = math.random(2) == 1
            reaper.MIDI_SetNote(take, i, nil, mute_state, nil, nil, nil, nil, nil, true)
        end
    end
    
    reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Mute", -1)