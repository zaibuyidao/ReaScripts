--[[
 * ReaScript Name: Split Note By Tick_Multi Track
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

retval,tick= reaper.GetUserInputs('Split notes by Tick',1,'Split Tick','0') 
tick_sub=tonumber(tick)

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then

reaper.MIDI_DisableSort(take)

local idx = -1


if tick_sub > 0  then

repeat

integer = reaper.MIDI_EnumSelNotes(take, idx)

retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)

local dur= endppqpos - startppqpos

if dur > tick_sub then
  
  reaper.MIDI_SetNote(take, integer, true, false, startppqpos, startppqpos+tick_sub-1, null, null, null, false)
  
  i=1
  notestart = startppqpos + tick_sub * i
  while notestart < endppqpos do
 durend = startppqpos + tick_sub * (i+1)
  if durend > endppqpos then durend = endppqpos end -- fangzhi yichu
  reaper.MIDI_InsertNote(take, false, false, notestart, durend-1, chan, pitch, vel, false)
  i=i+1
  notestart = startppqpos + tick_sub * i
   
  end --while end
end

idx = integer

until  integer == -1

end

reaper.MIDI_Sort(take)
end
end -- while item end

reaper.SN_FocusMIDIEditor()


  
  
