--[[
 * ReaScript Name: insert CC
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

retval, shuzhi = reaper.GetUserInputs('insert CC', 2, 'CC Num=,CC Val=', '11,127')
num_sub,val_sub=string.match(shuzhi,"(%d+),(%d+)")
num=tonumber (num_sub)
val=tonumber (val_sub)
tb={}
for i=0 ,notecnt,1 do
retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
if (sel==true)
then
tb[i]=startppqpos
chengong = reaper.MIDI_InsertCC(take, false,false, startppqpos, 176, 0, num, val)
end
end
reaper.SN_FocusMIDIEditor()
