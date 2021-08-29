--[[
 * ReaScript Name: Mark 标记移动
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

start, selend = reaper.GetSet_LoopTimeRange(false, false, -1, -1, false)
if selend==0 then return end
retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
mark_num=num_markers+num_regions
idx,i=0,0
settime=1
tb_isrgn={} tb_pos={}  tb_rgnend={}  tb_name={} tb_markrgnindexnumber={} 
while i<mark_num do
retval, isrgn, pos, rgnend, name,markrgnindexnumber = reaper.EnumProjectMarkers(idx)
if pos>=start and pos<=selend then 
reaper.DeleteProjectMarkerByIndex(0, idx)
table.insert(tb_isrgn,isrgn) table.insert(tb_pos,pos) table.insert(tb_rgnend,rgnend) table.insert(tb_name,name) table.insert(tb_markrgnindexnumber,markrgnindexnumber)
timestr=reaper.format_timestr_pos(pos,'',1)
measure,b,t=string.match(timestr,'(%d+).(%d+).(%d+)')
retval, qn_start, qn_end, timesig_num,timesig_denom, tempo = reaper.TimeMap_GetMeasureInfo(0, measure)
else idx=idx+1 
end
i=i+1
end
for i , v in ipairs(tb_isrgn) do
reaper.AddProjectMarker(0 , tb_isrgn[i] , tb_pos[i]+settime , tb_rgnend[i] , tb_name[i] , tb_markrgnindexnumber[i] )
end
