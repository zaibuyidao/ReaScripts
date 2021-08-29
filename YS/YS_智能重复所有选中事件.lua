--[[
 * ReaScript Name: 智能重复所有选中事件
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

idx_first = reaper.MIDI_EnumSelEvts(take, -1)

if idx_first == -1 then return end

retval, selected, muted, ppqpos_first, msg = reaper.MIDI_GetEvt(take, idx_first, true, false, -1, '')
selidx = reaper.MIDI_EnumSelEvts(take, idx_first)
if selidx ~= -1 then 
idx = selidx
while  idx ~= -1 do 
retval, selected, muted, ppqpos_end, msg = reaper.MIDI_GetEvt(take, idx, false, false, -1, '')
selidx = idx
idx = reaper.MIDI_EnumSelEvts(take, selidx)
end
juli = ppqpos_end - ppqpos_first
else
juli = 0
end  -- if end 
Item = reaper.GetMediaItemTake_Item(take)
item_st = reaper.GetMediaItemInfo_Value(Item, 'D_POSITION')
QN = reaper.TimeMap2_timeToQN(0, item_st)
timebase1 = reaper.MIDI_GetPPQPosFromProjQN(take, QN)
timebase2 = reaper.MIDI_GetPPQPosFromProjQN(take, QN+1)
timebase = timebase2 - timebase1

shiliu = timebase / 4
ba = timebase / 2
si = timebase
er = timebase * 2

 if juli <= shiliu then
reaper.MIDIEditor_OnCommand(editor , 40440) -- move first 
reaper.MIDIEditor_OnCommand(editor , 40713) -- move
reaper.MIDIEditor_OnCommand(editor , 40010) -- copy
reaper.MIDIEditor_OnCommand(editor , 40011) --paste
end
if juli > shiliu and juli <= ba then
reaper.MIDIEditor_OnCommand(editor , 40440) -- move first 
reaper.MIDIEditor_OnCommand(editor , 40716) -- move
reaper.MIDIEditor_OnCommand(editor , 40010) -- copy
reaper.MIDIEditor_OnCommand(editor , 40011) --paste
end
if juli > ba and juli <= si then
reaper.MIDIEditor_OnCommand(editor , 40440) -- move first 
reaper.MIDIEditor_OnCommand(editor , 40719) -- move
reaper.MIDIEditor_OnCommand(editor , 40010) -- copy
reaper.MIDIEditor_OnCommand(editor , 40011) --paste
end
if juli > si and juli <= er then
reaper.MIDIEditor_OnCommand(editor , 40440) -- move first 
reaper.MIDIEditor_OnCommand(editor , 40722) -- move
reaper.MIDIEditor_OnCommand(editor , 40010) -- copy
reaper.MIDIEditor_OnCommand(editor , 40011) --paste
end
if juli > er and juli <= er*2 then
reaper.MIDIEditor_OnCommand(editor , 40440) -- move first 
reaper.MIDIEditor_OnCommand(editor , 40682) -- move
reaper.MIDIEditor_OnCommand(editor , 40010) -- copy
reaper.MIDIEditor_OnCommand(editor , 40011) --paste
end
if juli > er*2 then 
reaper.MIDIEditor_OnCommand(editor , 40882) -- ctrl + D
end

reaper.MIDI_Sort(take) 
