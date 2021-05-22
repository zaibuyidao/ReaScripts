--[[
 * ReaScript Name: Paste Item Position
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
 * v1.0 (2021-5-22)
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

-- local items = reaper.CountSelectedMediaItems()
-- if items > 1 then return reaper.MB("僅可以復制一個對象", "錯誤", 0) end

local item_pos = getSavedData("CopyItemPosition", "Position")
local cur_pos = reaper.GetCursorPosition()

reaper.Main_OnCommand(40698, 0) -- Edit: Copy items

for i = 1, #item_pos do
  reaper.SetEditCurPos(item_pos[i], 0, 0)
  -- reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
  reaper.Main_OnCommand(40058, 0) -- Item: Paste items/tracks (old-style handling of hidden tracks)
end

reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.Undo_EndBlock("Paste Item Position", -1)