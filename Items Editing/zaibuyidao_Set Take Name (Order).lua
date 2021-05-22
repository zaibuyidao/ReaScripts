--[[
 * ReaScript Name: Set Take Name (Order)
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

-- 計算數字的位數
function DightNum(num)
  if math.floor(num) ~= num or num < 0 then
    return -1
  elseif 0 == num then
    return 1
  else
    local tmp_dight = 0
    while num > 0 do
      num = math.floor(num/10)
      tmp_dight = tmp_dight + 1
    end
    return tmp_dight 
  end
end
-- 在整數數字前面加0
function AddZeroFrontNum(dest_dight, num)
  local num_dight = DightNum(num)
  if -1 == num_dight then 
    return -1 
  elseif num_dight >= dest_dight then
    return tostring(num)
  else
    local str_e = ""
    for var =1, dest_dight - num_dight do
      str_e = str_e .. "0"
    end
    return str_e .. tostring(num)
  end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
    local name = ""
    local zero_num = "2"
    local retval, retvals_csv = reaper.GetUserInputs('Set Take Name (Order)', 2, 'New Name & Order,Digits,extrawidth=150', name .. "," .. zero_num)
    name, zero_num = retvals_csv:match("(.*),(.*)")
    if not retval or not (tonumber(name) or tostring(name)) or not tonumber(zero_num) then return end
    zero_num = tonumber(zero_num)
    for i = 0, count_sel_items - 1 do
        local begin_num = i + 1
        local add_zero = AddZeroFrontNum(zero_num, begin_num)
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local take_name = reaper.GetTakeName(take)
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', name .. add_zero, true)
    end
  end
reaper.Undo_EndBlock('Set Take Name (Order)', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()