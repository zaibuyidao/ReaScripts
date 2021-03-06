--[[
 * ReaScript Name: Set Region Name
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-1)
  + Initial release
--]]

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

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

function max(a,b)
  if a>b then
    return a
  end
  return b
end

function create_region(reg_start, reg_end, name)
  if name == nil then return end
  local index = reaper.AddProjectMarker2(0, true, reg_start, reg_end, name, -1, 0)
end

function rename_region(name)
  if name == nil then return end
  reaper.SetProjectMarker3(0, markrgnindexnumber, isrgn, pos, rgnend, name, color)
end

local show_msg = reaper.GetExtState("SetRegionName", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "設置區域名稱"
    text = "v=001 -- Timeline order 時間順序\na=a -- Letter order 字母順序\n"
    text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("SetRegionName", "ShowMsg", show_msg, true)
    end
end

item_count = reaper.CountSelectedMediaItems(0)
if item_count == 0 then return end

local items = {}

for i = 1, reaper.CountSelectedMediaItems(0) do
  local item = reaper.GetSelectedMediaItem(0, i-1)
  if item ~= nil then
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_pos + item_len
    table.insert( items,{ left=item_pos,right=item_end } )
  end
end

if #items <= 0 then return end

table.sort(items,function(a,b)
  return a.left < b.left
end)

local regions = {}
local left_t = {}

local cur = {
  left = items[1].left,
  right = items[1].right
}

for i,item in ipairs(items) do
  if cur.right - item.left > 0 then -- 判定區域是否為相交
    cur.right = max(item.right,cur.right)
  else
    table.insert(regions, cur)
    cur = {
      left = item.left,
      right = item.right
    }
  end
end

table.insert(regions, cur)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local name = reaper.GetExtState("SetRegionName", "Name")
if (name == "") then name = "Region_v=001" end
local tail = reaper.GetExtState("SetRegionName", "Tail")
if (tail == "") then tail = "0" end

local ok, retvals_csv = reaper.GetUserInputs("Set Region Name", 2, "Region name 區域名,Tail 尾部 (ms),extrawidth=200", name .. ',' .. tail)
if not ok or not tonumber(tail) then return end
name, tail = retvals_csv:match("(.*),(.*)")
reaper.SetExtState("SetRegionName", "Name", name, false)
reaper.SetExtState("SetRegionName", "Tail", tail, false)
tail = tail / 1000

for i, region in ipairs(regions) do
  region_name = name

  if string.match(region_name, "v=[%d+]*") ~= nil then -- 長度3
    nbr = string.match(region_name, "v=[%d+]*")
    nbr = string.sub(nbr, 3) -- 截取3
    if tonumber(nbr) then
      region_name = region_name:gsub("v="..nbr, function ()
        nbr = AddZeroFrontNum(string.len(nbr), math.floor(nbr+(i-1)))
        return tostring(nbr)
      end)
    end
  end

  if string.match(region_name, "a=[A-Za-z]*") ~= nil then -- 長度3
    xyz = string.match(region_name, "a=[A-Za-z]*")
    xyz_len = string.len(xyz)
    xyz_pos = string.sub(xyz, 3, 3) -- 截取3

    -- if xyz_len == 3 then
      if string.find(xyz_pos,"(%u)") == 1 then
        letter = string.upper(xyz_pos) -- 大寫
        alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      else
        letter = string.lower(xyz_pos) -- 小寫
        alphabet = 'abcdefghijklmnopqrstuvwxyz'
      end

      local letter_byte = string.char(letter:byte())
      local letter_idx = alphabet:find(letter)
      letter_idx = (letter_idx % #alphabet) + (i-1)
      letter_idx = letter_idx % #alphabet
      if letter_idx == 0 then letter_idx = #alphabet end
      letter_byte = alphabet:sub(letter_idx, letter_idx)

      region_name = region_name:gsub("a=" .. xyz_pos, letter_byte)
    -- end
  end
  
  create_region(region.left, region.right+tail, region_name)
end

reaper.Undo_EndBlock("Set Region Name", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
