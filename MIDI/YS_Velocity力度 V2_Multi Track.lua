--[[
 * ReaScript Name: Velocity力度 V2_Multi Track
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

retval, shuzhi = reaper.GetUserInputs('Velocity Tools V2_Multi Track', 3, '输入开始力度：,输入结束力度：,百分比：0__绝对值：1', '100,100,0')
if retval then
bigin_sub,jiewei_sub,moshi=string.match(shuzhi,"(%d+),(%d+),(%d+)")
tou=tonumber (bigin_sub)
wei=tonumber (jiewei_sub)
chazhi=wei-tou+ 0.1
--INPUT
left=math.huge
right = -1

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
reaper.MIDI_DisableSort(take)
 i=-1
repeat
 integer = reaper.MIDI_EnumSelNotes(take, i)
 if integer ~= -1 then
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 if startppqpos < left then left = startppqpos end
 if startppqpos > right then right = startppqpos end
 end
  i=integer
  integer = reaper.MIDI_EnumSelNotes(take, i)
until  (integer==-1)

reaper.MIDI_Sort(take)
juli = right - left
jiange = juli / chazhi
end

end -- while item end  get select time


contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
reaper.MIDI_DisableSort(take)
 i=-1
repeat
 integer = reaper.MIDI_EnumSelNotes(take, i)
 if integer ~= -1 then
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 if moshi == '0' then
 if jiange == 0 then vel_new = vel * tou / 100 
 vel_new2 , b = math.modf(vel_new) else 
 vel_new = vel * ((tou + ( (startppqpos-left) / jiange ) )/ 100)
 vel_new2 , b = math.modf(vel_new)  
 end
 end
 if moshi == '1' then
 if jiange == 0 then vel_new = tou 
 vel_new2 , b = math.modf(vel_new) else 
 vel_new = tou + ( (startppqpos-left) / jiange )
 vel_new2 , b = math.modf(vel_new)  
 end
 end
 if vel_new2 < 1 then vel_new2=1 end
 if vel_new2 > 127 then vel_new2=127 end

 reaper.MIDI_SetNote(take, integer, true, false, NULL, NULL, NULL, NULL,vel_new2, false)
 end
  i=integer
  integer = reaper.MIDI_EnumSelNotes(take, i)
until  (integer==-1)

reaper.MIDI_Sort(take)
end
end -- while item end
end

reaper.SN_FocusMIDIEditor()
