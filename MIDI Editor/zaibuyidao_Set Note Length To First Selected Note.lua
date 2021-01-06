--[[
 * ReaScript Name: Set Note Length To First Selected Note
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
 * v1.0 (2020-5-19)
  + Initial release
--]]

function Main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    local cnt, index = 0, {}
    local val = reaper.MIDI_EnumSelNotes(take, -1)
    if val ~= -1 then sel_note = true end
    while val ~= - 1 do
        cnt = cnt + 1
        index[cnt] = val
        val = reaper.MIDI_EnumSelNotes(take, val)
    end
    if #index > 1 then
        local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
        local notelen = endpos-startpos
        reaper.MIDI_DisableSort(take)
        for i = 1, #index do
            local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, index[i])
            reaper.MIDI_SetNote(take, index[i], nil, nil, startppqpos, startppqpos+notelen, nil, nil, nil, false)
        end
        reaper.UpdateArrange()
        reaper.MIDI_Sort(take)
    elseif #index == 1 then
        local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, index[1])
        local notelen = endpos-startpos
        reaper.MIDI_DisableSort(take)
        for i = 1, notecnt do
            local _, _, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
            reaper.MIDI_SetNote(take, i - 1, false, nil, startppqpos, startppqpos+notelen, nil, nil, nil, false)
        end
        reaper.UpdateArrange()
        reaper.MIDI_Sort(take)
    end
end
script_title = "Set Note Length To First Selected Note"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
