--[[
 * ReaScript Name: 批量更改MIDI发送通道
 * Version: 1.0
 * Author: YS
 * provides: [main=main] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-29)
  + Initial release
--]]

retval,get=reaper.GetUserInputs('批量更改MIDI 发送通道',1,'MIDI发送通道 0-16 :','1')
if retval then
get=tonumber(get)
if get>=0 and get<17 then
count=reaper.CountSelectedMediaItems(0)
i=0
  while i<count do 
  item=reaper.GetSelectedMediaItem(0, i)
  retval,str=reaper.GetItemStateChunk(item,'',false)
  find=string.find (str, '(OUTCH) (%d+)')
  if find~=nil then 
  if get==0 then 
  str=string.gsub(str,'(OUTCH) (%d+)','')
  else
  str=string.gsub(str,'(OUTCH) (%d+)','OUTCH '..get)
  end
  else
  if get~=0 then
  str=string.gsub(str,'<SOURCE MIDI','<SOURCE MIDI\nOUTCH '..get)
  end
  end
  --reaper.ClearConsole()
  --reaper.ShowConsoleMsg(str)
  boolean=reaper.SetItemStateChunk(item, str, true)
  i=i+1
  end
end
end
