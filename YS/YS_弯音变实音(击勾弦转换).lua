--[[
 * ReaScript Name: 弯音变实音(击勾弦转换)
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

integer = reaper.MIDI_EnumSelNotes(take, -1)
if integer == -1 then reaper.ShowMessageBox('没有音符被选中！', '错误！', 0) reaper.SN_FocusMIDIEditor() return end

retval, selected, muted, startppqpos, endppqpos1, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)

ccidx=reaper.MIDI_EnumSelCC(take, -1)

if ccidx ~= -1 then

ccidx_temp=-1
repeat
 ccidx_new2=reaper.MIDI_EnumSelCC(take, ccidx_temp) 
  _, _, _, ppqpos_new2, chanmsg, _, _, _ = reaper.MIDI_GetCC(take, ccidx_new2)
  if chanmsg == 224 then
  if ppqpos_new2>endppqpos1+10 then 
  reaper.ShowMessageBox('弯音时间位置超出音符，转换终止！', '错误！', 0) reaper.SN_FocusMIDIEditor()
  return end end
  ccidx_temp = ccidx_new2
  until ccidx_new2 == -1
 
 -----------------------------------------------

retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)

if chanmsg == 224 then

reaper.MIDI_SetCC(take, ccidx, NULL, true, NULL, NULL, NULL, NULL, NULL, false)

 wheel1 = msg2+msg3*128-8192
 chufa = ppqpos 
 
 reaper.MIDI_SetNote(take, integer, NULL, NULL, NULL, ppqpos+10, NULL, NULL, NULL, false)
end
else 
reaper.ShowMessageBox('没有 Wheel 被选中！', '错误！', 0) reaper.SN_FocusMIDIEditor() return end
----------------------------------------------------
repeat

 ccidx_new=reaper.MIDI_EnumSelCC(take, ccidx) 
 
 retval, selected, muted, ppqpos_new, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx_new)
 
 if chanmsg == 224 then
 
 
 reaper.MIDI_SetCC(take, ccidx_new, NULL, true, NULL, NULL, NULL, NULL, NULL, false)
 
  wheel2= msg2+msg3*128-8192
  
  if wheel1 == 0 
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch, vel, false)
  end
  if wheel1 > -800 and wheel1 < -500 
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-1, vel, false)
  end
  if wheel1 > -1500 and wheel1 < -1200 
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-2, vel, false)
  end
  if wheel1 > -2200 and wheel1 < -1800
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-3, vel, false)
  end
  if wheel1 > -2900 and wheel1 < -2500
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-4, vel, false)
  end
  if wheel1 > -3600 and wheel1 < -3200
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-5, vel, false)
  end
  if wheel1 > -4200 and wheel1 < -3800
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-6, vel, false)
  end
  if wheel1 > -4900 and wheel1 < -4500
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-7, vel, false)
  end
  if wheel1 > -5600 and wheel1 < -5200
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-8, vel, false)
  end
  if wheel1 > -6300 and wheel1 < -5900
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-9, vel, false)
  end
  if wheel1 > -7000 and wheel1 < -6600
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-10, vel, false)
  end
  if wheel1 > -7700 and wheel1 < -7300
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-11, vel, false)
  end
  if wheel1 > -8193 and wheel1 < -8000
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch-12, vel, false)
  end
  ----- ++++
  if wheel1 < 800 and wheel1 > 500 
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+1, vel, false)
  end
  if wheel1 < 1500 and wheel1 > 1200 
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+2, vel, false)
  end
  if wheel1 < 2200 and wheel1 > 1800
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+3, vel, false)
  end
  if wheel1 < 2900 and wheel1 > 2500
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+4, vel, false)
  end
  if wheel1 < 3600 and wheel1 > 3200
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+5, vel, false)
  end
  if wheel1 < 4200 and wheel1 > 3800
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+6, vel, false)
  end
  if wheel1 < 4900 and wheel1 > 4500
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+7, vel, false)
  end
  if wheel1 < 5600 and wheel1 > 5200
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+8, vel, false)
  end
  if wheel1 < 6300 and wheel1 > 5900
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+9, vel, false)
  end
  if wheel1 < 7000 and wheel1 > 6600
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+10, vel, false)
  end
  if wheel1 < 7700 and wheel1 > 7300
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+11, vel, false)
  end
  if wheel1 < 8193 and wheel1 > 8000
  then reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos_new+10, chan, pitch+12, vel, false)
  end 

  ppqpos=ppqpos_new  
  chufa_end = ppqpos_new  
  wheel1=wheel2
  
 end 
 ccidx_new=reaper.MIDI_EnumSelCC(take, ccidx)
 if  ccidx_new == -1 then 
 if endppqpos1>ppqpos then 
 if wheel1 == 0 
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch, vel, false)
 end
 if wheel1 > -800 and wheel1 < -500 
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-1, vel, false)
 end
 if wheel1 > -1500 and wheel1 < -1200 
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-2, vel, false)
 end
 if wheel1 > -2200 and wheel1 < -1800
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-3, vel, false)
 end
 if wheel1 > -2900 and wheel1 < -2500
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-4, vel, false)
 end
 if wheel1 > -3600 and wheel1 < -3200
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-5, vel, false)
 end
 if wheel1 > -4200 and wheel1 < -3800
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-6, vel, false)
 end
 if wheel1 > -4900 and wheel1 < -4500
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-7, vel, false)
 end
 if wheel1 > -5600 and wheel1 < -5200
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-8, vel, false)
 end
 if wheel1 > -6300 and wheel1 < -5900
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-9, vel, false)
 end
 if wheel1 > -7000 and wheel1 < -6600
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-10, vel, false)
 end
 if wheel1 > -7700 and wheel1 < -7300
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-11, vel, false)
 end
 if wheel1 > -8193 and wheel1 < -8000
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch-12, vel, false)
 end
 ----- ++++
 if wheel1 < 800 and wheel1 > 500 
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+1, vel, false)
 end
 if wheel1 < 1500 and wheel1 > 1200 
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+2, vel, false)
 end
 if wheel1 < 2200 and wheel1 > 1800
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+3, vel, false)
 end
 if wheel1 < 2900 and wheel1 > 2500
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+4, vel, false)
 end
 if wheel1 < 3600 and wheel1 > 3200
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+5, vel, false)
 end
 if wheel1 < 4200 and wheel1 > 3800
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+6, vel, false)
 end
 if wheel1 < 4900 and wheel1 > 4500
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+7, vel, false)
 end
 if wheel1 < 5600 and wheel1 > 5200
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+8, vel, false)
 end
 if wheel1 < 6300 and wheel1 > 5900
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+9, vel, false)
 end
 if wheel1 < 7000 and wheel1 > 6600
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+10, vel, false)
 end
 if wheel1 < 7700 and wheel1 > 7300
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+11, vel, false)
 end
 if wheel1 < 8193 and wheel1 > 8000
 then reaper.MIDI_InsertNote(take, false, false, ppqpos, endppqpos1, chan, pitch+12, vel, false)
 end 
  end 
 retval, notecnt,ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, notecnt-1)
 reaper.MIDI_SetNote(take, notecnt-1, NULL, NULL, NULL, endppqpos1, NULL, NULL, NULL, false)
 end 

 ccidx = ccidx_new
 
 until ccidx_new == -1
 
 
 reaper.MIDI_Sort(take)
 





