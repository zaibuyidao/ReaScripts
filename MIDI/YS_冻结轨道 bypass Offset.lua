--[[
 * ReaScript Name: 冻结轨道 bypass Offset
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

idx,i=0,1
track_tb={}
seltrack=reaper.GetSelectedTrack(0, idx)
if seltrack~=nil then
repeat
offset=reaper.GetMediaTrackInfo_Value(seltrack, 'I_PLAY_OFFSET_FLAG')
if offset==0 then 
reaper.SetMediaTrackInfo_Value(seltrack, 'I_PLAY_OFFSET_FLAG', 1)
track_tb[i]=seltrack i=i+1
end
idx=idx+1
seltrack=reaper.GetSelectedTrack(0, idx)
until seltrack==nil
reaper.Main_OnCommand(41223, 0)
end
i=1
while i <= #track_tb do
reaper.SetMediaTrackInfo_Value(track_tb[i], 'I_PLAY_OFFSET_FLAG', 0)
i=i+1
end
