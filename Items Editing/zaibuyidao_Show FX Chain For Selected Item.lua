--[[
 * ReaScript Name: Show FX Chain For Selected Item
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
 * v1.0 (2021-10-16)
  + Initial release
--]]

item_keep = false

function Msg(string) reaper.ShowConsoleMsg(tostring(string) .. '\n') end

function updateItemsFx()
  local item_count = reaper.CountMediaItems(0)
  for item_idx = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, item_idx)
    local take = reaper.GetTake(item, 0)
    local chain = reaper.CF_GetTakeFXChain(take)
    value = reaper.CF_EnumSelectedFX(chain, -1)
    if value >= 0 then
      items_fx[item_idx] = value
    end
  end
end

function hasTakeFxOpen(take)
  local cnt = reaper.TakeFX_GetCount(take)
  for i = 0, cnt - 1 do
    if reaper.TakeFX_GetOpen(take, i) then
      return true
    end
  end
  return false
end

items_fx = {}

function main()

  updateItemsFx()

  -- 標記某個item的fx窗口是否已生效(被打開), 如果已生效後續操作將關閉所有item的fx窗口
  local item_processed = false

  -- item 處理
  local item_count = reaper.CountMediaItems(0)
  for item_idx = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, item_idx)
    local take = reaper.GetTake(item, 0)
    take_fx_count = reaper.TakeFX_GetCount(take)
     -- if reaper.IsMediaItemSelected(item) and take_fx_count > 0 then
    if reaper.IsMediaItemSelected(item) then
      item_processed = true
    end
  end

  for item_idx = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, item_idx)
    local take = reaper.GetTake(item, 0)
    take_fx_count = reaper.TakeFX_GetCount(take)
    fx = reaper.TakeFX_GetChainVisible(take)
    if not reaper.IsMediaItemSelected(item) or take_fx_count <= 0 then
      reaper.PreventUIRefresh(1)
      -- if not item_keep or item_processed then
      if not item_keep then
        reaper.TakeFX_SetOpen(take, fx, false)
      end
    else
      if not hasTakeFxOpen(take) then
        reaper.TakeFX_SetOpen(take, items_fx[item_idx] or fx, true)
      end
      reaper.UpdateArrange()
      reaper.PreventUIRefresh(-1)
    end
  end

  reaper.defer(main)
  
end

main()