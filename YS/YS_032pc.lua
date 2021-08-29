--[[
 * ReaScript Name: 032pc
 * Version: 1.0
 * Author: YS
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * provides: [midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local editor=reaper.MIDIEditor_GetActive()
local take=reaper.MIDIEditor_GetTake(editor)
reaper.MIDI_DisableSort(take)
 i=1
 ccidx=0
 PC = {}
repeat
    retval,selected,muted,ppqpos, chanmsg, chan, num, val = reaper.MIDI_GetCC(take, ccidx)
  if chanmsg==192  then
   PC[i]=ppqpos
   i = i+1
   end 
 ccidx = ccidx + 1
until retval == false
-- get pc 

 i=1
 ccidx=0
repeat
    retval,selected,muted,ppqpos, chanmsg, chan, num, val = reaper.MIDI_GetCC(take, ccidx)
  if chanmsg==176 then
  if num == 0 or num==32 then
   for i, v in ipairs(PC) do
       if (v - ppqpos ) <= 2 then 
       reaper.MIDI_SetCC(take, ccidx, NULL, NULL, PC[i], NULL, NULL, NULL, NULL, false)
       end
       end
   end  
   end 
 ccidx = ccidx + 1
until retval == false

reaper.MIDI_Sort(take)
