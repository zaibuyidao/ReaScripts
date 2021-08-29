--[[
 * ReaScript Name: Note to Pitch
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

tbon={}
tboff={}
tbpitch={}
tbchan={}
tbvel={}
i=1
repeat
integer = reaper.MIDI_EnumSelNotes(take, -1)
retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, integer)
tbon[i]=startppqpos
tboff[i]=endppqpos
tbpitch[i]=pitch
tbchan[i]=chan
tbvel[i]=vel
i=i+1
boolean = reaper.MIDI_DeleteNote(take, integer)
until  (integer==-1)
i=i-2   --buchang
--
newon=tbon[1]
newoff=tboff[i]
newpitch=tbpitch[1]
newchan=tbchan[1]
newvel=tbvel[1]
reaper.MIDI_InsertNote(take, false, false, newon, newoff-1, newchan, newpitch, newvel, true)
--insert Note
tbpn={}
ii=2
while (ii <= i) do
tbpn[ii]=tbpitch[ii]-tbpitch[1]
ii=ii+1
end
--get pitch num
for ii=2,i  do
 pitch = 683*tbpn[ii] 

  if (pitch > 8191) then pitch = 8191 end
  if (pitch < -8192) then pitch = -8191 end

  local beishu = math.modf( pitch / 128 )
  local yushu = math.fmod( pitch, 128 ) 
    if (beishu < 0)
    then beishu=beishu-1
    end
 reaper.MIDI_InsertCC(take, false, false, tbon[ii] , 224, 0,yushu,64+beishu)
 end
 --insert Pitch
 if (tbpitch[1] ~= tbpitch[i]) then
 reaper.MIDI_InsertCC(take, false, false, tboff[i] , 224, 0,0,64)
 end
 --end Pitch
 reaper.MIDIEditor_OnCommand(editor , 40366)
