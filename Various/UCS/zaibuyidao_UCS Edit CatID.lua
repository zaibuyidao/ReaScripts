-- NoIndex: true

function print(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

local bias = 0.002 -- 補償偏差值
local absolute = false

function Open_URL(url)
  if not OS then local OS = reaper.GetOS() end
  if OS=="OSX32" or OS=="OSX64" then
    os.execute("open ".. url)
  else
    os.execute("start ".. url)
  end
end

if not reaper.BR_Win32_SetFocus then
  local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    Open_URL("http://www.sws-extension.org/download/pre-release/")
  end
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("請右鍵單擊並安裝'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動REAPER並再次運行腳本，謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function str_split(str,delimiter)
  local dLen = string.len(delimiter)
  local newDeli = ''
  for i=1,dLen,1 do
    newDeli = newDeli .. "["..string.sub(delimiter,i,i).."]"
  end

  local locaStart,locaEnd = string.find(str,newDeli)
  local arr = {}
  local n = 1
  while locaStart ~= nil do
    if locaStart>0 then
      arr[n] = string.sub(str,1,locaStart-1)
      n = n + 1
    end

    str = string.sub(str,locaEnd+1,string.len(str))
    locaStart,locaEnd = string.find(str,newDeli)
  end
  if str ~= nil then
    arr[n] = str
  end
  return arr
end

local CatID = reaper.GetExtState("UCSEditCatID", "CatID")
local mode = reaper.GetExtState("UCSEditCatID", "Mode")
if mode == "" then mode = "r-mgr" end

local retval, retvals_csv = reaper.GetUserInputs("UCS Edit CatID", 2, "CatID,Process: r-sel / r-mgr / r-ts / take,extrawidth=100", CatID ..','.. mode)
if not retval then return end
CatID, mode = retvals_csv:match("(.*),(.*)")

reaper.SetExtState("UCSEditCatID", "CatID", CatID, false)
reaper.SetExtState("UCSEditCatID", "Mode", mode, false)
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if mode == "r-sel" then -- Item-Region
  local function get_all_regions()
    local result = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
      if retval ~= nil and isrgn then
        table.insert(result, {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos,
          right = rgnend,
          name = name,
          color = color
        })
      end
    end
    return result
  end
  
  local function get_sel_regions()
    local all_regions = get_all_regions()
    if #all_regions == 0 then return {} end
    local sel_index = {}
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then return {} end
  
    -- 获取item列表
    local items = {}
    for i = 1, item_count do
      local item = reaper.GetSelectedMediaItem(0, i-1)
      if item ~= nil then
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_pos + item_len
        table.insert(items, {left=item_pos,right=item_end} )
      end
    end
  
    -- 合并item
    local merged_items = {}
    table.sort(items, function(a,b)
      return a.left < b.left
    end)
    local cur = {
      left = items[1].left,
      right = items[1].right
    }
    for i,item in ipairs(items) do
      if cur.right - item.left > 0 then -- 确定区域是否为相交
        cur.right = math.max(item.right,cur.right)
      else
        table.insert(merged_items, cur)
        cur = {
          left = item.left,
          right = item.right
        }
      end
    end
    table.insert(merged_items, cur)
  
    -- 标记选中区间
    for _, merged_item in ipairs(merged_items) do
      local l, r = 1, #all_regions
      -- 查找第一个左端点在item左侧的区间
      while l <= r do
        local mid = math.floor((l+r)/2)
        if (all_regions[mid].left - bias) > merged_item.left then
          r = mid - 1
        else 
          l = mid + 1
        end
      end
  
      if absolute then
        if math.abs( (merged_item.right - merged_item.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
          sel_index[r] = true
        end
      else
        if r ~= 0 then
          if merged_item.right <= all_regions[r].right then -- if merged_item.right <= all_regions[r].right + bias then
            sel_index[r] = true
          end
        end
      end
    end
  
    -- 处理结果
    local result = {}
    local indexs = {}
    for k, _ in pairs(sel_index) do table.insert(indexs, k) end
    table.sort(indexs)
    for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end
  
    return result
  end
  
  local function set_region(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
  end

  local sel_regions = get_sel_regions()

  for i,region in ipairs(sel_regions) do
    local origin_name = region.name

    local origin_name_t = str_split(origin_name,'_')
    local split, cat_id
    if #origin_name_t > 1 then
      cat_id = origin_name_t[1] -- CatID 位置
      if string.match(cat_id, '-') then
        split = str_split(cat_id,'-')[1]
      else
        split = cat_id
      end
      region.name = string.gsub(region.name, split, CatID)
    end
    set_region(region)
  end
end

if mode == "r-mgr" then -- Region Manager
  local function GetRegionManager()
    local title = reaper.JS_Localize("Region/Marker Manager", "common")
    local arr = reaper.new_array({}, 1024)
    reaper.JS_Window_ArrayFind(title, true, arr)
    local adr = arr.table()
    for j = 1, #adr do
      local hwnd = reaper.JS_Window_HandleFromAddress(adr[j])
      -- verify window by checking if it also has a specific child.
      if reaper.JS_Window_FindChildByID(hwnd, 1056) then -- 1045:ID of clear button
        return hwnd
      end 
    end
  end

  local hWnd = GetRegionManager()
  if hWnd == nil then return end
  local container = reaper.JS_Window_FindChildByID(hWnd, 1071)
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
  if sel_count == 0 then return end

  if reaper.GetToggleCommandStateEx(0, 40365) == 1 then -- View: Time unit for ruler: Minutes:Seconds
    minutes_seconds_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 40367) == 1 then -- View: Time unit for ruler: Measures.Beats
    meas_beat_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 41916) == 1 then -- View: Time unit for ruler: Measures.Beats (minimal)
    meas_beat_mini_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 40368) == 1 then -- View: Time unit for ruler: Seconds
    seconds_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 40369) == 1 then -- View: Time unit for ruler: Samples
    samples_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 40370) == 1 then -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
    hours_frames_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  if reaper.GetToggleCommandStateEx(0, 41973) == 1 then -- View: Time unit for ruler: Absolute frames
    frames_flag = true
    reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
  end
  
  local function get_all_regions()
    local result = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
      if retval ~= nil and isrgn then
        pos2 = string.sub(string.format("%.10f", pos), 1, -8) -- 截取到小數點3位數
        rgnend2 = string.sub(string.format("%.10f", rgnend), 1, -8) -- 截取到小數點3位數
  
        table.insert(result, {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos2,
          right = rgnend2,
          name = name,
          color = color,
          left_ori = pos,
          right_ori = rgnend
        })
      end
    end
    return result
  end

  local function get_sel_regions()
    local all_regions = get_all_regions()
    if #all_regions == 0 then return {} end
    local sel_index = {}
  
    local rgn_name, rgn_left, rgn_right, mng_regions, cur = {}, {}, {}, {}, {}
    local rgn_selected_bool = false
  
    j = 0
    for index in string.gmatch(sel_indexes, '[^,]+') do
      j = j + 1
      local sel_item = reaper.JS_ListView_GetItemText(container, tonumber(index), 1)
  
      if sel_item:find("R") ~= nil then
        rgn_name[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
        rgn_left[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
        rgn_right[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 4)
  
        cur = {
          regionname = rgn_name[j],
          left = tonumber(rgn_left[j]),
          right = tonumber(rgn_right[j])
        }
      
        table.insert(mng_regions, {
          regionname = cur.regionname,
          left = cur.left,
          right = cur.right
        })
  
        rgn_selected_bool = true
      end
    end
  
    -- 标记选中区域
    for _, merged_rgn in ipairs(mng_regions) do
      local l, r = 1, #all_regions
      -- 查找第一个左端点在左侧的区域
      while l <= r do
        local mid = math.floor((l+r)/2)
        if (all_regions[mid].left - bias) > merged_rgn.left then
          r = mid - 1
        else
          l = mid + 1
        end
      end
      if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
        sel_index[r] = true
      end
  
      -- if merged_rgn.right <= all_regions[r].right + bias then
      --   sel_index[r] = true
      -- end
    end
  
    -- 处理结果
    local result = {}
    local indexs = {}
    for k, _ in pairs(sel_index) do table.insert(indexs, k) end
    table.sort(indexs)
    for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end
  
    return result
  end

  local function set_region(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right_ori, region.name, region.color)
  end

  local sel_regions = get_sel_regions()
  
  if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
  if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
  if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
  if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
  if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
  if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
  if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames

  for i, region in ipairs(sel_regions) do
    local origin_name = region.name
    local origin_name_t = str_split(origin_name,'_')
    local split, cat_id
    if #origin_name_t > 1 then
      cat_id = origin_name_t[1] -- CatID 位置
      if string.match(cat_id, '-') then
        split = str_split(cat_id,'-')[1]
      else
        split = cat_id
      end
      region.name = string.gsub(region.name, split, CatID)
    end
    set_region(region)
  end

  HWND_Region = reaper.JS_Window_Find("Region/Marker Manager",0)
  reaper.BR_Win32_SetFocus(HWND_Region)
end

if mode == "r-ts" then -- Region Within Time Selection
  local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if time_sel_start == time_sel_end then return end

  local function get_all_regions()
    local result = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
      if retval ~= nil and isrgn then
        table.insert(result, {
          index = markrgnindexnumber,
          isrgn = isrgn,
          left = pos,
          right = rgnend,
          name = name,
          color = color
        })
      end
    end
    return result
  end
  
  local function get_sel_regions()
    local all_regions = get_all_regions()
    if #all_regions == 0 then return {} end
    local sel_index = {}
  
    local time_regions = {}
  
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions-1 do
      local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    
      if retval ~= nil and isrgn then
        cur = { left = pos, right = rgnend }
        table.insert(time_regions, cur)
      end
    end
  
    -- 标记选中区域
    for _, merged_rgn in ipairs(time_regions) do
      local l, r = 1, #all_regions
      -- 查找第一个左端点在item左侧的区域
      while l <= r do
        local mid = math.floor((l+r)/2)
  
        if (all_regions[mid].left - bias) > merged_rgn.left then
          r = mid - 1
        else 
          l = mid + 1
        end
      end
  
      if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
        sel_index[r] = true
      end
    end
  
    -- 处理结果
    local result = {}
    local indexs = {}
    for k, _ in pairs(sel_index) do table.insert(indexs, k) end
    table.sort(indexs)
    for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end
  
    return result
  end
  
  local function set_region(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
  end

  local sel_regions = get_sel_regions()

  j = {}
  for i, region in ipairs(sel_regions) do
    if region.left >= time_sel_start then
      if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
        j[#j+1] = i
  
        local origin_name = region.name

        local origin_name_t = str_split(origin_name,'_')
        local split, cat_id
        if #origin_name_t > 1 then
          cat_id = origin_name_t[1] -- CatID 位置
          if string.match(cat_id, '-') then
            split = str_split(cat_id,'-')[1]
          else
            split = cat_id
          end
          region.name = string.gsub(region.name, split, CatID)
        end
        set_region(region)
      end
    end
  end
end

if mode == "take" then -- Item-Take
  local startEvents = {}
  local count_sel_items = reaper.CountSelectedMediaItems(0)
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    local pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local take = reaper.GetActiveTake(item)
    local takeName = reaper.GetTakeName(take)
    if startEvents[startPos] == nil then startEvents[startPos] = {} end
    local event = {
      ["startPos"]=startPos,
      ["pitch"]=pitch,
      ["takeName"]=takeName,
      ["item"]=item
    }
    
    table.insert(startEvents[startPos], event)
  end
  
  local tempEvents = {}
  for i in pairs(startEvents) do
    table.insert(tempEvents,i)  
  end
  table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- 對key進行升序
  
  local result = {}
  for i,v in pairs(tempEvents) do
    table.insert(result,startEvents[v])
  end
  
  j = 0
  for _, list in pairs(result) do
    for i = 1, #list do
      j = j + 1
      track = reaper.GetMediaItem_Track(list[i].item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      parent_track = reaper.GetParentTrack(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end
  
      take = reaper.GetActiveTake(list[i].item)
      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      origin_name = reaper.GetTakeName(take)
  
      local origin_name_t = str_split(origin_name,'_')
      local split, cat_id
      if #origin_name_t > 1 then
        cat_id = origin_name_t[1] -- CatID 位置
        if string.match(cat_id, '-') then
          split = str_split(cat_id,'-')[1]
        else
          split = cat_id
        end
        take_name = string.gsub(take_name, split, CatID)
      end

      reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
  end
end

reaper.Undo_EndBlock('UCS Edit CatID', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()