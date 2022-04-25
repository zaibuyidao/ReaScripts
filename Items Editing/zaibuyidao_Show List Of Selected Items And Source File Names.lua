--[[
 * ReaScript Name: Show List Of Selected Items And Source File Names
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-4-26)
  + Initial release
--]]

local function Msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
end

reaper.PreventUIRefresh(1)
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.ClearConsole()

local startEvents = {}

for i = 0, count_sel_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local track = reaper.GetMediaItem_Track(item)
  local pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
  local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local take = reaper.GetActiveTake(item)
  if not reaper.TakeIsMIDI(take) then
    local takeName = reaper.GetTakeName(take)
    if startEvents[startPos] == nil then startEvents[startPos] = {} end
    local event = {
      ["startPos"]=startPos,
      ["pitch"]=pitch,
      ["takeName"]=takeName,
      ["item"]=item
    }
    
    table.insert(startEvents[startPos], event)
  end
end

local tempEvents = {}
for i in pairs(startEvents) do
  table.insert(tempEvents,i)  
end
table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- 對key進行升序

local result = {}
for i,v in pairs(tempEvents) do
  table.insert(result,startEvents[v])
end

function get_file_name(dir) -- 获取文件名
  local os = reaper.GetOS()
  if os ~= "Win32" and os ~= "Win64" then
    return dir:match('.+/([^/]*%.%w+)$') -- osx
  else
    return dir:match('.+\\([^\\]*%.%w+)$') -- win
  end
end

local taketake = {}
local j = 0
for _, list in pairs(result) do
  for i = 1, #list do
    j = j + 1
    take = reaper.GetActiveTake(list[i].item)
    name = reaper.GetTakeName(take)
    scr = reaper.GetMediaItemTake_Source(take)
    filename_scr = reaper.GetMediaSourceFileName(scr)
    filename = get_file_name(filename_scr)
    table.insert(taketake, {take_name = name, flie_name = filename})
  end
end

k = tostring(#taketake)
k = #k
for i, v in ipairs(taketake) do
  idx = i
  idx = string.format("%0" .. k .. "d", idx)
  Msg('['..idx..'] '..v.take_name..' <--> '..v.flie_name)
end

Msg('')
Msg('Total: '..#taketake)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)