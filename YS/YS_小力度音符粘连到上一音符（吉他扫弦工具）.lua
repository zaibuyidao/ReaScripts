--[[
 * ReaScript Name: 小力度音符粘连到上一音符（吉他扫弦工具）
 * Version: 1.0
 * Author: YS
 * provides: [midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local editor=reaper.MIDIEditor_GetActive()

local take=reaper.MIDIEditor_GetTake(editor)
retval,shuzhi= reaper.GetUserInputs('小力度音符粘连到上一音符',1,'输入力度临界值','90') 
if retval == false then return reaper.SN_FocusMIDIEditor() end
shuzhi=tonumber(shuzhi)
 
reaper.MIDI_DisableSort(take)

idx=-1
note={}
integer = reaper.MIDI_EnumSelNotes(take,-1)
retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
note['st']=endppqpos note['pitch']=pitch note['idx']=integer
idx=integer

while (integer ~= -1) do
integer = reaper.MIDI_EnumSelNotes(take,idx)
retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
if  vel<shuzhi and pitch==note['pitch'] then 
reaper.MIDI_DeleteNote(take, integer)
reaper.MIDI_SetNote(take, note['idx'], true, false, NULL, endppqpos, NULL, NULL, NULL, false)
else
note['st']=endppqpos note['pitch']=pitch note['idx']=integer
idx=integer
integer = reaper.MIDI_EnumSelNotes(take,idx)
end
end
reaper.MIDI_Sort(take)

reaper.SN_FocusMIDIEditor()

