--[[
 * ReaScript Name: insert CC 按选中音符
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval, shuzhi = reaper.GetUserInputs('insert CC 按选中音符', 3, 'CC Num=,CC Val=,Tick(-+)', '128,128,0')
if retval==false then return end
num_sub,val_sub,tick_sub=string.match(shuzhi,"(%d+),(%d+),([+-]?%d+)")
num=tonumber (num_sub)
val=tonumber (val_sub)  tick=tonumber (tick_sub)

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)

retval,notecnt,ccevtcnt, extsyxevtcnt = reaper.MIDI_CountEvts(take)
tb={}
for i=0 ,notecnt,1 do
retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
if (sel==true)
then
tb[i]=startppqpos

if num >= 0 and num <= 127 then
if val >= 0 and val <= 127 then
reaper.MIDI_InsertCC(take, false,false, startppqpos+tick, 176, 0, num, val)
end
end
end
end

end -- while item end
local editor=reaper.MIDIEditor_GetActive()
if num >= 0 and num <= 119 then
ID = num + 40238
reaper.MIDIEditor_OnCommand(editor, ID)
end
reaper.SN_FocusMIDIEditor()
