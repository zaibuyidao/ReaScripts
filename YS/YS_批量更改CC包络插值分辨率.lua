--[[
 * ReaScript Name: 批量更改CC包络插值分辨率
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval,get=reaper.GetUserInputs('批量更改CC分辨率',1,'CC数据间隔 Tick:','20')
get=480/get
get=string.format('%d',get)
count=reaper.CountSelectedMediaItems(0)
i=0
  while i<count do 
  item=reaper.GetSelectedMediaItem(0, i)
  retval,str=reaper.GetItemStateChunk(item,'',false)
  str=string.gsub(str,'(CCINTERP) (%d+)','CCINTERP '..get)
  --reaper.ClearConsole()
  --reaper.ShowConsoleMsg(str)
  boolean=reaper.SetItemStateChunk(item, str, true)
  i=i+1
  end

