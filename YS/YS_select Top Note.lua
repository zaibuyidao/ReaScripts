--[[
 * ReaScript Name: select Top Note
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

i,idx=2,-1

tbidx={}
tbst={}
tbpitch={}
selidx={}
tempst=-11
integer = reaper.MIDI_EnumSelNotes(take,idx)

while (integer ~= -1) do

integer = reaper.MIDI_EnumSelNotes(take,idx)

retval,selected, muted,startppqpos,endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
juli = startppqpos - tempst
if juli < 0 then juli = juli * -1 end
if juli <= 10 then
tbidx[i]=integer
tbpitch[i]=pitch
tbst[i]=startppqpos
i=i+1
else 
-- STRUM it
top=tbpitch[1]

for i, v in ipairs(tbpitch) do
if (top > v) then top=top else top=v end
end -- get top note

for i, vv in ipairs(tbidx) do
retval,_, _,_,_, _, pitch_b, _ = reaper.MIDI_GetNote(take, vv)
if pitch_b == top then 
table.insert(selidx,vv)
end --select end
end -- for end
tbidx={}
tbpitch={}
tbst={}

tbidx[1]=integer
tbst[1]=startppqpos
tbpitch[1]=pitch
i=2
end--if end
tempst = startppqpos
idx=integer
end -- while end
reaper.MIDI_SelectAll(take, false)
for i, v in ipairs(selidx) do
reaper.MIDI_SetNote(take,v,true,NULL,NULL,NULL,NULL,NULL,NULL,false)
end

reaper.MIDI_Sort(take)

reaper.SN_FocusMIDIEditor()
