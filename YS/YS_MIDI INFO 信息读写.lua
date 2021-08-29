--[[
 * ReaScript Name: MIDI INFO 信息读写
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

countitem=reaper.CountMediaItems(0)
i,count=0,0
txt=''
while i<countitem do 
item=reaper.GetMediaItem(0,i)
take=reaper.GetMediaItemTake(item,0)
  if reaper.TakeIsMIDI(take) then
  retval,notecnt,ccevtcnt,txtcnt=reaper.MIDI_CountEvts(take)
  if txtcnt~=0 then
  txtid=0
  repeat 
  retval, selected, muted, ppqpos, t_type, msg = reaper.MIDI_GetTextSysexEvt(take, txtid, NULL, NULL, -1, 1, '')
  PJtime=reaper.MIDI_GetProjTimeFromPPQPos(take,ppqpos)
  if t_type==1 and PJtime==0 then 
  txt=txt..msg..',' count=count+1 infotake=take infotxtcnt=txtcnt 
  track=reaper.GetMediaItemTake_Track(take)
  retval, trackname = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
  end
  txtid=txtid+1
  until txtid==txtcnt
  end
  end
i=i+1
end
input='Info 第 1 行 ：,Info 第 2 行 ：,Info 第 3 行 ：,Info 第 4 行 ：,Info 第 5 行 ：,Info 第 6 行 ：,Info 第 7 行 ：,Info 第 8 行 ：,Info 第 9 行 ：,Info 第 10 行 ：,Info 第 11 行 ：,Info 第 12 行 ：,Info 第 13 行 ：,Info 第 14 行 ：,Info 第 15 行 ：,Info 第 16 行 ：,extrawidth=300'
reaper.GetUserInputs('MIDI INFO in " '..trackname,count,input,txt)
