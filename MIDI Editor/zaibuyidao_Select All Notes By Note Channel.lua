--[[
 * ReaScript Name: Select All Notes By Note Channel
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
 * v1.0 (2020-6-5)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)
reaper.MIDI_DisableSort(take)
local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end
reaper.Undo_BeginBlock()
if #index == 1 then
  _, _, _, _, _, chan_num, _, _ = reaper.MIDI_GetNote(take, index[1])
else
  return reaper.SN_FocusMIDIEditor()
end
for i = 1, notecnt do
  retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
  if chan == chan_num then
    reaper.MIDI_SetNote(take, i - 1, true, nil, nil, nil, nil, nil, nil, false)
  end
end
reaper.Undo_EndBlock("Select All Notes By Note Channel", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
