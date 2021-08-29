--[[
 * ReaScript Name: Track Name Fix
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

integer = reaper.CountMediaItems(0)
 idx = 0
 while idx < integer do
 MediaItem = reaper.GetMediaItem(0, idx)
 idx=idx+1
 take = reaper.GetTake(MediaItem, 0)
 retval, selected, muted, ppqpos, type_1, msg = reaper.MIDI_GetTextSysexEvt(take, 0, NULL, NULL, NULL, 3, '')
   if type_1 == 3 then
   track  = reaper.GetMediaItem_Track(MediaItem)
   reaper.GetSetMediaTrackInfo_String(track,'P_NAME',msg, true)
   reaper.MIDI_DeleteTextSysexEvt(take, 0)
   end -- if end
   
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
   -------------------------  move CC0 CC32
   
 end -- while end
