--[[
 * ReaScript Name: Velocity to CC 力度转CC
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

retval,notecnt,ccevtcnt, extsyxevtcnt = reaper.MIDI_CountEvts(take)

retval, shuzhi = reaper.GetUserInputs('insert CC 按选中音符力度', 2, 'CC Num=,前后 tick', '3,-2')
if retval==false then return end
num_sub,tick_sub=string.match(shuzhi,"(%d+),([+-]?%d+)")
num=tonumber (num_sub)  tick=tonumber (tick_sub)

tb={}
for i=0 ,notecnt,1 do
retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
if (sel==true)
then
tb[i]=startppqpos

if num >= 0 and num <= 127 then

 reaper.MIDI_InsertCC(take, true,false, startppqpos+tick, 176, 0, num, vel)
end
end
end

if num >= 0 and num <= 119 then

ID = num + 40238
reaper.MIDIEditor_OnCommand(editor, ID)
end
reaper.MIDI_Sort(take)
---insert CC


reaper.MIDI_DisableSort(take)

 ccidx=-1
 tempcc=256
repeat
     integer = reaper.MIDI_EnumSelCC(take, ccidx)
     retval,selected,muted,ppqpos, chanmsg, chan, num_cc, val = reaper.MIDI_GetCC(take, integer)
     if  num_cc == num then
     adj = val - tempcc
     if adj == 0 then
 reaper.MIDI_DeleteCC(take, integer)
  else
 ccidx=integer
 tempcc=val
 end
 end
 
until integer==-1
--delete CC 
reaper.MIDI_Sort(take)
reaper.SN_FocusMIDIEditor() 
