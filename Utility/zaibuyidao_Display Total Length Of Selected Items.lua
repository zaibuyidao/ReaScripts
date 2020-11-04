--[[
 * ReaScript Name: Display Total Length Of Selected Items
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: X-Raym_Display sum of length of selected media items in the console.lua
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-4)
  + Initial release
--]]

console = true -- true/false: 在控制台中顯示調試消息

local reaper = reaper

function Msg(value)
    if console then reaper.ShowConsoleMsg(tostring(value) .. "\n") end
end

function table_max(t)
  local mn = nil
  for k, v in pairs(t) do
      if (mn == nil) then mn = v end
      if mn < v then mn = v end
  end
  return mn
end

function table_min(t)
  local mn = nil
  for k, v in pairs(t) do
      if (mn == nil) then mn = v end
      if mn > v then mn = v end
  end
  return mn
end

function Main()
  count_sel_items = reaper.CountSelectedMediaItems(0)
  reaper.ClearConsole()

  local len_sum = 0
  local len_pos = 0
  local len_start = {}
  local len_last = {}
  local same_pos = {}

  if count_sel_items > 0 then
    for i = 1, count_sel_items do
      local item = reaper.GetSelectedMediaItem(0, i - 1)
      len_sum = len_sum + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      len_pos = len_pos + reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len_last_item = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      local len_pos_item = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      
      len_start[#len_start + 1] = len_pos_item
      len_last[#len_last + 1] = len_last_item
    end

    far_start_pos = table_max(len_start) -- 最遠的開始位置
    near_start_pos = table_min(len_start) -- 最近的開始位置

    for i = 1, count_sel_items do
      local item = reaper.GetSelectedMediaItem(0, i - 1)
      local len_pos_item = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
       if len_pos_item == far_start_pos then -- 如果item處於最遠的開始位置
        len_new = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        same_pos[#same_pos+1] = len_new
        longest_end = table_max(same_pos)
      end
    end

    local len_total = far_start_pos - near_start_pos + longest_end -- 總長度

    Msg("Number of items selected: ")
    Msg(count_sel_items)
    Msg("")

    Msg("Total length (h:m:s.ms)")
    Msg(reaper.format_timestr(len_total, 5))
    Msg("")

    Msg("Total length sum (h:m:s.ms)")
    Msg(reaper.format_timestr(len_sum, 5))
    Msg("")

    Msg("Average length by item (h:m:s.ms)")
    Msg(reaper.format_timestr(len_sum / count_sel_items, 5))
    Msg("")
  end
end

reaper.defer(Main)
