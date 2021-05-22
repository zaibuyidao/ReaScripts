--[[
 * ReaScript Name: Humanize Take Volume
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
  local retval, retvals_csv = reaper.GetUserInputs('Humanize Take Volume', 1, 'Strength dB:', '')
  if not retval or not tonumber(retvals_csv) then return end
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local take_vol = reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL')
    local take_db = 20*log10(take_vol)
    local delta_db = retvals_csv - take_db
    local input = (retvals_csv+1)*2
    -- local rand = math.floor(math.random()*(input-1)-(input/2)) -- 隨機整數
    local rand = math.random()*(input-1)-(input/2)
    rand = rand+1
    local new_db = take_vol*10^(0.05*rand)
    reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL', new_db)
    reaper.UpdateItemInProject(item)
  end
end
reaper.Undo_EndBlock('Humanize Take Volume', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()