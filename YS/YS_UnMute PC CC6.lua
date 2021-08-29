--[[
 * ReaScript Name: UnMute PC CC6
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

reaper.Main_OnCommand(40340, 0)
reaper.Undo_BeginBlock()

  function takename()
  stringNeedBig = ''
  take = reaper.GetTake(MediaItem, 0)
  if reaper.TakeIsMIDI(take)  then
  track  = reaper.GetMediaItem_Track(MediaItem)
  buf = reaper.GetProjectName(0, '')
  num = reaper.GetMediaItemInfo_Value(MediaItem, 'IP_ITEMNUMBER')
  num = num + 1
  n1,n2 = math.modf(num)
  retval, stringNeedBig = reaper.GetSetMediaTrackInfo_String(track,'P_NAME','', false)
  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', buf..' - '..'['..stringNeedBig..']'..' #'..n1, true)
  end
  end
-------------------------------------------------
integer = reaper.CountMediaItems(0)
 idx = 0
 ccidx , syxidx= 0 ,0
 haha = {}
 while idx < integer do
 MediaItem = reaper.GetMediaItem(0, idx)
 idx=idx+1
  take = reaper.GetTake(MediaItem, 0)
  num = reaper.GetMediaItemInfo_Value(MediaItem, 'IP_ITEMNUMBER')
  haha[idx] = num
    if ( num == 0 and reaper.TakeIsMIDI(take) ) then
   retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
     if ccevtcnt > 0 then 
     while ccidx < ccevtcnt do 
     retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
      if chanmsg == 176 and msg2 == 6 then 
      reaper.MIDI_SetCC(take, ccidx, false, false, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
      end -- if cc6 end
      if chanmsg == 176  then 
        if msg2 >=98 and msg2 <= 101 then
      reaper.MIDI_SetCC(take, ccidx, false, false, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
      end
      end -- if cc98-101 end
      if chanmsg == 192  then 
      reaper.MIDI_SetCC(take, ccidx, false, false, ppqpos, chanmsg, chan, msg2, msg3, true)
      reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
      end -- if PC end
      ccidx = ccidx + 1
    end -- while end
    ccidx = 0
  end  -- if ccevt end
  if textsyxevtcnt > 0 then 
  while syxidx < textsyxevtcnt do
  retval, selected, muted, ppqpos, txt_type, msg =reaper.MIDI_GetTextSysexEvt(take,syxidx,false,false,0,0,'')

  reaper.MIDI_SetTextSysexEvt(take, syxidx, false, false, NULL, NULL, '', false)

  reaper.SetMediaItemTakeInfo_Value(take, 'I_CUSTOMCOLOR', 21036800)
  syxidx = syxidx + 1
  end -- while end
  syxidx = 0
  end -- if syx end
  reaper.MIDI_Sort(take)
  end -- if takemidi end
  takename()
end -- while end
reaper.UpdateArrange()
reaper.Undo_EndBlock('', 0)


