--[[
 * ReaScript Name: insert CC 按选择范围_Multi Track
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval,shuzhi= reaper.GetUserInputs('insert CC 按选择范围(多轨)',3,'输入CC类型 CC num =,输入CC起始数值 CC from =,输入CC结束数值 CC thru =','11,127,0') 
if retval==false then reaper.SN_FocusMIDIEditor() return end
num_sub,val1_sub,val2_sub=string.match(shuzhi,"(%d+),(%d+),(%d+)")
num=tonumber (num_sub)
val1=tonumber (val1_sub)
val2=tonumber (val2_sub)

if num >= 0 and num <= 127 then
if val1 >= 0 and val1 <= 127 then
if val2 >= 0 and val2 <= 127 then

local editor=reaper.MIDIEditor_GetActive()

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then

reaper.MIDI_DisableSort(take)

From,Thru = reaper.GetSet_LoopTimeRange(false, true, 0, 0, true)
if From==0 and Thru==0 then return end

local From_tick=reaper.MIDI_GetPPQPosFromProjTime(take, From)
local Thru_tick=reaper.MIDI_GetPPQPosFromProjTime(take, Thru)


reaper.MIDI_InsertCC(take, false, false, From_tick , 176, 0,num,val1)
retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
reaper.MIDI_SetCCShape(take, ccevtcnt-1, 1, 1, false)
reaper.MIDI_InsertCC(take, false, false, Thru_tick , 176, 0,num,val2)
reaper.MIDI_Sort(take)
end

end -- while item end

if num >= 0 and num <= 119 then

ID = num + 40238

reaper.MIDIEditor_OnCommand(editor, ID)

end
end 
end
end

reaper.SN_FocusMIDIEditor()

