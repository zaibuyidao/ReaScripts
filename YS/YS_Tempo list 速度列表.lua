--[[
 * ReaScript Name: Tempo list 速度列表
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

txt="" i=0 tb={}
itemidx=0
repeat 
item=reaper.GetMediaItem(0, itemidx)
take=reaper.GetTake(item, 0)
itemidx=itemidx+1
until reaper.TakeIsMIDI(take)
repeat 
retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper.GetTempoTimeSigMarker(0, i)
table.insert(tb, bpm)
bpm=(math.floor(bpm*1000 + 0.5) ) /1000
beatpos=math.floor(beatpos) + 1
measurepos=measurepos+1
tick= reaper.MIDI_GetPPQPosFromProjTime(take, timepos)
StartOfMeasure= reaper.MIDI_GetPPQPos_StartOfMeasure(take, tick)
tick_2=(tick-StartOfMeasure)%480
tick_2=math.floor(tick_2+0.5)
tick_2=tostring(tick_2) measurepos=tostring(measurepos)
if #tick_2==1 then tick_2='00'..tick_2 end 
if #tick_2==2 then tick_2='0'..tick_2 end
if #measurepos==1 then measurepos='  '..measurepos end
if #measurepos==2 then measurepos=' '..measurepos end
if bpm~=0 then
txt = txt .. measurepos ..':'..beatpos..':'..tick_2..'    Tempo  '..bpm..'\n'  
end
i = i+1
until retval==false


local ctx = reaper.ImGui_CreateContext('My script')
reaper.ImGui_SetNextWindowSize(ctx, 250, 400)
function loop()

 local visible, open = reaper.ImGui_Begin(ctx, 'Tempo List', true)
 if visible then
   --reaper.ImGui_Text(ctx, out)
     reaper.ImGui_TextColored(ctx, 0XDCDCDCFF, txt)
    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(loop)

_, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID,ownCommandID,1)
reaper.RefreshToolbar2(sectionID, ownCommandID)

function exit()
reaper.SetToggleCommandState(sectionID,ownCommandID,0)
reaper.RefreshToolbar2(sectionID,ownCommandID)
end
reaper.atexit(exit)


