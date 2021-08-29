--[[
 * ReaScript Name: 音色信息批量修改
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

ccidx=-1
sel_idx=reaper.MIDI_EnumSelCC(take, ccidx) 
if sel_idx~=-1 then
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, sel_idx)
if chanmsg==176 and msg2==0 then yinse=msg3*128 end
sel_idx=reaper.MIDI_EnumSelCC(take, sel_idx)
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, sel_idx)
if chanmsg==176 and msg2==32 then yinse=yinse+msg3 bank=yinse end
sel_idx=reaper.MIDI_EnumSelCC(take, sel_idx)
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, sel_idx)
if chanmsg==192  then yinse=yinse..','..msg2 program=msg2 end

retval,shuzhi= reaper.GetUserInputs('音色信息批量修改',2,'新的库号:,新的音色号:',bank..','..program) 
if retval == false then return reaper.SN_FocusMIDIEditor() end
kuhao,yinsehao=string.match(shuzhi,"(%d+),(%d+)")
kh=tonumber (kuhao)  if kh>16383 then kh=16383 end
ysh=tonumber (yinsehao) if ysh>127 then ysh=127 end
end -- sel_idx~=-1
reaper.MIDI_Sort(take)
--------------------get input
track = reaper.GetMediaItemTake_Track(take)
item_cout = reaper.GetTrackNumMediaItems(track)
item_idx=0
while item_idx<item_cout do
item = reaper.GetTrackMediaItem(track, item_idx)
take = reaper.GetMediaItemTake(item, 0)

reaper.MIDI_DisableSort(take)
retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
ccidx=0
while retval do
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
if chanmsg==176 and msg2==0 then yinse_new=msg3*128 
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx+1)
if chanmsg==176 and msg2==32 then yinse_new=yinse_new+msg3 
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx+2)
if chanmsg==192  then yinse_new=yinse_new..','..msg2 

if yinse_new==yinse then 
reaper.MIDI_SetCC(take, ccidx, true, NULL,NULL, NULL, NULL, NULL, math.modf(kh/128) , false)
reaper.MIDI_SetCC(take, ccidx+1, true, NULL,NULL, NULL, NULL, NULL, kh%128, false)
reaper.MIDI_SetCC(take, ccidx+2, true, NULL,NULL, NULL, NULL, ysh, NULL, false)
end

ccidx=ccidx+2
end  end  end
ccidx=ccidx+1
retval,selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
end
reaper.MIDI_Sort(take)
item_idx=item_idx+1
end

reaper.SN_FocusMIDIEditor()
