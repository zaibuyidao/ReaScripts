--[[
 * ReaScript Name: sel Note insert CC 64(sustain)
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local editor=reaper.MIDIEditor_GetActive()

local take=reaper.MIDIEditor_GetTake(editor)

reaper.MIDI_DisableSort(take)

retval,notecnt,ccevtcnt, extsyxevtcnt = reaper.MIDI_CountEvts(take)

tb={}
for i=0 ,notecnt,1 do
retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
if (sel==true)
then
tb[i]=startppqpos

reaper.MIDI_InsertCC(take, false,false, startppqpos-10, 176, 0, 64, 0)
reaper.MIDI_InsertCC(take, false,false, startppqpos+110, 176, 0, 64, 127)
end
end

reaper.MIDI_Sort(take)

ID = 64 + 40238

reaper.MIDIEditor_OnCommand(editor, ID)


reaper.SN_FocusMIDIEditor()
