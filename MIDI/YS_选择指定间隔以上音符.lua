--[[
 * ReaScript Name: 选择指定间隔以上音符
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

local retval, shuzhi = reaper.GetUserInputs('选择指定间隔以上音符', 1, '选中音符指定间隔tick', '120')

jiange=string.match(shuzhi,"%d+")
local jiange=tonumber (jiange)

reaper.MIDI_DisableSort(take)

idx , tempst= -1 , -jiange

integer = reaper.MIDI_EnumSelNotes(take, idx) 

while  integer ~= -1 do

 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 
retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)

if startppqpos-tempst<jiange then

reaper.MIDI_SetNote(take, idx, false, NULL, NULL, NULL, NULL, NULL, NULL, false) 

end
tempst=startppqpos

 idx = integer
 
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 
 end -- while end
 
 reaper.MIDI_Sort(take)

 reaper.SN_FocusMIDIEditor()
