--[[
 * ReaScript Name: Paste Item Length
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
local item_len = getSavedData("CopyItemLength", "Length")
for i = 1, count_sel_items do
  local item = reaper.GetSelectedMediaItem(0, i-1)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len)
end
reaper.Undo_EndBlock("Paste Item Length", -1)