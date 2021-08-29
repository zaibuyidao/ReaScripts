--[[
 * ReaScript Name: 音符对位
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

idx,i,ii=-1,2,2
tb1={}
tb2={}
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 tb1[1] = pitch
 tempst =  startppqpos
 idx = integer
repeat
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 juli = startppqpos - tempst 
 if juli < 0 then juli = juli * -1 end
 if juli < 13 then
 tb1[i] = pitch
 i=i+1
 end
 tempst =  startppqpos
 idx = integer
 until juli > 12
 tb2[1] = pitch
 
 idx_back=idx

repeat
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 tb2[ii] = pitch
 ii = ii+1
 idx = integer
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 until integer == -1
---------------------------------------------
table.sort (tb1)
table.sort (tb2)

ii=1
while ii < #tb2 do
 if tb2[ii+1] == tb2[ii] then table.remove(tb2,ii+1) else ii = ii+1 end
 end
---------------------------------------------

if #tb2 <= #tb1 then
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx_back)
 ii = 1 
 while ii <= #tb2 do
 if pitch == tb2[ii] then 
 reaper.MIDI_SetNote(take, idx_back, true, false, startppqpos, endppqpos, chan, tb1[ii], vel, true)
 end -- if end
 ii=ii+1
 end --while end  
repeat
 integer = reaper.MIDI_EnumSelNotes(take, idx_back) 
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
 ii = 1 
 while ii <= #tb2 do
 if pitch == tb2[ii] then 
 reaper.MIDI_SetNote(take, integer, true, false, startppqpos, endppqpos, chan, tb1[ii], vel, true)
 end -- if end
 ii=ii+1
 end --while end  
 idx_back = integer
 integer = reaper.MIDI_EnumSelNotes(take, idx_back) 
 until integer == -1
 
 reaper.MIDI_Sort(take)
 
 else  
 reaper.ShowMessageBox('目标音符数量大于参考音符数量！无法对位！', '出错啦!',0) 
 end
 
 reaper.SN_FocusMIDIEditor()
