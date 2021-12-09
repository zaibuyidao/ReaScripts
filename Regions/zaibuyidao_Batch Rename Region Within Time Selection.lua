--[[
 * ReaScript Name: Batch Rename Region Within Time Selection
 * Version: 1.1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-18)
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

function chsize(char)
  if not char then
    return 0
  elseif char > 240 then
    return 4
  elseif char > 225 then
    return 3
  elseif char > 192 then
    return 2
  else
    return 1
  end
end

function utf8len(str)
  local len = 0
  local currentIndex = 1
  while currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    len = len + 1
  end
  return len
end

function utf8sub(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  newChars = utf8len(str) - endChars
  while newChars > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    newChars = newChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8sub2(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  while tonumber(endChars) > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    endChars = endChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8sub_del(str,startChar)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
      local char = string.byte(str,startIndex)
      startIndex = startIndex + chsize(char)
      startChar = startChar - 1
  end
  return str:sub(startIndex)
end

function print(param)
  if type(param) == "table" then
      table.print(param)
      return
  end
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end
function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
      if (print_r_cache[tostring(t)]) then
          print(indent .. "*" .. tostring(t))
      else
          print_r_cache[tostring(t)] = true
          if (type(t) == "table") then
              for pos, val in pairs(t) do
                  if (type(val) == "table") then
                      print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                      sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                      print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                  elseif (type(val) == "string") then
                      print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                  else
                      print(indent .. "[" .. pos .. "] => " .. tostring(val))
                  end
              end
          else
              print(indent .. tostring(t))
          end
      end
  end
  if (type(t) == "table") then
      print(tostring(t) .. " {")
      sub_print_r(t, "  ")
      print("}")
  else
      sub_print_r(t, "  ")
  end
end

function max(a,b)
  if a>b then
    return a
  end
  return b
end

function get_precise_decimal(num, n)
  if type(num) ~= "number" then
    return num
  end
  n = n or 0
  n = math.floor(n)
  if	n < 0 then n = 0 end
  local decimal = 10 ^ n
  local temp = math.floor(num * decimal)
  return temp / decimal
end

function key_of(left, right)
  return tostring(get_precise_decimal(left,10)) .. " " .. tostring(get_precise_decimal(right,10))
end

function collect_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    
    if retval ~= nil then
      if isrgn then
        result[key_of(pos, rgnend)] = {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos,
          right = rgnend,
          name = name,
          color = color
        }
      end
    end
  end
  return result
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

local show_msg = reaper.GetExtState("BatchRenameRegionWithinTimeSelection", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名區域"
    text = "$regionname -- 區域名稱\nv=001 -- Timeline order 時間順序\na=a -- Letter order 字母順序\n"
    text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameRegionWithinTimeSelection", "ShowMsg", show_msg, true)
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
if time_sel_start == time_sel_end then return end

local regions = {}

local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
for i = 0, num_markers + num_regions-1 do
  local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)

  if retval ~= nil then
    if isrgn then
      cur = { left = pos, right = rgnend }
      table.insert(regions, cur)
    end
  end
end

local all_regions = collect_regions()
local pattern, begin_str, end_str, position, insert, delete, find, replace = '', '0', '0', '0', '', '0', '', ''

-- for key,region in pairs(all_regions) do
--   Msg("all:" .. key)
-- end

local ok, retvals_csv = reaper.GetUserInputs("Batch Reanme Region", 8, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", pattern ..','.. begin_str .. ','.. end_str ..','.. position ..','.. insert ..','.. delete ..','.. find ..','.. replace)
if not ok then return end

pattern, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
find = find:gsub('-', '%%-')
find = find:gsub('+', '%%+')

name_t = {}
for i, region in ipairs(regions) do
  local matched = all_regions[key_of(region.left, region.right)]
  if matched then
    name_t[#name_t+1] = matched.name
  end
end

j = {}

for i, region in ipairs(regions) do

  -- Msg("finding:" .. key_of(region.left))
  local matched = all_regions[key_of(region.left, region.right)]

  if region.left >= time_sel_start then
    if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
      j[#j+1] = i
      if matched then
        if pattern ~= "" then
          matched.name = pattern
          matched.name = matched.name:gsub("$regionname", name_t[i])

          if string.match(matched.name, "v=[%d+]*") ~= nil then -- 長度3
            nbr = string.match(matched.name, "v=[%d+]*")
            nbr = string.sub(nbr, 3) -- 截取3
            if tonumber(nbr) then
              matched.name = matched.name:gsub("v="..nbr, function ()
                cnt = AddZeroFrontNum(string.len(nbr), math.floor(nbr + #j - 1))
                return tostring(cnt)
              end)
            end
          end

          if string.match(matched.name, "a=[A-Za-z]*") ~= nil then -- 長度3
            xyz = string.match(matched.name, "a=[A-Za-z]*")
            xyz_len = string.len(xyz)
            xyz_pos = string.sub(xyz, 3, 3) -- 截取3
    
            if string.find(xyz_pos,"(%u)") == 1 then
              letter = string.upper(xyz_pos) -- 大寫
              alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            else
              letter = string.lower(xyz_pos) -- 小寫
              alphabet = 'abcdefghijklmnopqrstuvwxyz'
            end
    
            local letter_byte = string.char(letter:byte())
            local letter_idx = alphabet:find(letter)
            letter_idx = (letter_idx % #alphabet) + #j - 1
            letter_idx = letter_idx % #alphabet
            if letter_idx == 0 then letter_idx = #alphabet end
            letter_byte = alphabet:sub(letter_idx, letter_idx)
  
            matched.name = matched.name:gsub("a=" .. xyz_pos, letter_byte)
          end
        end

        matched.name = utf8sub(matched.name,begin_str,end_str)
        matched.name = utf8sub2(matched.name,0,position)..insert..utf8sub_del(matched.name,position+delete)
        matched.name = string.gsub(matched.name, find, replace)
    
        if insert ~= '' then
          matched.name = matched.name:gsub("$regionname", name_t[i])
  
          if string.match(matched.name, "v=[%d+]*") ~= nil then -- 長度3
            nbr = string.match(matched.name, "v=[%d+]*")
            nbr = string.sub(nbr, 3) -- 截取3
            if tonumber(nbr) then
              matched.name = matched.name:gsub("v="..nbr, function ()
                nbr = AddZeroFrontNum(string.len(nbr), math.floor(nbr + #j - 1))
                return tostring(nbr)
              end)
            end
          end

          if string.match(matched.name, "a=[A-Za-z]*") ~= nil then -- 長度3
            xyz = string.match(matched.name, "a=[A-Za-z]*")
            xyz_len = string.len(xyz)
            xyz_pos = string.sub(xyz, 3, 3) -- 截取3
    
            if string.find(xyz_pos,"(%u)") == 1 then
              letter = string.upper(xyz_pos) -- 大寫
              alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            else
              letter = string.lower(xyz_pos) -- 小寫
              alphabet = 'abcdefghijklmnopqrstuvwxyz'
            end
    
            local letter_byte = string.char(letter:byte())
            local letter_idx = alphabet:find(letter)
            letter_idx = (letter_idx % #alphabet) + #j - 1
            letter_idx = letter_idx % #alphabet
            if letter_idx == 0 then letter_idx = #alphabet end
            letter_byte = alphabet:sub(letter_idx, letter_idx)
  
            matched.name = matched.name:gsub("a=" .. xyz_pos, letter_byte)
          end
        end
    
        set_region(matched)
      end
    end
  end
end

reaper.Undo_EndBlock('Batch Rename Region Within Time Selection', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()