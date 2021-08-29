--[[
 * ReaScript Name: 右侧减少选区到上一个mark标记
 * Version: 1.0
 * Author: YS
 * provides: [main=main,midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

start, time_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
if start==time_end then return end
retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
countmark=num_markers+num_regions
idx=countmark-1
repeat
retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(idx)
idx=idx-1
until pos<time_end 
if start~=pos then
start, time_end = reaper.GetSet_LoopTimeRange(true, false, start, pos, false)
end
