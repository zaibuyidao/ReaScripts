--[[
 * ReaScript Name: Trim Note Left Edge
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
 * v1.0 (2020-3-4)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
local retval, j = reaper.GetUserInputs("Trim Note Left Edge", 1, "Amount", "-1")
if not retval then return reaper.SN_FocusMIDIEditor() end
reaper.MIDI_DisableSort(take)
reaper.Undo_BeginBlock()
for i = 1, notes do
  retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i-1)
  if sel == true then
    reaper.MIDI_SetNote(take, i-1, sel, nil, startppqpos-j, nil, nil, nil, nil, false)
  end
end
reaper.Undo_EndBlock("Trim Note Left Edge", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()