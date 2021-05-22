--[[
 * ReaScript Name: Humanize Item Volume
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
local log10 = function(x) return math.log(x, 10) end
if count_sel_items > 0 then
  local retval, retvals_csv = reaper.GetUserInputs('Humanize Item Volume', 1, 'Strength dB:', '')
  if not retval or not tonumber(retvals_csv) then return end
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
    local item_db = 20*log10(item_vol) -- 獲取對象的dB
    local delta_db = retvals_csv - item_db
    local input = (retvals_csv+1)*2
    --local rand = math.floor(math.random()*(input-1)-(input/2)) -- 隨機整數
    local rand = math.random()*(input-1)-(input/2)
    rand = rand+1
    local new_db = item_vol*10^(0.05*rand)
    reaper.SetMediaItemInfo_Value(item, 'D_VOL', new_db)
    reaper.UpdateItemInProject(item)
  end
end
reaper.Undo_EndBlock('Humanize Item Volume', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()