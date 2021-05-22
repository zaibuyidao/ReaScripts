--[[
 * ReaScript Name: Paste Item Position (Move Only)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-5-21)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function table.unserialize(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then return nil end
  return func()
end

function getSavedData(key1, key2)
  return table.unserialize(reaper.GetExtState(key1, key2))
end

reaper.Undo_BeginBlock()

local items = reaper.CountSelectedMediaItems()
local pos = getSavedData("CopyItemPosition", "Position")
local cur_pos = reaper.GetCursorPosition()

local t = {}
for i = 0, items-1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  t[#t+1] = item
end

if #t > #pos then
  return
  reaper.MB("移動對像數量超出範圍", "錯誤", 0)
end

for i = 1, #t do
  reaper.SetMediaItemInfo_Value(t[i], 'D_POSITION', pos[i])
end

reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.Undo_EndBlock("Paste Item Position (Move Only)", -1)