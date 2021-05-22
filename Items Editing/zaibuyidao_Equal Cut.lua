--[[
 * ReaScript Name: Equal Cut
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-5-22)
  + Initial release
--]]

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items == 0 then return end

reaper.ClearConsole()
local cur_pos = reaper.GetCursorPosition()
local sel_item = reaper.GetSelectedMediaItem(0, 0)
if sel_item == nil then return end

local retval, retvals_csv = reaper.GetUserInputs('Equal Cut', 1, 'Length (seconds):', '')
if not retval or not tonumber(retvals_csv) then return end

local item_start = reaper.GetMediaItemInfo_Value(sel_item, "D_POSITION")
local item_len = reaper.GetMediaItemInfo_Value(sel_item, "D_LENGTH")
local multi_cut = retvals_csv+item_start
if multi_cut <= item_start then return end

local cuts_len = multi_cut-item_start
local num_cuts = math.floor(item_len/cuts_len)
reaper.SetEditCurPos(multi_cut, 0, 0)

for i = 0, num_cuts do
  reaper.Main_OnCommand(40012, 0) -- Item: Split items at edit or play cursor
  sel_item = reaper.GetSelectedMediaItem(0, 0)
  item_start = reaper.GetMediaItemInfo_Value(sel_item, "D_POSITION")
  reaper.SetEditCurPos(item_start+cuts_len, 0, 0)
end
reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.SelectAllMediaItems(0, 0)
reaper.Undo_EndBlock('Equal Cut', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()