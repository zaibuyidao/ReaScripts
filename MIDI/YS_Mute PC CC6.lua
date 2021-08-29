--[[
 * ReaScript Name: Mute PC CC6
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

reaper.Undo_BeginBlock()
integer = reaper.CountMediaItems(0)
 idx = 0
 ccidx ,syxidx = 0, 0
 
 while idx < integer do
 MediaItem = reaper.GetMediaItem(0, idx)
 idx=idx+1
  take = reaper.GetTake(MediaItem, 0)
  num = reaper.GetMediaItemInfo_Value(MediaItem, 'IP_ITEMNUMBER')
   if ( num == 0 and reaper.TakeIsMIDI(take) ) then
   --if reaper.TakeIsMIDI(take)  then
   retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
     if ccevtcnt > 0 then 
     while ccidx < ccevtcnt do 
     retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
      if chanmsg == 176 and msg2 == 6 then 
      reaper.MIDI_SetCC(take, ccidx, false, true, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
      end -- if cc6 end
      if chanmsg == 176  then 
        if msg2 >=98 and msg2 <= 101 then
      reaper.MIDI_SetCC(take, ccidx, false, true, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
      end
      end -- if cc98-101 end
      if chanmsg == 192  then 
      reaper.MIDI_SetCC(take, ccidx, false, true, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
      end -- if PC end
      ccidx = ccidx + 1
    end -- while end
    ccidx = 0
  end   -- if ccevt end
    if textsyxevtcnt > 0 then 
    while syxidx < textsyxevtcnt do
    reaper.MIDI_SetTextSysexEvt(take, syxidx, false, true, NULL, NULL, '', true)
    reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 16777471)
    syxidx = syxidx + 1
    end -- while end
    syxidx = 0
    end -- if syx end
    reaper.MIDI_Sort(take)
  end   --take midi end
end -- while end
reaper.UpdateArrange()
reaper.Undo_EndBlock('', 0)


