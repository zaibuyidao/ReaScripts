--[[
 * ReaScript Name: Design Tools (Dynamic Menu)
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.3 (2021-6-6)
  + 加入隨機交換對象(橫向)
 * v1.2 (2021-6-5)
  + 加入複製粘貼item長度
 * v1.1 (2021-5-26)
  + 加入批量重命名
 * v1.0 (2021-5-13)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function UnselectAllTracks()
  first_track = reaper.GetTrack(0, 0)
  reaper.SetOnlyTrackSelected(first_track)
  reaper.SetTrackSelected(first_track, false)
end

local function ShuffleTable( t )
	local rand = math.random 
	local iterations = #t
	local w
	for z = iterations, 2, -1 do
		w = rand(z)
		t[z], t[w] = t[w], t[z]
	end
end

function table.serialize(obj)
  local lua = ""
  local t = type(obj)
  if t == "number" then
    lua = lua .. obj
  elseif t == "boolean" then
    lua = lua .. tostring(obj)
  elseif t == "string" then
    lua = lua .. string.format("%q", obj)
  elseif t == "table" then
    lua = lua .. "{\n"
  for k, v in pairs(obj) do
    lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
  end
  local metatable = getmetatable(obj)
  if metatable ~= nil and type(metatable.__index) == "table" then
    for k, v in pairs(metatable.__index) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
    end
  end
  lua = lua .. "}"
  elseif t == "nil" then
    return nil
  else
    error("can not serialize a " .. t .. " type.")
  end
  return lua
end

function table.unserialize(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = load(lua)
  if func == nil then return nil end
  return func()
end

function getSavedData(key1, key2)
  return table.unserialize(reaper.GetExtState(key1, key2))
end

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

function RegionRGB()
  local R = math.random(255)
  local G = math.random(255)
  local B = math.random(255)
  return R, G, B
end

function RGBHexToDec(R, G, B)
  local red = string.format("%x", R)
  local green = string.format("%x", G)
  local blue = string.format("%x", B)
  if (#red < 2) then red = "0" .. red end
  if (#green < 2) then green = "0" .. green end
  if (#blue < 2) then blue = "0" .. blue end
  local color = "01" .. blue .. green .. red
  return tonumber(color, 16)
end

function RandomMarkerColor()
  local marker_ok, num_markers, num_regions = reaper.CountProjectMarkers(0)
  if marker_ok and (num_markers or num_regions ~= 0) then
    for i = 1, num_markers + num_regions do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i - 1)
      if retval ~= nil then
        local marker = {}
        marker.pos = pos
        marker.name = name
        marker.rgnend = rgnend
        marker.idx = markrgnindexnumber
        marker.color = RGBHexToDec(RegionRGB())
        if isrgn == false then
          reaper.SetProjectMarker3(0, marker.idx, isrgn, marker.pos, marker.pos, marker.name, marker.color)
        end
      end
    end
  end
end

function RandomRegionColor()
  local marker_ok, num_markers, num_regions = reaper.CountProjectMarkers(0)
  if marker_ok and (num_markers or num_regions ~= 0) then
    for i = 1, num_markers + num_regions do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i - 1)
      if retval ~= nil then
        local region = {}
        region.pos = pos
        region.name = name
        region.rgnend = rgnend
        region.idx = markrgnindexnumber
        region.color = RGBHexToDec(RegionRGB())
        if isrgn == true then
          reaper.SetProjectMarker3(0, region.idx, isrgn, region.pos, region.rgnend, region.name, region.color)
        end
      end
    end
  end
end

function RandomRegionAndMarkerColor()
  local marker_ok, num_markers, num_regions = reaper.CountProjectMarkers(0)
  if marker_ok and (num_markers or num_regions ~= 0) then
    for i = 1, num_markers + num_regions do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i - 1)
      if retval ~= nil then
        local region = {}
        region.pos = pos
        region.name = name
        region.rgnend = rgnend
        region.idx = markrgnindexnumber
        region.color = RGBHexToDec(RegionRGB())
        if isrgn == true then
          reaper.SetProjectMarker3(0, region.idx, isrgn, region.pos, region.rgnend, region.name, region.color)
        else
          reaper.SetProjectMarker3(0, region.idx, isrgn, region.pos, region.pos, region.name, region.color)
        end
      end
    end
  end
end

function MultiCut()
  reaper.ClearConsole()
  local cur_pos = reaper.GetCursorPosition()
  local sel_item = reaper.GetSelectedMediaItem(0, 0)
  if sel_item == nil then return end

  local item_start = reaper.GetMediaItemInfo_Value(sel_item, "D_POSITION")
  if cur_pos <= item_start then return end
  local item_len = reaper.GetMediaItemInfo_Value(sel_item, "D_LENGTH")
  local cuts_len = cur_pos-item_start
  local num_cuts = math.floor(item_len/cuts_len)
  
  for i = 0, num_cuts do
    reaper.Main_OnCommand(40012, 0) -- Item: Split items at edit or play cursor
    sel_item = reaper.GetSelectedMediaItem(0, 0)
    item_start = reaper.GetMediaItemInfo_Value(sel_item, "D_POSITION")
    reaper.SetEditCurPos(item_start+cuts_len, 0, 0)
  end
  reaper.SetEditCurPos(cur_pos, 0, 0)
  reaper.SelectAllMediaItems(0, 0)
end

function MultiCut2()
  reaper.ClearConsole()
  local cur_pos = reaper.GetCursorPosition()
  local sel_item = reaper.GetSelectedMediaItem(0, 0)
  if sel_item == nil then return end

  local retval, retvals_csv = reaper.GetUserInputs('均等分割', 1, '長度 秒:', '')
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
end

count_sel_items = reaper.CountSelectedMediaItems(0)

function AddMarkToSnapOffset()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('設置標記', 1, '新標記,extrawidth=150', '')
    if not retval or not (tonumber(retvals_csv) or tostring(retvals_csv)) then return end
    for i = 0, count_sel_items - 1 do
      local color = green
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
      local snap = take_start + item_snap
      reaper.SetTakeMarker(take, -1, retvals_csv, snap, color)
    end
  end
end

function SetTakeName()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('設置名稱', 1, '新名稱,extrawidth=150', '')
    if not retval or not (tonumber(retvals_csv) or tostring(retvals_csv)) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_name = reaper.GetTakeName(take)
      reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', retvals_csv, true)
    end
  end
end

function SetTakeNameOrder()
  if count_sel_items > 0 then
    local name = ""
    local zero_num = "2"
    local retval, retvals_csv = reaper.GetUserInputs('設置名稱', 2, '新名稱+自動排序,位數,extrawidth=150', name .. "," .. zero_num)
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
end

function RandPan()
  if count_sel_items > 0 then
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local rand = math.random() * 2 - 1
      reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetPan()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('設置聲像', 1, '新聲像 %:', '')
    if not retval or not tonumber(retvals_csv) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local rand = retvals_csv/100
      reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetItemVol()
  local log10 = function(x) return math.log(x, 10) end
  if count_sel_items > 0 then
    local retval, new_db = reaper.GetUserInputs("設置對象音量", 1, "新音量 dB:", "")
    if not retval or not tonumber(new_db) then return end
    if retval == true and new_db and tonumber(new_db) then
      for i = 0, count_sel_items-1 do
        local it = reaper.GetSelectedMediaItem(0,i)
        local it_vol = reaper.GetMediaItemInfo_Value(it, 'D_VOL')
        local it_db = 20*log10(it_vol)
        local delta_db = new_db - it_db
        reaper.SetMediaItemInfo_Value(it, 'D_VOL', it_vol*10^(0.05*delta_db))
        reaper.UpdateItemInProject(it)
      end
    end
  end
end

function RandItemVol()
  local log10 = function(x) return math.log(x, 10) end
  if count_sel_items > 0 then
    for i = 0, count_sel_items-1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local item_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
      local rand = math.random() * 1 -- 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB
      reaper.SetMediaItemInfo_Value(item, 'D_VOL', rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetItemRandVol()
  local log10 = function(x) return math.log(x, 10) end
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('音量人性化', 1, '音量幅度 dB:', '')
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
end

function RandVol()
  if count_sel_items > 0 then
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local rand = math.random() * 1 -- 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB
      reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL', rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetVol()
  local log10 = function(x) return math.log(x, 10) end
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('設置音量', 1, '新音量 dB:', '')
    if not retval or not tonumber(retvals_csv) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_vol = reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL')
      local take_db = 20*log10(take_vol)
      local delta_db = retvals_csv - take_db
      reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL', take_vol*10^(0.05*delta_db))
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetTakeRandVol()
  local log10 = function(x) return math.log(x, 10) end
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('音量人性化', 1, '音量幅度 dB:', '')
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
end

function SetTakeRandPan()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('聲像人性化', 1, '聲像幅度 %:', '')
    if not retval or not tonumber(retvals_csv) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local take_pan = reaper.GetMediaItemTakeInfo_Value(take, 'D_PAN')
      local input = (retvals_csv+1)*2
      local rand = math.floor(math.random()*(input-1)-(input/2))
      rand = rand+1
      rand = rand/100
      rand = take_pan+rand
      if rand > 100 then rand = 100 end
      if rand < -100 then rand = -100 end
      reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function RandPitch()
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
end

function SetTakePitch()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('設置音高', 1, '新音高:', '')
    if not retval or not tonumber(retvals_csv) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local pitch = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH')
      reaper.SetMediaItemTakeInfo_Value(take, 'D_PITCH', retvals_csv)
      reaper.UpdateItemInProject(item)
    end
  end
end

function SetTakeRandPitch()
  if count_sel_items > 0 then
    local retval, retvals_csv = reaper.GetUserInputs('音高人性化', 1, '音高幅度 dB:', '')
    if not retval or not tonumber(retvals_csv) then return end
    for i = 0, count_sel_items - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local take = reaper.GetActiveTake(item)
      local pitch = reaper.GetMediaItemTakeInfo_Value(take, 'D_PITCH')
      local input = (retvals_csv+1)*2
      -- local rand = math.floor(math.random()*(input-1)-(input/2))+1 -- 隨機整數
      local rand = (math.random()*(input-1)-(input/2))+1
      if rand > 12 then rand = 12 end
      if rand < -12 then rand = -12 end
      reaper.SetMediaItemTakeInfo_Value(take, 'D_PITCH', pitch+rand)
      reaper.UpdateItemInProject(item)
    end
  end
end

function CopyItemLength()
  local len_t = {}
  count_sel_items = reaper.CountSelectedMediaItems(0)
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  end
  reaper.SetExtState("CopyItemLength", "Length", item_len, false)
end

function PasteItemLength()
  local item_len = getSavedData("CopyItemLength", "Length")
  for i = 1, count_sel_items do
    local item = reaper.GetSelectedMediaItem(0, i-1)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len)
  end
end

function CopyItemPosition()
  local start_t = {}
  count_sel_items = reaper.CountSelectedMediaItems(0)
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    table.insert(start_t, item_start)
  end
  reaper.SetExtState("CopyItemPosition", "Position", table.serialize(start_t), false)
end

function PasteItemPosition()
  local item_pos = getSavedData("CopyItemPosition", "Position")
  local cur_pos = reaper.GetCursorPosition()

  -- local items = reaper.CountSelectedMediaItems()
  -- if items > 1 then return reaper.MB("僅可以復制一個對象", "錯誤", 0) end
  
  reaper.Main_OnCommand(40698, 0) -- Edit: Copy items
  
  for i = 1, #item_pos do
    reaper.SetEditCurPos(item_pos[i], 0, 0)
    -- reaper.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
    reaper.Main_OnCommand(40058, 0) -- Item: Paste items/tracks (old-style handling of hidden tracks)
  end
  reaper.SetEditCurPos(cur_pos, 0, 0)
end

function PasteItemPositionMove()
  local items = reaper.CountSelectedMediaItems()
  local pos = getSavedData("CopyItemPosition", "Position")
  local cur_pos = reaper.GetCursorPosition()
  local t = {}
  for i = 0, items-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    t[#t+1] = item
  end
  
  if #t > #pos then
    return
    reaper.MB("移動對像數量超出範圍", "錯誤", 0)
  end

  for i = 1, #t do
    reaper.SetMediaItemInfo_Value(t[i], 'D_POSITION', pos[i])
  end
  reaper.SetEditCurPos(cur_pos, 0, 0)
end

function ScaleItemVolume()
  local count_item = reaper.CountSelectedMediaItems(0)
  if count_item == 0 then return end

  local item_t, pos = {}, {}
  for i = 0, count_item - 1 do
      item_t[i] = reaper.GetSelectedMediaItem(0, i)
      pos[i] = reaper.GetMediaItemInfo_Value(item_t[i], "D_POSITION")
  end

  local log10 = function(x) return math.log(x, 10) end
  local a = 20*log10(reaper.GetMediaItemInfo_Value(item_t[0], 'D_VOL'))
  local z = 20*log10(reaper.GetMediaItemInfo_Value(item_t[#item_t], 'D_VOL'))
  local n = reaper.GetExtState("ScaleItemVolume", "Toggle")
  if (n == "") then n = "0" end
  local cur_range = tostring(a)..','..tostring(z)..','..tostring(n)
  local retval, userInputsCSV = reaper.GetUserInputs("縮放對象音量", 3, "開始位置 dB,結束位置 dB,切換模式 (0=絕對 1=相對),extrawidth=60", cur_range)
  if not retval then return end
  local begin_db, end_db, toggle = userInputsCSV:match("(.*),(.*),(.*)")
  n = toggle
  reaper.SetExtState("ScaleItemVolume", "Toggle", n, false)
  local offset_0 = (end_db - begin_db) / (pos[#pos] - pos[0])
  local offset_1 = (end_db - begin_db) / count_item
  
  for i = 0, count_item - 1 do
      local item = reaper.GetSelectedMediaItem(0, i)
      local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local item_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
      local item_db = 20*log10(item_vol)
      if toggle == '0' then
          local new_db = (item_pos - pos[0]) * offset_0 + begin_db
          local delta_db = new_db - item_db
          reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
      elseif toggle == '1' then
          local delta_db = begin_db - item_db
          reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
          begin_db = offset_1 + begin_db
          if i == count_item - 1 then -- 補償最後一個數
              delta_db = end_db - item_db
              reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
          end
      end
  end
end

function RandomExchangeItems()
	selected_items_count = reaper.CountSelectedMediaItems(0)
	if selected_items_count >= 2 then
		first_track = reaper.GetTrack(0, 0)
		reaper.SetOnlyTrackSelected(first_track)
		reaper.SetTrackSelected(first_track, false)
	
		selected_items_count = reaper.CountSelectedMediaItems(0)
		
		for i = 0, selected_items_count - 1  do
			item = reaper.GetSelectedMediaItem(0, i)
			track = reaper.GetMediaItem_Track(item)
			reaper.SetTrackSelected(track, true)
		end
	
		selected_tracks_count = reaper.CountSelectedTracks(0)
	
		for i = 0, selected_tracks_count - 1  do
			track = reaper.GetSelectedTrack(0, i) 
			count_items_on_track = reaper.CountTrackMediaItems(track)
			sel_items_on_track = {}
			snap_sel_items_on_track = {}
			snap_sel_items_on_tracks_len = 1 
	
			for j = 0, count_items_on_track - 1  do
				item = reaper.GetTrackMediaItem(track, j)
				if reaper.IsMediaItemSelected(item) == true then
					sel_items_on_track[snap_sel_items_on_tracks_len] = item
					snap_sel_items_on_track[snap_sel_items_on_tracks_len] = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET") + reaper.GetMediaItemInfo_Value(item, "D_POSITION")
					snap_sel_items_on_tracks_len = snap_sel_items_on_tracks_len + 1
				end     
			end
	
			ShuffleTable(snap_sel_items_on_track)
	
			for k = 1, snap_sel_items_on_tracks_len - 1 do
				item = sel_items_on_track[k]
				item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
				item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
	
				reaper.SetMediaItemInfo_Value(item, "D_POSITION", snap_sel_items_on_track[k] - item_snap)
				offset = reaper.GetMediaItemInfo_Value(item, "D_POSITION") - item_pos
				if group_state == 1 then
					group = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
					if group > 0 then
						groups[group].offset = offset
					end
				end
			end
		end
	end
end

-- 勾選狀態，如果狀態為1則勾選。
if reaper.GetToggleCommandStateEx(0, 41051) == 1 then take_reverse = true end

local menu = "" -- #音頻編輯||
menu = menu
.. (normal and "!" or "") .. "片段通道模式: 標準" .. "|"
.. (reverse_stereo and "!" or "") .. "片段通道模式: 反向立體聲(左右互換)" .. "|"
.. (mono and "!" or "") .. "片段通道模式: 單聲道(縮混)" .. "|"
.. (chan_left and "!" or "") .. "片段通道模式: 單聲道(左)" .. "|"
.. (chan_right and "!" or "") .. "片段通道模式: 單聲道(右)" .. "||"

.. (item_vol and "!" or "") .. "設置對象音量" .. "|"
.. (rand_item_vol and "!" or "") .. "隨機對象音量" .. "|"
.. (set_item_rand_vol and "!" or "") .. "音量人性化" .. "|"
.. ">" .. "音量/聲像/音高(片段)" .. "|"
.. (center_vol and "!" or "") .. "設置片段音量" .. "|"
.. (rand_vol and "!" or "") .. "隨機片段音量" .. "|"
.. (set_rand_vol and "!" or "") .. "音量人性化" .. "||"
.. (center_pan and "!" or "") .. "設置片段聲像" .. "|"
.. (rand_pan and "!" or "") .. "隨機片段聲像" .. "|"
.. (set_rand_pan and "!" or "") .. "聲像人性化" .. "||"
.. (set_take_pitch and "!" or "") .. "設置片段音高" .. "|"
.. (rand_pitch and "!" or "") .. "隨機片段音高" .. "|"
.. (set_take_rand_pitch and "!" or "") .. "音高人性化" .. "|"
.. "<" .. "||"

.. (take_mark_snap and "!" or "") .. "在吸附偏移處添加/編輯片段標記" .. "|"
.. (take_mark_pos and "!" or "") .. "在光標處添加/編輯片段標記" .. "|"
.. (clean_take_mark and "!" or "") .. "刪除對像中的片段標記" .. "||"

.. (copy_fx and "!" or "") .. "複製選定對象的FX鏈" .. "|"
.. (paste_fx and "!" or "") .. "粘貼選定對象的FX鏈" .. "|"
.. (remove_fx and "!" or "") .. "移除活動片段的FX鏈" .. "||"

.. (set_take_name and "!" or "") .. "設置片段名稱" .. "|"
.. (batch_rename_take and "!" or "") .. "批量重命名片段" .. "|"
.. (create_region and "!" or "") .. "按片段名稱創建區域" .. "||"

.. (set_region_name and "!" or "") .. "設置區域名稱" .. "|"
.. (batch_rename_region and "!" or "") .. "批量重命名區域" .. "||"

.. (take_reverse and "!" or "") .. "反向活動片段" .. "|"
.. (render_item_new and "!" or "") .. "將對象渲染到新片段(右)" .. "||"

.. (copy_item_pos and "!" or "") .. "複製對象位置" .. "|"
.. (paste_item_pos and "!" or "") .. "粘貼對象位置" .. "|"
.. (paste_item_pos_move and "!" or "") .. "粘貼對象位置(僅移動)" .. "||"
.. (copy_item_len and "!" or "") .. "複製對象長度" .. "|"
.. (paste_item_len and "!" or "") .. "粘貼對象長度" .. "||"

.. (scale_item_vol and "!" or "") .. "對象音量縮放" .. "|"
.. (swap_items_2_tracks and "!" or "") .. "交換兩軌對象" .. "|"
.. (rand_exchange_items and "!" or "") .. "隨機交換對象位置" .. "||"
.. (multi_cut2 and "!" or "") .. "平均分割對象" .. "|"
.. (multi_cut and "!" or "") .. "在光標處平均分割對象" .. "|"

title = "Hidden gfx window for showing the 音頻編輯 Menu showmenu"
gfx.init(title, 0, 0, 0, 0, 0)
local dyn_win = reaper.JS_Window_Find(title, true)
local out = 0
if dyn_win then
  out = 7000
  reaper.JS_Window_Move(dyn_win, -out, -out)
end

out = reaper.GetOS():find("OSX") and 0 or out
gfx.x, gfx.y = gfx.mouse_x-0+out, gfx.mouse_y-0+out -- 可設置彈出菜單時鼠標所處的位置
local selection = gfx.showmenu(menu)
gfx.quit()

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if selection > 0 then
  selection = selection - 0 -- 此處selection值與標題行數關聯，標題佔用一行-1，佔用兩行則-2

  if selection == 1 then reaper.Main_OnCommand(40176, 0) end -- Item properties: Set take channel mode to normal
  if selection == 2 then reaper.Main_OnCommand(40177, 0) end -- Item properties: Set take channel mode to reverse stereo
  if selection == 3 then reaper.Main_OnCommand(40178, 0) end -- SWS: Set all takes channel mode to mono (downmix)
  if selection == 4 then reaper.Main_OnCommand(40179, 0) end -- Item properties: Set take channel mode to mono (left)
  if selection == 5 then reaper.Main_OnCommand(40180, 0) end -- Item properties: Set take channel mode to mono (right)

  -- 設置對象音量
  if selection == 6 then SetItemVol() end
  if selection == 7 then RandItemVol() end
  if selection == 8 then SetItemRandVol() end
  -- 設置片段音量/聲像
  if selection == 9 then SetVol() end
  if selection == 10 then RandVol() end
  if selection == 11 then SetTakeRandVol() end
  if selection == 12 then SetPan() end
  if selection == 13 then RandPan() end
  if selection == 14 then SetTakeRandPan() end
  if selection == 15 then SetTakePitch() end
  if selection == 16 then RandPitch() end
  if selection == 17 then SetTakeRandPitch() end

  -- 吸附偏移
  if selection == 18 then AddMarkToSnapOffset() end
  if selection == 19 then reaper.Main_OnCommand(42385, 0) end -- Item: Add/edit take marker at play position or edit cursor
  if selection == 20 then reaper.Main_OnCommand(42387, 0) end -- Item: Delete all take markers

  -- 複製 粘貼FX
  if selection == 21 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_COPYFXCHAIN1"), 0) end -- SWS/S&M: Copy FX chain from selected item
  if selection == 22 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_S&M_COPYFXCHAIN8"), 0) end -- SWS/S&M: Paste FX chain to selected items
  if selection == 23 then reaper.Main_OnCommand(40640, 0) end -- Item: Remove FX for item take

  -- 設置片段名稱
  if selection == 24 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS330a59e50afdc815f97d12a5e02cf45c596a5282"), 0) end -- Script: zaibuyidao_Set Take Name.lua
  -- 批量重命名片段
  if selection == 25 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSb6ef8409fd708ea9bc92396e7b8d3210b71d6eec"), 0) end -- Script: zaibuyidao_Batch Rename Take.lua
  -- 按片段創建區域
  if selection == 26 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_REGIONSFROMITEMS"), 0) end -- SWS: Create regions from selected items (name by active take)

  if selection == 27 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS72ddd826cdde392952c6a8a735687ffa6599a7fb"), 0) end -- Script: zaibuyidao_Set Region Name.lua
  if selection == 28 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RSa0cfd778eeff4b28569c51bf2d4cad1ccadad689"), 0) end -- Script: zaibuyidao_Batch Rename Region.lua 

  -- 重複激活片段 反向活動片段
  if selection == 29 then reaper.Main_OnCommand(41051, 0) end -- Item properties: Toggle take reverse
  if selection == 30 then
    reaper.Main_OnCommand(41999, 0) -- Item: Render items to new take
    reaper.Main_OnCommand(40643, 0) -- Take: Explode takes of items in order
  end
  if selection == 31 then CopyItemPosition() end
  if selection == 32 then PasteItemPosition() end
  if selection == 33 then PasteItemPositionMove() end
  if selection == 34 then CopyItemLength() end
  if selection == 35 then PasteItemLength() end
  if selection == 36 then ScaleItemVolume() end
  if selection == 37 then reaper.Main_OnCommand(reaper.NamedCommandLookup("_RS3afff51cc0ffcfe7b6797e743c138acefd608692"), 0) end -- Script: zaibuyidao_Swap Items Of Two Tracks.lua 交換兩軌對象
  if selection == 38 then RandomExchangeItems() end
  if selection == 39 then MultiCut2() end
  if selection == 40 then MultiCut() end

end

reaper.Undo_EndBlock('Design Tools (Dynamic Menu)', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)