--[[
 * ReaScript Name: insert PC
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

idx = -1
jihao = ''
integer = reaper.MIDI_EnumSelNotes(take, idx)
integer_first = integer
idx = integer

repeat    
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 integer_end = integer 
 idx = integer
 integer = reaper.MIDI_EnumSelNotes(take, idx) 
 until (integer == -1)
 
retval,val= reaper.GetUserInputs('Edit Val',4,'输入新的库号 bank = ,输入新的音色号 PC = ,输入旧的库号 bank = ,输入旧的音色号 PC = ','3,128,3,128') 
bank_new1,PC_new1,bank_old1,PC_old1=string.match(val,"(%d+),(%d+),(%d+),(%d+)")
bank_new=tonumber (bank_new1)
PC_new=tonumber (PC_new1)
bank_old=tonumber (bank_old1)
PC_old=tonumber (PC_old1)
MSB_new = math.modf( bank_new / 128 ) 
LSB_new = bank_new % 128
MSB_old = math.modf( bank_old / 128 ) 
LSB_old = bank_old % 128
     
while  integer_first <= integer_end+1  do
retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer_first)
if selected ~= jihao and retval ~= false then 
  if selected then
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 176, chan, 0, MSB_new)
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 176, chan, 32, LSB_new)
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 192, chan, PC_new, 0)
else 
if PC_old < 128 then
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 176, chan, 0, MSB_old)
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 176, chan, 32, LSB_old)
reaper.MIDI_InsertCC(take, false, false, startppqpos-10, 192, chan, PC_old, 0)
end
end  -- if1 end
end  -- if2 end
jihao = selected
integer_first = integer_first + 1
end

reaper.MIDI_Sort(take)
reaper.MIDIEditor_OnCommand(editor , 40369)
reaper.SN_FocusMIDIEditor()



