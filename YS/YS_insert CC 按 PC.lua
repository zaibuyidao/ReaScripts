--[[
 * ReaScript Name: insert CC 按 PC
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval, num = reaper.GetUserInputs('insert Bank to PC', 1, 'CC num = ', '10')
if retval==false then return end

num=tonumber (num) 

editor=reaper.MIDIEditor_GetActive()
take=reaper.MIDIEditor_GetTake(editor)
idx=-1
repeat
ccidx=reaper.MIDI_EnumSelCC(take,idx)
retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
if chanmsg==192 then 
reaper.MIDI_InsertCC(take, false, false, ppqpos, 176, chan, num, msg2)
end
idx=ccidx
ccidx=reaper.MIDI_EnumSelCC(take,idx)
until  ccidx==-1

if num >= 0 and num <= 119 then

ID = num + 40238

reaper.MIDIEditor_OnCommand(editor, ID)

end

reaper.SN_FocusMIDIEditor()
