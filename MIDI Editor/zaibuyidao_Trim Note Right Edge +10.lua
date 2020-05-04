--[[
 * ReaScript Name: Trim Note Left Edge +10
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-4-29)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)
reaper.MIDI_DisableSort(take)
reaper.Undo_BeginBlock()
for i = 1, notecnt do
  retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
  if sel == true then
    reaper.MIDI_SetNote(take, i - 1, sel, nil, nil, endppqpos+10, nil, nil, nil, false)
  end
end
reaper.Undo_EndBlock("Trim Note Left Edge +10", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()