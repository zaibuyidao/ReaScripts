--[[
 * ReaScript Name: 自动颤音_Multi Track
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
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
reaper.MIDI_DisableSort(take)
retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

local idx=-1 
repeat 
 n_idx = reaper.MIDI_EnumSelNotes(take,idx)
 retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, n_idx)

local dur=endppqpos-startppqpos
 if (dur > 480) then
     reaper.MIDI_InsertCC(take, true,false, startppqpos+60, 176, 0, 1, 6)
     reaper.MIDI_SetCCShape(take,ccevtcnt , 5, -0.25, false)
     ccevtcnt=ccevtcnt+1
     reaper.MIDI_InsertCC(take, true,false, startppqpos+240, 176, 0, 1, 40)
     reaper.MIDI_SetCCShape(take,ccevtcnt , 5, 0.9, false)
     ccevtcnt=ccevtcnt+1
     reaper.MIDI_InsertCC(take, true,false, endppqpos-70, 176, 0, 1, 3)
     ccevtcnt=ccevtcnt+1
     reaper.MIDI_InsertCC(take, true,false, endppqpos-50, 176, 0, 1, 0)
     ccevtcnt=ccevtcnt+1
     end
idx=n_idx
until (n_idx==-1) 
reaper.MIDI_Sort(take)

end -- take is midi
end -- while item end

reaper.MIDIEditor_OnCommand(editor,40239)
