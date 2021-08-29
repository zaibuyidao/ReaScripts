--[[
 * ReaScript Name: Edit Val
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

editor=reaper.MIDIEditor_GetActive()
take=reaper.MIDIEditor_GetTake(editor)

integer = reaper.MIDI_EnumSelCC(take, -1)

retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, integer)

   if chanmsg == 176  then
     if msg2 ~= 0 then 
     retval,Val= reaper.GetUserInputs('Edit Val',1,'输入 CC '..msg2..' 数值 =','0') 
     shuru=tonumber (Val)
     reaper.MIDI_SetCC(take, integer, NULL, NULL, NULL, NULL, NULL, NULL, shuru, true)
     else
     integer2 = reaper.MIDI_EnumSelCC(take,integer)
     retval2, selected2, muted2, ppqpos2, chanmsg2, chan2, msg22, msg32 = reaper.MIDI_GetCC(take, integer2)
     if chanmsg == 176 and  msg22 == 32 then
     retval,Val= reaper.GetUserInputs('Edit Val',1,'输入音色 Bank =','0') 
     shuru=tonumber (Val)
     MSB = math.modf( shuru / 128 ) 
     LSB = shuru % 128
     reaper.MIDI_SetCC(take, integer, NULL, NULL, NULL, NULL, NULL, NULL, MSB, true)
     reaper.MIDI_SetCC(take, integer2, NULL, NULL, NULL, NULL, NULL, NULL, LSB, true)
     end  -- PC end
     end -- cc0 end
    end  -- if end
   if chanmsg == 192 then 
   retval,Val= reaper.GetUserInputs('Edit Val',1,'输入音色号 =','0') 
   shuru=tonumber (Val)
   reaper.MIDI_SetCC(take, integer, NULL, NULL, NULL, NULL, NULL, shuru, NULL, true)
   end
   if chanmsg == 224 then 
   retval,Val= reaper.GetUserInputs('Edit Val',1,'输入弯音数值 =','0') 
   shuru=tonumber (Val)
   pitch = shuru 
   
   if (pitch > 8191) then pitch = 8191 end
   if (pitch <= -8192) then pitch = -8191 end
   
   local beishu = math.modf( pitch / 128 )
   local yushu = math.fmod( pitch, 128 ) 
   if (beishu < 0)
   then beishu=beishu-1
   end
   reaper.MIDI_SetCC(take, integer, NULL, NULL, NULL, NULL, NULL, yushu, 64+beishu, true)
   end  -- wheel end
  reaper.MIDI_Sort(take)
  reaper.SN_FocusMIDIEditor()
  reaper.MIDIEditor_OnCommand(editor, 65535)
