--[[
 * ReaScript Name: insert CC 按选中音符_尾部
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

retval,notecnt,ccevtcnt, extsyxevtcnt = reaper.MIDI_CountEvts(take)

retval, shuzhi = reaper.GetUserInputs('insert CC 按选中音符', 2, 'CC Num=,CC Val=', '128,128')
num_sub,val_sub=string.match(shuzhi,"(%d+),(%d+)")
num=tonumber (num_sub)
val=tonumber (val_sub)
tb={}
for i=0 ,notecnt,1 do
retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
if (sel==true)
then
tb[i]=startppqpos

if num >= 0 and num <= 127 then
if val >= 0 and val <= 127 then
chengong = reaper.MIDI_InsertCC(take, false,false, endppqpos-10, 176, 0, num, val)
end
end
end
end
if num >= 0 and num <= 119 then

ID = num + 40238

reaper.MIDIEditor_OnCommand(editor, ID)

end
reaper.SN_FocusMIDIEditor()
