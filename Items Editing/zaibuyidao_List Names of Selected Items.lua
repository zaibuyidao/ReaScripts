-- @description List Names of Selected Items
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

local tempEvents = {}
for i in pairs(startEvents) do
  table.insert(tempEvents,i)  
end
table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- 對key進行升序

local result = {}
for i,v in pairs(tempEvents) do
  table.insert(result,startEvents[v])
end

local taketake = {}
local j = 0
for _, list in pairs(result) do
  for i = 1, #list do
    j = j + 1
    take = reaper.GetActiveTake(list[i].item)
    name = reaper.GetTakeName(take)
    table.insert(taketake, name)
  end
end

k = tostring(count_sel_items)
k = #k
for i = 0, count_sel_items -1 do
  idx = i + 1
  idx = string.format("%0" .. k .. "d", idx)
  Msg('['..idx..'] '..taketake[i+1])
end
Msg('')
Msg('Total: '..count_sel_items)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)