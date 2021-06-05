--[[
 * ReaScript Name: Copy Item Length
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
 * v1.0 (2021-6-5)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

reaper.Undo_BeginBlock()
local len_t = {}
count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 1 then return end
for i = 0, count_sel_items - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
end
reaper.SetExtState("CopyItemLength", "Length", item_len, false)
reaper.Undo_EndBlock("Copy Item Length", -1)