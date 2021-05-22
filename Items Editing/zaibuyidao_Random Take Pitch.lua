--[[
 * ReaScript Name: Random Take Pitch
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)
local min = -12
local max = 12
if count_sel_items == 0 then return end
for i = 0, count_sel_items-1 do
  local item = reaper.GetSelectedMediaItem(0,i)
  local take = reaper.GetActiveTake(item)
  local pitch = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH')
  local new_pitch = math.random(min,max)
  if new_pitch ~= pitch then
    reaper.SetMediaItemTakeInfo_Value(take, 'D_PITCH', math.random()*new_pitch)
    reaper.UpdateItemInProject(item)
  end
end
reaper.Undo_EndBlock('Random Take Pitch', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()