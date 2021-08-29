--[[
 * ReaScript Name: 相同音高音符缩短5tick
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

tempend,i,idx,temppitch=-1,1,-1,-1
integer = reaper.MIDI_EnumSelNotes(take,idx)
while (integer ~= -1) do
integer = reaper.MIDI_EnumSelNotes(take,idx)

retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
if startppqpos==tempend  and pitch==temppitch  then
 reaper.MIDI_SetNote(take, tempidx, NULL, NULL, NULL, startppqpos-5, NULL, NULL,NULL, false)
 end -- if end
 tempend=endppqpos temppitch=pitch tempidx=integer
 idx=integer
 integer = reaper.MIDI_EnumSelNotes(take,idx)
end -- while end
reaper.MIDI_Sort(take)


