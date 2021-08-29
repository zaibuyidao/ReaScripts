--[[
 * ReaScript Name: 扫弦Tick重建
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

retval,shuzhi= reaper.GetUserInputs('扫弦 Tick 重建',2,'输入新的 Tick 间隔,输入原 Tick 间隔最大值','2,10') 
new_sub,old_sub=string.match(shuzhi,"(%d+),(%d+)")
new=tonumber (new_sub)
old=tonumber (old_sub)

if retval then
 
reaper.MIDI_DisableSort(take)

tempst,i,idx=-1,1,-1
integer = reaper.MIDI_EnumSelNotes(take,idx)

while (integer ~= -1) do

integer = reaper.MIDI_EnumSelNotes(take,idx)

retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
juli = startppqpos - tempst
if juli <= old and juli > 0  then
  if endppqpos < first+(i*new) then endppqpos = first+(i*new)+1 end
 reaper.MIDI_SetNote(take, integer, true, false, first+(i*new), endppqpos, NULL, NULL,NULL, false)
 i = i+1
 else first = startppqpos  i=1
 end -- if end
 tempst=startppqpos
 
 idx=integer
end -- while end
reaper.MIDI_Sort(take)

end

reaper.SN_FocusMIDIEditor()
