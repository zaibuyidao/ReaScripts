--[[
 * ReaScript Name: 发音数超出检测
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

txt=""

retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

note_st={} note_end={}

idx,i=0,1 
while idx<notecnt do 

 retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
 
 note_st[i]=startppqpos note_end[i]=endppqpos
 
 idx=idx+1 i=i+1
 
 end
 
 idx,i=0,1 temppos=-0.2
 
 while idx<notecnt do 
 
  retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
  
  ii,fayinshu=1,0   
  while ii<=#note_st do 
  if startppqpos>=note_st[ii] and startppqpos<note_end[ii] then
  fayinshu=fayinshu+1
  end
  ii=ii+1 end -- while end
  if fayinshu>6 then
  pos=reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
  if pos-temppos>0.1 then
  buf = reaper.format_timestr_pos(pos, '', 2)
  txt=txt..buf ..' 发音数超过 6 \n'
  temppos=pos
  end
  end 
  
  idx=idx+1 i=i+1
  
  end
  reaper.ClearConsole()
  reaper.ShowConsoleMsg(txt)
