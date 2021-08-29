--[[
 * ReaScript Name: insert CC65 滑音开关
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

retval,shuzhi= reaper.GetUserInputs('自动插入CC65滑音开关',2,'最小旋律间隔 TICK:240-1920,CC5 滑音时间','480,12') 
if retval==false then reaper.SN_FocusMIDIEditor() return end
tick,cc5=string.match(shuzhi,"(%d+),(%d+)")
tick=tonumber (tick)
cc5=tonumber (cc5)

if tick < 240 then tick=240 end
if tick > 1920 then tick=1920 end

reaper.MIDI_DisableSort(take)

retval1,selected, muted, startpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, 0)
if retval1==false then reaper.SN_FocusMIDIEditor() return end
reaper.MIDI_InsertCC(take, false, false, startpos+10 , 176, 0,5,cc5)

retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
idx=0
temp_end=-481
while idx<notecnt do
 retval,selected, muted, startpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
 if startpos-temp_end>tick then
 reaper.MIDI_InsertCC(take, false, false, startpos+60 , 176, 0,65,127)
 if temp_end > 65 then 
 reaper.MIDI_InsertCC(take, false, false, temp_end-60 , 176, 0,65,0) end
 end
 temp_st=startpos temp_end=endppqpos
 idx =idx + 1
 end
 reaper.MIDI_InsertCC(take, false, false, endppqpos-60 , 176, 0,65,0)
 
 reaper.MIDI_Sort(take)
 
 reaper.MIDIEditor_OnCommand(editor,40303)
 
 reaper.SN_FocusMIDIEditor()
 
