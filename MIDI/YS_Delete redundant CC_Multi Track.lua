--[[
 * ReaScript Name: Delete redundant CC_Multi Track
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

local retval, shuzhi = reaper.GetUserInputs('Delete redundant CC', 2, 'CC num 控制器号 =,CC Adjacent values 前后差值 =,', '11,0')
local num_sub,adj_sub=string.match(shuzhi,"(%d+),(%d+)")
local num_val=tonumber (num_sub)
local adj_val=tonumber (adj_sub)
-- qushuzhi
editor=reaper.MIDIEditor_GetActive()
contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
reaper.MIDI_DisableSort(take)

local ccidx=-1
local tempcc=256
repeat
     integer = reaper.MIDI_EnumSelCC(take, ccidx)
     retval,selected,muted,ppqpos, chanmsg, chan, num, val = reaper.MIDI_GetCC(take, integer)
     adj = val - tempcc
    if adj < 0 then adj = adj * (-1) end
  if (num == num_val) and (adj <= adj_val) then
 reaper.MIDI_DeleteCC(take, integer)
 else
 tempcc=val
 ccidx=integer
 end
 
until integer==-1
--delete CC 
reaper.MIDI_Sort(take)
end
end -- while item end
reaper.SN_FocusMIDIEditor()
