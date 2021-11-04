--[[
 * ReaScript Name: Open FX Panel For Selected Item
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
 * v1.0 (2021-11-4)
  + Initial release
--]]

function Msg(string) reaper.ShowConsoleMsg(tostring(string) .. '\n') end

keep_fx = true        -- true or false -- Keep window open when no item is selected
opened_fx_items = {}  -- 已經打開的fx窗口的item

function forEachSelectedItems(block) -- 遍歷選中item
  local selected_item_count = reaper.CountSelectedMediaItems(0)
  for item_idx = 0, selected_item_count - 1 do
    block(reaper.GetSelectedMediaItem(0, item_idx), item_idx)
  end
end

function forEachSelectedFxItems(block) -- 遍歷帶有fx的選中item
  forEachSelectedItems(function (item, id)
    local take = reaper.GetActiveTake(item)
    if take ~= nil then
      local fx_count = reaper.TakeFX_GetCount(take)
      if fx_count > 0 then
        block(item, id, fx_count)
      end
    end
  end)
end

function countSelectedFxItems()
  local count = 0
  forEachSelectedFxItems(function () count = count + 1 end)
  return count
end

function hasTakeFxOpen(take) -- take是否存在一個打開的fx窗口
  if take == nil then return false end
  local cnt = reaper.TakeFX_GetCount(take)
  for i = 0, cnt - 1 do
    if reaper.TakeFX_GetOpen(take, i) then
      return true
    end
  end
  return false
end

function hasItemFxOpen(item) -- item是否存在一個打開的fx窗口
  local take = reaper.GetActiveTake(item)
  if take ~= nil then
    return hasTakeFxOpen(take)
  end
end

function openItemFx(item)
  if not hasItemFxOpen(item) then
    -- 防止item被刪除
    pcall(function ()
      value = reaper.TakeFX_GetCount(reaper.GetActiveTake(item))
      reaper.TakeFX_SetOpen(reaper.GetActiveTake(item), (value - 1) or 0, true)
    end)
  end
end

function closeOpenedFxItems(cond)
  for item in pairs(opened_fx_items) do
    if cond == nil or cond(item) then
      pcall(function ()
        reaper.TakeFX_SetOpen(reaper.GetActiveTake(item), 0, false)
      end)
    end
  end
end

-- 更新已打開的fx窗口(item)
for item_idx = 0, reaper.CountMediaItems(0) - 1 do
  local item = reaper.GetMediaItem(0, item_idx)
  if hasItemFxOpen(item) then opened_fx_items[item] = true end
end

function main()
    reaper.PreventUIRefresh(1)

    local selected_item_count = countSelectedFxItems()

    if selected_item_count > 0 then
      local selected_items = {}
      -- 打開選中的item fx窗口
      forEachSelectedFxItems(function (item)
        selected_items[item] = true
        openItemFx(item)
      end)
      -- 關閉先前的item fx窗口
      closeOpenedFxItems(function (item)
        return selected_items[item] == nil
      end)
      opened_fx_items = selected_items -- 更新已打開的item fx窗口

    elseif not keep_fx then -- 沒有選中任何項, 並且不保持窗口
      -- 全部關閉
      closeOpenedFxItems()
      opened_fx_items = {}
    end
    -- 沒有選中任何項, 且保持窗口. 不做任何處理

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

main()