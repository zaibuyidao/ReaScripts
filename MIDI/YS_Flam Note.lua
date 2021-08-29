--[[
 * ReaScript Name: Flam Note
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local retval, shuzhi = reaper.GetUserInputs('Flam Note', 2, '音符距离 tick,力度增减值,', '20,-10')
if retval==false then reaper.SN_FocusMIDIEditor() return end

tick_sub,chazhi_sub=string.match(shuzhi,"(-?%d+),(-?%d+)")
local tick = tonumber (tick_sub)
local chazhi = tonumber (chazhi_sub)

if tick < 0 then tick_sub = tick * (-1) else tick_sub = tick end 

if tick_sub >= 5 then

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)

reaper.MIDI_DisableSort(take)
idx=-1
repeat
 integer = reaper.MIDI_EnumSelNotes(take, idx)
 if integer ~= -1 then
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 if tick > 0 then
 reaper.MIDI_SetNote(take, integer, true, false, startppqpos, startppqpos+tick-1, NULL, NULL,NULL, false)
 end
 new_vel = vel+chazhi 
 if new_vel < 1 then new_vel = 1 end
 if new_vel >127 then new_vel = 127 end
 if tick < 0 then 
 reaper.MIDI_InsertNote(take, false, false, startppqpos+tick, startppqpos-1, chan, pitch, new_vel, false)
 else 
 reaper.MIDI_InsertNote(take, false, false, startppqpos+tick, endppqpos+tick, chan, pitch, new_vel, false)
 end
 idx=integer
 end
 until integer==-1
 reaper.MIDI_Sort(take)
 end -- while item end

end -- >=5
reaper.SN_FocusMIDIEditor()
