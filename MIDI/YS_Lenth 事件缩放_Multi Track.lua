--[[
 * ReaScript Name: Lenth 事件缩放_Multi Track
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

string = reaper.GetExtState('old lenth', '1')

retval, shuzhi = reaper.GetUserInputs('Lengh 长度 Multi Track', 1, '设定长度比例%：', string)

if retval then
val=tonumber (shuzhi)

 reaper.SetExtState('old lenth', '1', shuzhi, true)
 
 left=math.huge
 else reaper.SN_FocusMIDIEditor() return end

 ------------
 
 contselitem= reaper.CountSelectedMediaItems(0)
 selitem = 0
 while selitem < contselitem do
 MediaItem = reaper.GetSelectedMediaItem(0, selitem)
 selitem = selitem + 1
 take = reaper.GetTake(MediaItem, 0)
 if reaper.TakeIsMIDI(take) then
 reaper.MIDI_DisableSort(take)
  i=-1
  integer = reaper.MIDI_EnumSelEvts(take, i)
  if integer ~= -1 then
 repeat
  integer = reaper.MIDI_EnumSelEvts(take, i)
  retval, selected, muted, ppqpos, msg = reaper.MIDI_GetEvt(take, integer, true, false, -1, '')
  if ppqpos < left then left = ppqpos end
  i=integer
   integer = reaper.MIDI_EnumSelEvts(take, i)
 until  (integer==-1)
 end 
 
 reaper.MIDI_Sort(take)
 end
 end -- selitem end
 
 
 selitem = 0
 while selitem < contselitem do
 MediaItem = reaper.GetSelectedMediaItem(0, selitem)
 selitem = selitem + 1
 take = reaper.GetTake(MediaItem, 0)
 if reaper.TakeIsMIDI(take) then
 reaper.MIDI_DisableSort(take)

 evtidx = -1
integer = reaper.MIDI_EnumSelEvts(take, evtidx)
if  integer ~= -1 then

   repeat
       retval, selected, muted, ppqpos2, msg = reaper.MIDI_GetEvt(take, integer, true, false, -1, '')
       juli = ppqpos2 - left
       newjuli =  juli * (val /100) 
       reaper.MIDI_SetEvt(take, integer, true, false, left+newjuli, msg, false)
       evtidx = integer
       integer = reaper.MIDI_EnumSelEvts(take, evtidx)
       until ( integer == -1 )
      end  -- if end
       
reaper.MIDI_Sort(take) 
end
end --selitem end

reaper.SN_FocusMIDIEditor()




