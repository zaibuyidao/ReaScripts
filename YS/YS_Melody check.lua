--[[
 * ReaScript Name: Melody check
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

editor=reaper.MIDIEditor_GetActive()
take=reaper.MIDIEditor_GetTake(editor)
function checkmelody()
txt=''
MediaTrack = reaper.GetMediaItemTake_Track(take)
retval, trackname=reaper.GetSetMediaTrackInfo_String(MediaTrack,'P_NAME','',false)
trackname1=string.lower(trackname)

a=string.find(trackname1,'vocal')
b=string.find(trackname1,'melody')
c=string.find(trackname1,'GuideMelo')

if a~=nil or b~=nil or c~=nil then
retval,notecnt, ccevtcnt, textsyxevtcnt=reaper.MIDI_CountEvts(take)
if notecnt~=0 then
noteidx=0 tempend=-1
repeat
retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
if vel~=100 and vel~=1  then txt=txt..'轨道 '..trackname..' 主旋律音符力度格式错误！' break end
if startppqpos<tempend then 
pos=reaper.MIDI_GetProjTimeFromPPQPos(take,startppqpos)
meas=reaper.format_timestr_pos(pos,'',2)
txt=txt..'轨道 '..trackname..'  '..meas..' 主旋律音符有前后重叠！ \n' end
tempend=endppqpos
noteidx=noteidx+1
until noteidx==notecnt
end
end
end

  checkmelody()
  if txt~='' then reaper.MB(txt,'',0)  return end



