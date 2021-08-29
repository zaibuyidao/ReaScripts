--[[
 * ReaScript Name: GetSet Track Info
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

count = reaper.CountSelectedTracks(0)
if count==0 then return end
if count==1 then 
MediaTrack = reaper.GetSelectedTrack(0, 0)
retval,tk_name = reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', '', false)
num = reaper.GetMediaTrackInfo_Value(MediaTrack, 'I_MIDIHWOUT')
if num==-1 then port=0 chan=0 
else
port = math.modf( num / 32 ) + 1
chan = math.fmod( num, 32 )
chan=string.match(chan,'%d+')
end
msg=tk_name..','..port..','..chan
bl,input=reaper.GetUserInputs('GetSet Track Info',3,'Track Name 轨道名称:,Track Midi Port 端口:,Track Midi Channel 通道 :,extrawidth=200',msg)
if bl==false then return end 
idx=string.find (input, ',', 1)
name_in=string.sub(input, 0,idx-1)
reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', name_in, true)
input2=string.sub(input,idx+1)
port_new,chan_new=string.match(input2,'(%d+),(%d+)')
port_new=tonumber(port_new)-1  if port_new>15 then port_new=15 end
chan_new=tonumber(chan_new)  if chan_new>16 then chan_new=16 end
num_new=port_new*32+chan_new
reaper.SetMediaTrackInfo_Value(MediaTrack,'I_MIDIHWOUT',num_new)
end
-- dangui end

if count>1 then 
duogui=reaper.MB('是否按顺序设置多个轨道？否则只设置第一个被选中的轨道！','多个轨道信息！',4) 
if duogui==7 then
MediaTrack = reaper.GetSelectedTrack(0, 0)
retval,tk_name = reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', '', false)
num = reaper.GetMediaTrackInfo_Value(MediaTrack, 'I_MIDIHWOUT')
if num==-1 then port=0 chan=0 
else
port = math.modf( num / 32 ) + 1
chan = math.fmod( num, 32 )
chan=string.match(chan,'%d+')
end
msg=tk_name..','..port..','..chan
bl,input=reaper.GetUserInputs('GetSet Track Info',3,'Track Name 轨道名称:,Track Midi Port 端口:,Track Midi Channel 通道 :,extrawidth=200',msg)
if bl==false then return end 
idx=string.find (input, ',', 1)
name_in=string.sub(input, 0,idx-1)
reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', name_in, true)
input2=string.sub(input,idx+1)
port_new,chan_new=string.match(input2,'(%d+),(%d+)')
port_new=tonumber(port_new)-1   if port_new>15 then port_new=15 end
chan_new=tonumber(chan_new)  if chan_new>16 then chan_new=16 end
num_new=port_new*32+chan_new
reaper.SetMediaTrackInfo_Value(MediaTrack,'I_MIDIHWOUT',num_new)
-- dangui end
else
tr_idx=0
while tr_idx < count do
MediaTrack = reaper.GetSelectedTrack(0, tr_idx)
retval,tk_name = reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', '', false)
num = reaper.GetMediaTrackInfo_Value(MediaTrack, 'I_MIDIHWOUT')
if num==-1 then port=0 chan=0 
else
port = math.modf( num / 32 ) + 1
chan = math.fmod( num, 32 )
chan=string.match(chan,'%d+')
end
msg=tk_name..','..port..','..chan
bl,input=reaper.GetUserInputs('GetSet Track Info',3,'Track Name 轨道名称:,Track Midi Port 端口:,Track Midi Channel 通道 :,extrawidth=200',msg)
if bl==false then return end 
idx=string.find (input, ',', 1)
name_in=string.sub(input, 0,idx-1)
reaper.GetSetMediaTrackInfo_String(MediaTrack, 'P_NAME', name_in, true)
input2=string.sub(input,idx+1)
port_new,chan_new=string.match(input2,'(%d+),(%d+)')
port_new=tonumber(port_new)-1   if port_new>15 then port_new=15 end
chan_new=tonumber(chan_new)  if chan_new>16 then chan_new=16 end
num_new=port_new*32+chan_new
reaper.SetMediaTrackInfo_Value(MediaTrack,'I_MIDIHWOUT',num_new)
tr_idx=tr_idx+1
end --while end
end --if yes
end  -- count>1 end



