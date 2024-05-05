-- @description Copy Source Filenames of Selected Active Takes to Clipboard
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
table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- key升序

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

function remove_name_suffix(str)
  local idx = str:match(".+()%.%w+$") -- 获取文件后缀
  if idx then 
    str = str:sub(1, idx - 1) 
  end
  return str
end

function to_string_ex(value)
  if type(value)=='table' then
    return table_to_str(value)
  elseif type(value)=='string' then
    return value
  else
    return tostring(value)
  end
end

function table_to_str(t)
  if t == nil then return "" end
  local retstr= ""

  local i = 1
  for key,value in pairs(t) do
    local signal = "" .. '\n'
    if i == 1 then
      signal = ""
    end

    if key == i then
      retstr = retstr .. signal .. to_string_ex(value)
    else
      if type(key) == 'number' or type(key) == 'string' then
        retstr = retstr .. signal .. to_string_ex(remove_name_suffix(value))
      else
        if type(key) == 'userdata' then
            retstr = retstr .. signal .. "*s" .. table_to_str(getmetatable(key)) .. "*e" .. "=" .. to_string_ex(value)
        else
            retstr = retstr .. signal .. key .. "=" .. to_string_ex(value)
        end
      end
    end
    i = i + 1
  end

  retstr = retstr .. ""
  return retstr
end

local taketake = {}
for _, list in pairs(result) do
  for i = 1, #list do
    take = reaper.GetActiveTake(list[i].item)
    name = reaper.GetTakeName(take)
    scr = reaper.GetMediaItemTake_Source(take)
    filename_scr = reaper.GetMediaSourceFileName(scr)
    filename = get_file_name(filename_scr)
    table.insert(taketake, {file_name = filename})
  end
end

copy_take_name = table_to_str(taketake)
reaper.CF_SetClipboard(copy_take_name)
-- Msg(copy_take_name)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)