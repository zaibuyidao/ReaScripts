--[[
 * ReaScript Name: MIX 工程规范检测
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

txt = ''
retval, timepos1, measurepos1, beatpos1, bpm1, timesig_num1, timesig_denom1, lineartempo = reaper.GetTempoTimeSigMarker(0, 0)
retval, timepos2, measurepos2, beatpos2, bpm2, timesig_num2, timesig_denom2, lineartempo = reaper.GetTempoTimeSigMarker(0, 1)
if retval ~= false then
if measurepos2 <= 2 and bpm1~=bpm2 then 
txt = '错误：起始速度和歌曲速度不一致！ \n' end
bili_1=timesig_num1 / timesig_denom1 bili_2=timesig_num2 / timesig_denom2
if measurepos2 <= 2 and bili_1~=bili_2 then 
txt = txt ..'错误：起始节拍和歌曲节拍不一致！ \n' end
end
xuanze = 1
   if  bili_1 == 0.75 then xuanze = reaper.MB('全曲节拍设定为 43 或者 86 ？', '节拍设定确认！', 4) end
   if xuanze == 7 then txt = txt ..'错误：全曲节拍设定确认并修改！ \n' end
i=0
repeat 
retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, i)
bili=timesig_num / timesig_denom  if  bili < 0.75 then txt = txt .. '有低于43或者86的拍子在第 ' ..measurepos+1 ..' 小节! \n' end
i = i+1
until retval==false

tb_mark={}  
tb_mark['intro']='In'  tb_mark['bridge']='Br' tb_mark['end']='Ending' tb_mark['outro']='Ending' 
tb_mark['birdge']= 'Br' tb_mark['in']='In' tb_mark['br']='Br' tb_mark['out']='Ending' tb_mark['ending']='Ending'
tb_mark['a']='A'   tb_mark['b']='B' tb_mark['c']='C' tb_mark['d']='D' tb_mark['e']='E' tb_mark['f']='F' 
tb_mark['g']='G' tb_mark['h']='H' tb_mark['i']='I' tb_mark['j']='J' tb_mark['k']='K'
tb_mark['key=a']='Key=A' tb_mark['key=b']='Key=B' tb_mark['key=c']='Key=C' 
tb_mark['key=d']='Key=D' tb_mark['key=e']='Key=E' tb_mark['key=f']='Key=F' tb_mark['key=g']='Key=G' 
tb_mark['key=ab']='Key=Ab' tb_mark['key=g#']='Key=Ab' tb_mark['key=bb']='Key=Bb' tb_mark['key=a#']='Key=Bb'
tb_mark['key=db']='Key=C#' tb_mark['key=c#']='Key=C#' tb_mark['key=d#']='Key=Eb' 
tb_mark['key=eb']='Key=Eb' tb_mark['key=gb']='Key=F#' tb_mark['key=f#']='Key=F#'

midx =0
retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
num_maker2=num_markers+num_regions-1
poslist={}
while midx<num_maker2 do
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)

takeidx=0
repeat 
item=reaper.GetMediaItem(0,takeidx)
take=reaper.GetTake(item,0)
takeidx=takeidx+1
until reaper.TakeIsMIDI(take)
tick=reaper.MIDI_GetPPQPosFromProjTime(take,pos)
start=reaper.MIDI_GetPPQPos_StartOfMeasure(take,tick)
if tick~=start then 
txt = txt ..'错误：标签'..name..'不在小节最前面！ \n' end

name_low = string.lower(name)
if name=='' or name_low=='start' then reaper.DeleteProjectMarkerByIndex(0, midx) 
midx=midx-1 num_maker2=num_maker2-1
else
name_low = string.lower(name)
name_low=string.gsub(name_low,'%d+','')
if tb_mark[name_low] ~= nil then 
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,tb_mark[name_low])

poslist[midx]= tb_mark[name_low]
else
buf = reaper.format_timestr_pos(pos, '', 2)
txt = txt ..'错误：有无法识别的标签 "'..name..'" 在 '..buf..' ！ \n'
end
end
midx = midx + 1 
end --while end
m_retval, isrgn, pos, rgnend, name_end, markrgnindexnumber = reaper.EnumProjectMarkers2(0,midx)

takeidx=0
repeat 
item=reaper.GetMediaItem(0,takeidx)
take=reaper.GetTake(item,0)
takeidx=takeidx+1
until reaper.TakeIsMIDI(take)
tick=reaper.MIDI_GetPPQPosFromProjTime(take,pos)
start=reaper.MIDI_GetPPQPos_StartOfMeasure(take,tick)
if tick~=start then 
txt = txt ..'错误：最后一个标签'..'不在小节最前面！ \n' end

if name_end~='' then  txt = txt ..'错误：最后一个标签 "'..name_end..'" 不是空白！ \n' end
m_retval, isrgn, pos, rgnend, name_key, markrgnindexnumber = reaper.EnumProjectMarkers(0)
name_key2=string.match(name_key, 'Key=')
if name_key2~='Key=' then  txt = txt ..'错误：第一个标签 "'..name_key..'" 不是 Key=***！ \n' end

   
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='A' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='B' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='C' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='D' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='E' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='F' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='G' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='H' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='I' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='J' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='K' then 
if jishu~=0 then name=name..jishu end
reaper.SetProjectMarker(markrgnindexnumber, false, pos,0,name)
jishu=jishu+1
end
midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 
-----------------------------------
midx =0
jishu=0
repeat 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
if name =='In' then 
retval, measures,cml, fullbeats, cdenom = reaper.TimeMap2_timeToBeats(0, pos)
pos = reaper.TimeMap2_beatsToTime(0, 0, measures-2)
--reaper.AddProjectMarker(0, false, pos, -1, 'START', -1)
end

midx = midx + 1 
m_retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(midx)
until m_retval == 0 

if txt=='' then txt='MIX 工程格式正确！ 所有标记格式已规范处理！ ' 
reaper.MB(txt,'恭喜！',0)
else 
reaper.ClearConsole()
reaper.ShowConsoleMsg(txt)
end
