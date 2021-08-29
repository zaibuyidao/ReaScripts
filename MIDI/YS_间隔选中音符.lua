--[[
 * ReaScript Name: 间隔选中音符
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

local retval, shuzhi = reaper.GetUserInputs('间隔选中音符', 1, '选中音符起始位置 0 ，1', '1')

val_sub=string.match(shuzhi,"%d+")
local qishi=tonumber (val_sub)
idxtb={}

reaper.MIDI_DisableSort(take)

idx , a ,i,ii= -1 , 0 ,1,1

integer = reaper.MIDI_EnumSelNotes(take, idx) 

while  integer ~= -1 do

 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 
 b = a % 2
 
 if  b==qishi then 
 idxtb[i]= integer
 i=i+1
 end -- if end
 
 a = a+1 
 idx = integer
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 
 end -- while end
 reaper.MIDI_SelectAll(take, false)
 while ii<i do
 reaper.MIDI_SetNote(take, idxtb[ii], true, false, NULL, NULL, NULL, NULL, NULL, false)
 ii=ii+1 
 end
 
 reaper.MIDI_Sort(take)

 reaper.SN_FocusMIDIEditor()
