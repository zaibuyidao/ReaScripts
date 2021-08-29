--[[
 * ReaScript Name: select Note_Multi Track
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

reaper.PreventUIRefresh(1)

retval, shuzhi = reaper.GetUserInputs('Select Note', 8, 'Tick Min,Tick Max,Beat Min 起始拍,Beat Max 结束拍,Duration Min 最小长度,Duration Max 最大长度,Vel Min 最小力度,Vel Max 最大力度', '0,479,1,16,0,57600,0,127')
if  retval  then 
Tmin_sub,Tmax_sub,Bmin_sub,Bmax_sub,Dmin_sub,Dmax_sub,Vmin_sub,Vmax_sub=string.match(shuzhi,"(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
Tmin=tonumber (Tmin_sub)   Tmax=tonumber (Tmax_sub)  Bmin=tonumber (Bmin_sub)  Bmax=tonumber (Bmax_sub)
Dmin=tonumber (Dmin_sub)  Dmax=tonumber (Dmax_sub) Vmin=tonumber (Vmin_sub)  Vmax=tonumber (Vmax_sub)
Bmin=Bmin-1  Bmax=Bmax


local editor=reaper.MIDIEditor_GetActive()

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)

if reaper.TakeIsMIDI(take) then
 
local idx=-1 selidx={}

reaper.MIDI_DisableSort(take)

repeat

local integer = reaper.MIDI_EnumSelNotes(take, idx)

  if integer==-1 then break end

local retval, sel, mute, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)

local tick_m = startppqpos-reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)

local dur=endppqpos-startppqpos

local tick= tick_m % 480

if  (tick_m >= Bmin*480 and tick_m < Bmax*480) and (tick >= Tmin and tick <=Tmax) and (dur >= Dmin and dur <=Dmax) and (vel <= Vmax and vel >= Vmin)
then
table.insert(selidx,integer)
end

idx = integer

until (integer == -1)

reaper.MIDI_SelectAll(take,false)

for i , v in ipairs(selidx) do
reaper.MIDI_SetNote(take,v,true,NULL,NULL,NULL,NULL,NULL,NULL,false)
end

reaper.MIDI_Sort(take)

end -- take is midi
end -- while item end

end -- getinput

reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()





