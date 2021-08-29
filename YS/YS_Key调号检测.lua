--[[
 * ReaScript Name: Key调号检测
 * Version: 1.0
 * Author: YS
 * provides: [main=midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

idx=0 tb_key={}  tb_key[1]=0 tb_key[2]=0 tb_key[3]=0 tb_key[4]=0 tb_key[5]=0 tb_key[6]=0 tb_key[7]=0
tb_key[8]=0 tb_key[9]=0 tb_key[10]=0 tb_key[11]=0 tb_key[12]=0
tbtb={}
selnum=reaper.CountSelectedMediaItems(0) 
if selnum<1 then reaper.MB('没有选中任何对象！','错误！',0) return end
repeat
item=reaper.GetSelectedMediaItem(0,idx)
take=reaper.GetMediaItemTake(item,0)
retval, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
noteidx=0 
while noteidx<notecnt do
retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, noteidx)
pitch=pitch%12+1
tb_key[pitch]=tb_key[pitch]+1+(math.random(30)/30)
noteidx=noteidx+1
end
idx=idx+1
until idx==selnum

tb_key2={}
for i,v in ipairs(tb_key) do 
 if v~=0 then table.insert(tb_key2,v) end
end
if #tb_key2 < 7 then reaper.MB('可参考音符太少，无法识别调号，请重新选择参考对象！(可多选)','错误！',0)  
reaper.SN_FocusMIDIEditor() return
end


temp=0
for i,v in ipairs(tb_key) do 
 if v>temp then temp=v no1=v key1=i end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no1 then temp=v no2=v key2=i  end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no2 then temp=v no3=v key3=i  end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no3 then temp=v no4=v key4=i  end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no4 then temp=v no5=v key5=i  end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no5 then temp=v no6=v key6=i  end
end
temp=0
for i,v in ipairs(tb_key) do 
 if v>temp and v<no6 then temp=v no7=v key7=i  end
end

keymax={key1,key2,key3,key4,key5,key6,key7}
table.sort(keymax)
maxnote=(keymax[1]..','..keymax[2]..','..keymax[3]..','..keymax[4]..','..keymax[5]..','..keymax[6]..','..keymax[7])
tb_diaohao={} 
tb_diaohao['1,3,5,6,8,10,12']='C' 
tb_diaohao['1,2,4,6,7,9,11']='C#' 
tb_diaohao['2,3,5,7,8,10,12']='D'
tb_diaohao['1,3,4,6,8,9,11']='Eb'
tb_diaohao['2,4,5,7,9,10,12']='E'
tb_diaohao['1,3,5,6,8,10,11']='F'
tb_diaohao['2,4,6,7,9,11,12']='F#'
tb_diaohao['1,3,5,7,8,10,12']='G'
tb_diaohao['1,2,4,6,8,9,11']='Ab'
tb_diaohao['2,3,5,7,9,10,12']='A'
tb_diaohao['1,3,4,6,8,10,11']='Bb'
tb_diaohao['2,4,5,7,9,11,12']='B'

if tb_diaohao[maxnote]~=nil then reaper.MB('调号为:  '..tb_diaohao[maxnote],'仅供参考！',0) 
else reaper.MB('无法识别调号，请重新选择参考对象！(可多选)','错误！',0) 
end

reaper.SN_FocusMIDIEditor()
