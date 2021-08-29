--[[
 * ReaScript Name: 显示MIDI模板信息
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

_, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID,ownCommandID,1)
reaper.RefreshToolbar2(sectionID, ownCommandID)

out=''
count=reaper.CountTracks(0)
idx=0
while idx<count do
track=reaper.GetTrack(0,idx)
item=reaper.GetTrackMediaItem(track,0)
if item~=nil then
take=reaper.GetMediaItemTake(item,0)
if reaper.TakeIsMIDI(take) then 
retval,name=reaper.GetSetMediaTrackInfo_String(track,'P_NAME','',false)
if #name<20 then blank=20-#name 
i=0 
while i<blank do name=name..' ' i=i+1 end
else name=string.sub(name, 0,18)..'..'
end
retval, notecnt, ccevtcnt,textsyxevtcnt = reaper.MIDI_CountEvts(take)
ccidx=0
if ccevtcnt~=0 then 
while ccidx<ccevtcnt do
retval,selected,muted, ppqpos,chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccidx)
if chanmsg==176 then

if msg2==0 then
cc0=msg3
end
if msg2==32 then
bank=cc0*128+msg3 bank=tostring(bank)
if #bank<6 then blank=6-#bank end
i=0 
while i<blank do bank=bank..' ' i=i+1 end
end

if msg2==7 then
vol=msg3  vol=tostring(vol)
if #vol<4 then blank=4-#vol end
i=0 
while i<blank do vol=vol..' ' i=i+1 end
end

if msg2==10 then
pan=msg3  pan=tostring(pan)
if #pan<4 then blank=4-#pan end
i=0 
while i<blank do pan=pan..' ' i=i+1 end
end

if msg2==91 then
rev=msg3  rev=tostring(rev)
if #rev<4 then blank=4-#rev end
i=0 
while i<blank do rev=rev..' ' i=i+1 end
end

if msg2==93 then
cho=msg3  cho=tostring(cho)
if #cho<4 then blank=4-#cho end
i=0 
while i<blank do cho=cho..' ' i=i+1 end
end

delay=''
if msg2==94 then
delay=msg3  delay=tostring(delay)
if #delay<4 then blank=4-#delay end
i=0 
while i<blank do delay=delay..' ' i=i+1 end
end

end --chanmsg==176

if chanmsg==192 then
PC=msg2  PC=tostring(PC)
if #PC<4 then blank=4-#PC end
i=0 
while i<blank do PC=PC..' ' i=i+1 end
end

ccidx=ccidx+1
end --while
out=out..name..' Bank='..bank..' Patch='..PC..' Vol='..vol..' Pan='..pan..' Rev='..rev..' Cho='..cho..' Delay='..delay..'\n---------------------------------------------------------------------------------------\n'
end --ccevtcnt~=0
end --TakeIsMIDI
end --item~=nil
idx=idx+1
end
--reaper.ShowConsoleMsg('')
--reaper.ShowConsoleMsg(out)


local ctx = reaper.ImGui_CreateContext('My script')
 reaper.ImGui_SetNextWindowSize(ctx, 650, 900)
function loop()

 local visible, open = reaper.ImGui_Begin(ctx, 'MIDI Template information', true)
 if visible then
   --reaper.ImGui_Text(ctx, out)
     reaper.ImGui_TextColored(ctx, 0XDCDCDCFF, out)
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(loop)

function exit()
reaper.SetToggleCommandState(sectionID,ownCommandID,0)
reaper.RefreshToolbar2(sectionID,ownCommandID)
end
reaper.atexit(exit)
