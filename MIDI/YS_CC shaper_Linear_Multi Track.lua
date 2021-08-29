--[[
 * ReaScript Name: CC shaper_Linear_Multi Track
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

editor=reaper.MIDIEditor_GetActive()
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
 reaper.MIDI_DisableSort(take)
idx=-1 
repeat 
  ccidx = reaper.MIDI_EnumSelCC(take,idx)  
  if ccidx~=-1 then
 reaper.MIDI_SetCCShape(take, ccidx, 1, 0, false)
  end
idx=ccidx
ccidx = reaper.MIDI_EnumSelCC(take,idx) 
until (ccidx==-1) 

reaper.MIDI_Sort(take)
end
end -- while item end


