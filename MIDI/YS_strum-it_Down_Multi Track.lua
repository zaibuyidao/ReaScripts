--[[
 * ReaScript Name: strum-it_Down_Multi Track
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

retval, shuzhi = reaper.GetUserInputs('Strum it Down', 1, 'Strum Tick ', '3')
num_sub=string.match(shuzhi,"(%d+)")
num=tonumber (num_sub)
if retval then   

contselitem= reaper.CountSelectedMediaItems(0)
selitem = 0
while selitem < contselitem do
MediaItem = reaper.GetSelectedMediaItem(0, selitem)
selitem = selitem + 1
take = reaper.GetTake(MediaItem, 0)
if reaper.TakeIsMIDI(take) then
reaper.MIDI_DisableSort(take)

i,idx=2,-1

tbidx={}
tbst={}
tbend={}
tbchan={}
tbpitch={}
tbpitch2={}
tbvel={}
tempst=-1
TBinteger={}
integer = reaper.MIDI_EnumSelNotes(take,idx)

while (integer ~= -1) do

integer = reaper.MIDI_EnumSelNotes(take,idx)
TBinteger[i]=integer

retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)

if startppqpos == tempst then
tbidx[i]=integer
tbst[i]=startppqpos
tbend[i]=endppqpos
tbchan[i]=chan
tbpitch[i]=pitch
tbpitch2[i]=pitch
tbvel[i]=vel
i=i+1
else 
-- STRUM it
low=tbpitch[1]

for i, v in ipairs(tbpitch) do
if (low < v) then low=low else low=v end
end -- get low note
table.sort (tbpitch)
tbp_new={}
for i, v in ipairs(tbpitch) do
tbp_new [ v ] = i
end
for i, vv in ipairs(tbidx) do
haha= reaper.MIDI_SetNote(take, vv, true, false, tbst[i] + (tbp_new[tbpitch2[i]]-1)*num, tbend[i], NULL, NULL,NULL, false)
end --strum it end
tbidx={}
tbst={}
tbend={}
tbchan={}
tbpitch={}
tbpitch2={}
tbvel={}
tbidx[1]=integer
tbst[1]=startppqpos
tbend[1]=endppqpos
tbchan[1]=chan
tbpitch[1]=pitch
tbpitch2[1]=pitch
tbvel[1]=vel
i=2
end--if end
tempst = startppqpos
idx=integer
end -- while end
reaper.MIDI_Sort(take)
end
end -- while item end
end -- not 0 end

reaper.SN_FocusMIDIEditor()
