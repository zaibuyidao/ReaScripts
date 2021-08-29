--[[
 * ReaScript Name: slide Left 10 tick_Multi Track
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

--local take=reaper.MIDIEditor_GetTake(editor)

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then

idx=-1
    
reaper.MIDI_DisableSort(take)
integer = reaper.MIDI_EnumSelEvts(take, idx)

while integer ~= -1 do

integer = reaper.MIDI_EnumSelEvts(take, idx)

if integer~=-1 then

retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, integer, true, false, -1, '')

reaper.MIDI_SetEvt(take, integer, true, false,  ppqpos-10, '', false)

idx=integer

end -- if end 

end -- while end

reaper.MIDI_Sort(take)
end

end -- while item end


