--[[
 * ReaScript Name: CC Saw
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

local retval, shuzhi = reaper.GetUserInputs('CC Saw 锯齿', 2, '循环间隔,差值', '6,6')

jiange_sub,val_sub=string.match(shuzhi,"(%d+),(%d+)")
local jiange=tonumber (jiange_sub)
local chazhi=tonumber (val_sub)
if jiange < 3 then jiange = 3 end

tb={}
i,ii=1,0
repeat
tb[i]=ii
i=i+1
ii=ii+1
until i > jiange
ii=i
i=i-3
repeat
tb[ii]=i
i=i-1
ii=ii+1
until i == 0


reaper.MIDI_DisableSort(take)

idx , a = -1 , 1

while  integer ~= -1 do

 integer = reaper.MIDI_EnumSelCC(take, idx)
 
 retval, selected,muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, integer)
  if chanmsg == 176 then
 
 new_cc = msg3 - (tb[a]*chazhi)
 
 if new_cc < 0  then new_cc = 0 end
 reaper.MIDI_SetCC(take, integer, true, false, NULL, NULL, NULL, NULL, new_cc, false)
 
 end
 
 a = a + 1
 
 if a == ii then a = 1 end
 
 idx = integer
 integer = reaper.MIDI_EnumSelCC(take, idx)
 
 end -- while end
 
 reaper.MIDI_Sort(take)

reaper.SN_FocusMIDIEditor()
