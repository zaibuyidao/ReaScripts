-- NoIndex: true

bias = 0.002

function Msg(param) 
    reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ") 
    end
    reaper.ShowConsoleMsg("\n")
end

KEYS = {
    LEFT_MOUSE = 1,
    RIGHT_MOUSE = 2,
    CONTROL = 4,
    SHIFT = 8,
    ALT = 16,
    WINDOWS = 32,
    MIDDLE_MOUSE = 64
}

LANGS = {
    { id = "en", name = 'English' },
    { id = "zh", name = '简体中文' },
    { id = "tw", name = '正體中文' },
    { id = "ja", name = '日本語' }
}

base_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
    loadfile(reaper.GetResourcePath() .. "/Scripts/zaibuyidao Scripts/Development/Lokasenna_GUI Library/Set Lokasenna_GUI library.lua")()
    loadfile(base_path .. "/lib/utils.lua")()
    loadfile(base_path .. "/lib/ucs.lua")()
    loadfile(base_path .. "/lib/guir.lua")()
else
    loadfile(reaper.GetResourcePath() .. "\\Scripts\\zaibuyidao Scripts\\Development\\Lokasenna_GUI Library\\Set Lokasenna_GUI library.lua")()
    loadfile(base_path .. "\\lib\\utils.lua")()
    loadfile(base_path .. "\\lib\\ucs.lua")()
    loadfile(base_path .. "\\lib\\guir.lua")()
end

local full_usc_data
local cur_usc_data
local current_filter_pattern = ""

if not reaper.APIExists("JS_Localize") then
    reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'. Then restart REAPER and run the script again. Thank you!\n\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動 REAPER 並再次運行腳本。謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, "Error", 0)
    end
    return reaper.defer(function() end)
end

function GetRegionManager()
    local title = reaper.JS_Localize("Region/Marker Manager", "common")
    local arr = reaper.new_array({}, 1024)
    reaper.JS_Window_ArrayFind(title, true, arr)
    local adr = arr.table()
    for j = 1, #adr do
        local hwnd = reaper.JS_Window_HandleFromAddress(adr[j])
        if reaper.JS_Window_FindChildByID(hwnd, 1056) then -- 1045:ID of clear button
            return hwnd
        end 
    end
end

--------------------------------------------- Rename Region Manager ---------------------------------------------

function get_all_regions()
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

function get_sel_regions()
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
    end
  
    -- 处理结果
    local result = {}
    local indexs = {}
    for k, _ in pairs(sel_index) do table.insert(indexs, k) end
    table.sort(indexs)
    for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end
  
    return result
end

function set_region(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right_ori, region.name, region.color)
end

--[[
text = "$regionname: Region name 區域名稱
v=01: Region count 區域計數
v=01-05 or v=05-01: Loop region count 循環區域計數
a=a: Letter count 字母計數
a=a-e or a=e-a: Loop letter count 循環字母計數
]]

-- 默認使用標尺的時間單位:秒
function set_sel_regions()
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
      
    local sel_regions = get_sel_regions()
      
    if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
    if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
    if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
    if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
    if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
    if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
    if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames
    return sel_regions
end

function build_name_region(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("$regionname", origin_name)

    if reverse then
        build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
            local len = #start_idx
            start_idx = tonumber(start_idx)
            end_idx = tonumber(end_idx)
            if start_idx > end_idx then
                return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
            end
            return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)
  
    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)

    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")
  
    if reverse then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
        
        build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)
  
    return build_pattern
end

function rename_region(pattern)
    hWnd_region_mang = GetRegionManager()
    if hWnd_region_mang == nil then return end
    container = reaper.JS_Window_FindChildByID(hWnd_region_mang, 1071)
    sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
    if sel_count == 0 then return end

    for i,region in ipairs(set_sel_regions()) do
        local origin_name = region.name
        if pattern ~= "" then -- 重命名
            region.name = build_name_region(pattern, origin_name, i)
        end
        set_region(region)
    end
end


--------------------------------------------- Rename Region Time Selection ---------------------------------------------

function get_all_regions_time()
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
  
function get_sel_regions_time()
    local all_regions = get_all_regions_time()
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
  
function set_region_time(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

--[[
text = "$regionname: Region name 區域名稱
v=01: Region count 區域計數
v=01-05 or v=05-01: Loop region count 循環區域計數
a=a: Letter count 字母計數
a=a-e or a=e-a: Loop letter count 循環字母計數
]]

function build_name_region_time(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("$regionname", origin_name)

    if reverse == "1" then
      build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
        local len = #start_idx
        start_idx = tonumber(start_idx)
        end_idx = tonumber(end_idx)
        if start_idx > end_idx then
            return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
        end
        return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
      end)
    end

    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)

    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)
    
    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")
  
    if reverse == "1" then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
              return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    
        build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
              return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end

    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)
  
    return build_pattern
end

function rename_region_time(pattern)
    local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if time_sel_start == time_sel_end then return end
    
    j = {}
    for i,region in ipairs(get_sel_regions_time()) do
        if region.left >= time_sel_start then
            if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
                j[#j+1] = i
                local origin_name = region.name
                if pattern ~= "" then -- 重命名
                    region.name = build_name_region_time(pattern, origin_name, #j)
                end
                set_region_time(region)
            end
        end
    end
end

--------------------------------------------- Rename Marker Manager ---------------------------------------------

function get_all_markers()
    local result = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        if retval ~= nil and not isrgn then
            pos2 = string.sub(string.format("%.10f", pos), 1, -8) -- 截取到小數點3位數
            rgnend2 = string.sub(string.format("%.10f", rgnend), 1, -8) -- 截取到小數點3位數
      
            table.insert(result, {
                index = markrgnindexnumber,
                isrgn = isrgn,
                left = pos2,
                right = rgnend2,
                name = name,
                color = color,
                left_ori = pos
            })
        end
    end
    return result
end

function get_sel_markers()
    local all_markers = get_all_markers()
    if #all_markers == 0 then return {} end
    local sel_index = {}
  
    local rgn_name, rgn_left, mng_markers, cur = {}, {}, {}, {}
    local mrk_selected_bool = false
  
    j = 0
    for index in string.gmatch(sel_indexes, '[^,]+') do
        j = j + 1
        local sel_item = reaper.JS_ListView_GetItemText(container, tonumber(index), 1)
    
        if sel_item:find("M") ~= nil then
            rgn_name[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
            rgn_left[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
      
            cur = {
                regionname = rgn_name[j],
                left = tonumber(rgn_left[j]),
            }
          
            table.insert(mng_markers, {
                regionname = cur.regionname,
                left = cur.left
            })
      
            mrk_selected_bool = true
        end
    end
  
    -- 标记选中区域
    for _, merged_rgn in ipairs(mng_markers) do
        local l, r = 1, #all_markers
        -- 查找第一个左端点在左侧的区域
        while l <= r do
            local mid = math.floor((l+r)/2)
            if (all_markers[mid].left - bias) > merged_rgn.left then
                r = mid - 1
            else
                l = mid + 1
            end
        end
        -- if math.abs( (merged_rgn.right - merged_rgn.left) - (all_markers[r].right - all_markers[r].left) ) <= bias * 2 then
        --   sel_index[r] = true
        -- end
    
        if merged_rgn.left <= all_markers[r].left + bias then
            sel_index[r] = true
        end
    end
  
    -- 处理结果
    local result = {}
    local indexs = {}
    for k, _ in pairs(sel_index) do table.insert(indexs, k) end
    table.sort(indexs)
    for _, v in ipairs(indexs) do table.insert(result, all_markers[v]) end
  
    return result
end

function set_marker(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right, region.name, region.color)
end
  
--[[
text = "$markername: Marker name 標記名稱
v=01: Marker count 標記計數
v=01-05 or v=05-01: Loop marker count 循環標記計數
a=a: Letter count 字母計數
a=a-e or a=e-a: Loop letter count 循環字母計數
]]

-- 默認使用標尺的時間單位:秒
function set_sel_markers()
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

    local sel_markers = get_sel_markers()
      
    if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
    if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
    if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
    if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
    if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
    if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
    if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames
    return sel_markers
end

function build_name_marker(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("$regionname", origin_name)

    if reverse then
        build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
            local len = #start_idx
            start_idx = tonumber(start_idx)
            end_idx = tonumber(end_idx)
            if start_idx > end_idx then
                return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
            end
            return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)
  
    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)

    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")
  
    if reverse then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
          end)
        
          build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)
  
    return build_pattern
end

function rename_marker(pattern)
    hWnd_region_mang = GetRegionManager()
    if hWnd_region_mang == nil then return end
    container = reaper.JS_Window_FindChildByID(hWnd_region_mang, 1071)
    sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
    if sel_count == 0 then return end

    for i,region in ipairs(set_sel_markers()) do
        local origin_name = region.name
    
        if pattern ~= "" then -- 重命名
            region.name = build_name_marker(pattern, origin_name, i)
        end
        set_marker(region)
    end
end

--------------------------------------------- Rename Take ---------------------------------------------

--[[
text = "$takename: 片段名稱
$trackname: 軌道名稱
$foldername: 文件夾名稱
$tracknum: 軌道編號
$takeguid: Take guid
v=01: Take count 片段計數
v=01-05 or v=05-01: Loop take count 循環片段計數
a=a: Letter count 字母計數
a=a-e or a=e-a: Loop letter count 循環字母範圍
]]

-- function get_random(n)
--     local t = {
--         "0","1","2","3","4","5","6","7","8","9",
--         "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
--         "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
--     }
--     local s = ""
--     for i = 1, n do
--         s = s .. t[math.random(#t)]
--     end
--     return s
-- end

function build_name_take(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("%$takename", origin_name)
    build_pattern = build_pattern:gsub('%$trackname', track_name)
    build_pattern = build_pattern:gsub('%$tracknum', track_num)
    build_pattern = build_pattern:gsub('%$takeguid', take_guid)
    build_pattern = build_pattern:gsub('%$foldername', parent_buf)

    if reverse then
        build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
            local len = #start_idx
            start_idx = tonumber(start_idx)
            end_idx = tonumber(end_idx)
            if start_idx > end_idx then
                return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
            end
            return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
        end)
    end

    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)

    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)

    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")

    if reverse then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
      
        build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)

    return build_pattern
end

function rename_take(pattern, order)
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items < 0 then return end

    if order == 1 then
        local track_items = {}

        for i = 0, count_sel_items - 1  do
            local item = reaper.GetSelectedMediaItem(0, i)
            local track = reaper.GetMediaItem_Track(item)
            if not track_items[track] then track_items[track] = {} end
            table.insert(track_items[track], item)
        end
        
        for _, items in pairs(track_items) do
            for i, item in ipairs(items) do
                take = reaper.GetActiveTake(item)
                track = reaper.GetMediaItem_Track(item)
                track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
                track_num = string.format("%0" .. 2 .. "d", track_num)
                _, track_name = reaper.GetTrackName(track)
                parent_track = reaper.GetParentTrack(track)
                if parent_track ~= nil then
                    _, parent_buf = reaper.GetTrackName(parent_track)
                else
                    parent_buf = ''
                end
          
                take_guid = reaper.BR_GetMediaItemTakeGUID(take)
                origin_name = reaper.GetTakeName(take)
                take_name = build_name_take(pattern, origin_name, i)
                reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
              end
        end
    elseif order == 2 then
        for z = 0, count_sel_items - 1 do -- 按換行順序排序
            item = reaper.GetSelectedMediaItem(0, z)
            track = reaper.GetMediaItem_Track(item)
            track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
            track_num = string.format("%0" .. 2 .. "d", track_num)
            _, track_name = reaper.GetTrackName(track)
            parent_track = reaper.GetParentTrack(track)
            if parent_track ~= nil then
                _, parent_buf = reaper.GetTrackName(parent_track)
            else
                parent_buf = ''
            end

            take = reaper.GetActiveTake(item)
            take_name = reaper.GetTakeName(take)
            take_guid = reaper.BR_GetMediaItemTakeGUID(take)
            origin_name = reaper.GetTakeName(take)
        
            take_name = build_name_take(pattern, origin_name, z + 1)
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
        end
    elseif order == 3 then -- 按時間綫順序排序
        local startEvents = {}
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
        
                take_name = build_name_take(pattern, origin_name, j)
                reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
            end
        end
    end
end

--------------------------------------------- Rename Track ---------------------------------------------

--[[
text = "$trackname: 軌道名稱
$foldername: 文件夾名稱
$tracknum: 軌道編號
$trackguid: Track guid
v=01: Track count 軌道計數
v=01-05 or v=05-01: Loop track count 循環軌道計數
a=a: Letter count 字母順序
a=a-e or a=e-a: Loop letter count 循環字母計數
]]

function build_name_track(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("%$trackname", origin_name)
    build_pattern = build_pattern:gsub('%$tracknum', track_num)
    build_pattern = build_pattern:gsub('%$trackguid', track_guid)
    build_pattern = build_pattern:gsub('%$foldername', parent_buf)
  
    if reverse == "1" then
        build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
            local len = #start_idx
            start_idx = tonumber(start_idx)
            end_idx = tonumber(end_idx)
            if start_idx > end_idx then
                return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
            end
            return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)
  
    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)

    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")
  
    if reverse == "1" then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
        
        build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end

    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)
    
    return build_pattern
end

function rename_track(pattern)
    count_sel_tracks = reaper.CountSelectedTracks(0)
    if count_sel_tracks == 0 then return end

    for i = 0, count_sel_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', "", false)
      
        parent_track = reaper.GetParentTrack(track)
        track_guid = reaper.BR_GetMediaTrackGUID(track)
        track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        track_num = string.format("%0" .. 2 .. "d", track_num)
      
        if parent_track ~= nil then
            _, parent_buf = reaper.GetTrackName(parent_track)
        else
            parent_buf = ''
        end
      
        local origin_name = track_name
      
        if pattern ~= "" then
            track_name = build_name_track(pattern, origin_name, i + 1)
        end
      
        reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)
    end
end

--------------------------------------------- Rename Marker Time Selection ---------------------------------------------

function get_all_markers_time()
    local result = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        if retval ~= nil and not isrgn then
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
  
function get_sel_markers_time()
    local all_regions = get_all_markers_time()
    if #all_regions == 0 then return {} end
    local sel_index = {}
  
    local time_regions = {}
  
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    for i = 0, num_markers + num_regions-1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    
        if retval ~= nil and not isrgn then
            cur = { left = pos }
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
    
        -- if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
        --   sel_index[r] = true
        -- end
    
        if merged_rgn.left <= all_regions[r].left + bias then
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
  
function set_marker_time(region)
    reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

--[[
text = "$markername: Marker name 標記名稱
v=01: Marker count 標記計數
v=01-05 or v=05-01: Loop marker count 循環標記計數
a=a: Letter count 字母計數
a=a-e or a=e-a: Loop letter count 循環字母計數
]]

function build_name_marker_time(build_pattern, origin_name, i)
    build_pattern = build_pattern:gsub("$regionname", origin_name)
  
    if reverse == "1" then
        build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
            local len = #start_idx
            start_idx = tonumber(start_idx)
            end_idx = tonumber(end_idx)
            if start_idx > end_idx then
                return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
            end
            return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
        return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
    end)
  
    build_pattern = build_pattern:gsub("r=(%d+)", function (n)
        local t = {
            "0","1","2","3","4","5","6","7","8","9",
            "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        }
        local s = ""
        for i = 1, n do
            s = s .. t[math.random(#t)]
        end
        return s
    end)

    local ab = string.byte("a")
    local zb = string.byte("z")
    local Ab = string.byte("A")
    local Zb = string.byte("Z")
  
    if reverse == "1" then
        build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
        
        build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
            local c1b = c1:byte()
            local c2b = c2:byte()
            if c1b > c2b then
                return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
            end
            return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
        end)
    end
  
    build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
        local cb = c:byte()
        if cb >= ab and cb <= zb then
            return string.char(ab + ((cb - ab) + (i - 1)) % 26)
        elseif cb >= Ab and cb <= Zb then
            return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
        end
    end)
  
    return build_pattern
end

function rename_marker_time(pattern)
    local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if time_sel_start == time_sel_end then return end
    
    j = {}
    for i, region in ipairs(get_sel_markers_time()) do
        if region.left >= time_sel_start then
            if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
                j[#j+1] = i
                local origin_name = region.name
                if pattern ~= "" then -- 重命名
                    region.name = build_name_marker_time(pattern, origin_name, #j)
                end
                set_marker_time(region)
            end
        end
    end
end

--------------------------------------------- UCS Rename Start ---------------------------------------------

function should_load_system_usc_data()
    return GUI.elms.check_cat:val()[3] == true
end

function should_load_user_usc_data()
    return GUI.elms.check_cat:val()[4] == true
end

function is_cat_id_enable() -- 启用CatID
    return GUI.elms.check_cat:val()[1] == true
end

function is_cat_short_enable() -- 启用CatShort
    return GUI.elms.check_cat:val()[2] == true
end

function is_loop_count_enable() -- 启用Loop count
    return GUI.elms.check_cat:val()[5] == true
end

function reload_usc_data()
    full_usc_data = {}
    if should_load_system_usc_data() then
        usc.read_from_csv(base_path .. "UCS_list.csv", full_usc_data)
    end
    if should_load_user_usc_data() then
        usc.read_from_csv(base_path .. "UCS_list_custom.csv", full_usc_data)
    end
end

function is_key_active(key)
    if GUI.mouse.cap & key == key then return true end
    return false
end

function switch_lang(index) -- 切换语言
    GUI.elms.menu_lang:val(index)
    local optarray = table.map(LANGS, function (item) return item.name end)
    optarray[GUI.elms.menu_lang:val()] = "!" .. optarray[GUI.elms.menu_lang:val()]
    GUI.elms.menu_lang.optarray = optarray
end

-- function switch_wildcard(index) -- 切换通配符
--     GUI.elms.menu_wild:val(index)
--     local optarray = GUI.elms.menu_wild.optarray[GUI.elms.menu_wild:val()]
--     optarray[GUI.elms.menu_wild:val()] = "!" .. optarray[GUI.elms.menu_wild:val()]
--     GUI.elms.menu_wild.optarray = optarray
-- end

function copy_text(text)  -- 复制关键词
    if text == '' then return end
    reaper.CF_SetClipboard(text)
end

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end
    reaper.JS_Window_SetTitle(search, text)

    if os ~= "Win32" and os ~= "Win64" then
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    else
        -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
        reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x0020, 0, 0, 0) -- 空格
        reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x0008, 0, 0, 0) -- 退格
    end
end

seperators = {
    {name = "Underline", value = "_"},
    {name = "Pyphen", value = "-"},
    {name = "Blank", value = " "},
    {name = "None", value = ""}
}

GUI.elms.radio_connect.optarray = table.map(seperators, function (item) return item.name end)

function get_seperator()
    return seperators[GUI.elms.radio_connect:val()].value
end

function is_sep(sep)
    for _, seperator in ipairs(seperators) do
        if sep == seperator.value then
            return true
        end
    end
end

function append_search(text)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = get_seperator()
    local result = orig
    if not is_sep(orig:sub(#orig, #orig)) and #orig > 0 then
        result = result .. sep
    end
    result = result .. text
    et:val(result)
    et.caret = et:carettoend()
    et:redraw()
end

function prepend_cat_id(cat_id)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = get_seperator()
    local result = orig
    -- 存在cat_id前缀，先删除前缀
    if et.cat_id and et.cat_id == orig:sub(1, #et.cat_id) then
        result = result:sub(#et.cat_id + 1, #orig)
    end
    -- 如果剩余内容不为空，并且开头不是分隔符，则先附加分隔符
    if #result > 0 and not is_sep(result:sub(1, 1)) then
        result = sep .. result
    end
    result = cat_id .. result
    et:val(result)
    et.cat_id = cat_id
end

function append_search_underline(text)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = "_"
    local result = orig
    if not is_sep(orig:sub(#orig, #orig)) and #orig > 0 then
        result = result .. sep
    end
    result = result .. text
    et:val(result)
    et.caret = et:carettoend()
    et:redraw()
end

function append_search_hyphen(text)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = "-"
    local result = orig
    if not is_sep(orig:sub(#orig, #orig)) and #orig > 0 then
        result = result .. sep
    end
    result = result .. text
    et:val(result)
    et.caret = et:carettoend()
    et:redraw()
end

function append_search_blank(text)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = " "
    local result = orig
    if not is_sep(orig:sub(#orig, #orig)) and #orig > 0 then
        result = result .. sep
    end
    result = result .. text
    et:val(result)
    et.caret = et:carettoend()
    et:redraw()
end

function append_search_none(text)
    local et = GUI.elms.edittext_search
    local orig = et:val()
    local sep = ""
    local result = orig
    if not is_sep(orig:sub(#orig, #orig)) and #orig > 0 then
        result = result .. sep
    end
    result = result .. text
    et:val(result)
    et.caret = et:carettoend()
    et:redraw()
end

-- function append_search(text)
--     local orig = GUI.elms.edittext_search:val()
--     local append_pre = ""
    
--     local connect = GUI.elms.radio_connect.optarray[GUI.elms.radio_connect:val()]
--     local append_after = ""
--     if connect == "Default" then
--         if #orig > 0 then append_pre = "_" end
--     elseif connect == "Hyphen" then
--         if #orig > 0 then append_pre = "-" end
--     elseif connect == "Space" then
--         if #orig > 0 then append_pre = " " end
--     elseif connect == "None" then
--         if #orig > 0 then append_pre = "" end
--     else
--         append_after = connect .. " " .. text
--     end
--     GUI.elms.edittext_search:val(orig .. append_pre .. text) -- 文本
--     GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
--     GUI.elms.edittext_search:redraw()
-- end

function filter_pattern_match(text, pattern)
    -- 大小写敏感
    -- text:find(pattern)
    return text:lower():find(pattern:lower())
end

function filter(data, pattern)
    if not pattern or #pattern == 0 then return data end

    local result = {}
    local locale = get_locale()
    for _, category in ipairs(data) do
        if filter_pattern_match(category.name:get(locale), pattern) then
            table.insert(result, category)
            goto continue_category
        end
        local new_children = {}

        for _, child in ipairs(category.children) do
            if filter_pattern_match(child.name:get(locale) .. " [" .. child.cat_id .. "]", pattern) then
                table.insert(new_children, child)
                goto continue_subcategory
            end
            local new_synonym_indexs = {}

            for i, syn in ipairs(child.synonyms:get(locale)) do
                if filter_pattern_match(syn, pattern) then 
                    table.insert(new_synonym_indexs, i) 
                end
            end
            
            if #new_synonym_indexs == 0 then goto continue_subcategory end

            local new_synonym = LocaleData {}
            for lc, syns in pairs(child.synonyms) do
                new_synonym[lc] = {}
                for _, idx in ipairs(new_synonym_indexs) do
                    table.insert(new_synonym[lc], syns[idx])
                end
            end

            table.insert(new_children, { 
                name = child.name,
                cat_id = child.cat_id,
                synonyms = new_synonym
            })
            
            ::continue_subcategory::
        end

        if #new_children > 0 then
            table.insert(result, { name = category.name, children = new_children })
        end

        ::continue_category::
    end

    return result
end

function get_locale()
    return LANGS[GUI.elms.menu_lang:val()].id
end

function renaming()
    reaper.Undo_BeginBlock()
    if is_loop_count_enable() then
        reverse = true
        if process == "Region mgr" then
            rename_region(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Region time" then
            rename_region_time(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Marker mgr" then
            rename_marker(GUI.elms.edittext_search:val()) -- 重命名标记
        elseif process == "Marker time" then
            rename_marker_time(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Take" then
            order = GUI.elms.radio_order:val()
            if take_order == "Track" then
                rename_take(GUI.elms.edittext_search:val(), order) -- 重命名Take
            elseif take_order == "Wrap" then
                rename_take(GUI.elms.edittext_search:val(), order)
            elseif take_order == "Timeline" then
                rename_take(GUI.elms.edittext_search:val(), order)
            end
        elseif process == "Track" then
            rename_track(GUI.elms.edittext_search:val()) -- 重命名轨道
        end

    else
        reverse = false
        if process == "Region mgr" then
            rename_region(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Region time" then
            rename_region_time(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Marker mgr" then
            rename_marker(GUI.elms.edittext_search:val()) -- 重命名标记
        elseif process == "Marker time" then
            rename_marker_time(GUI.elms.edittext_search:val()) -- 重命名区域
        elseif process == "Take" then
            order = GUI.elms.radio_order:val()
            if take_order == "Track" then
                rename_take(GUI.elms.edittext_search:val(), order) -- 重命名Take
            elseif take_order == "Wrap" then
                rename_take(GUI.elms.edittext_search:val(), order)
            elseif take_order == "Timeline" then
                rename_take(GUI.elms.edittext_search:val(), order)
            end
        elseif process == "Track" then
            rename_track(GUI.elms.edittext_search:val()) -- 重命名轨道
        end
    end
    if GUI.elms.edittext_filter.focus == true then GUI.elms.edittext_filter.focus = false end
    GUI.elms.edittext_search.focus = true
    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    reaper.Undo_EndBlock('', -1)
end

GUI.elms.edittext_search._onmousedown = GUI.elms.edittext_search.onmousedown
GUI.elms.edittext_filter._onmousedown = GUI.elms.edittext_filter.onmousedown

function display_usc_data(data)
    
    local orig_list_category_val = GUI.elms.list_category:val()
    local orig_list_subcategory_val = GUI.elms.list_subcategory:val()
    local orig_list_synonym_val = GUI.elms.list_synonym:val()

    function update_category(category_index)
        local locale = get_locale()
        if is_cat_short_enable() then
            GUI.elms.list_category.list = table.map(data, function(item)
                return item.name:get(locale) .. "  [" .. item.name.cat_short .. "]"
            end)
        else
            GUI.elms.list_category.list = table.map(data, function(item)
                return item.name:get(locale)
            end)
        end
        GUI.elms.list_category.name_list = table.map(data, function(item)
            return item.name:get(locale)
        end)
        GUI.elms.list_category.cat_short_list = table.map(data, function(item)
            return item.name.cat_short
        end)
        GUI.elms.list_category.cat_egory_list = table.map(data, function(item)
            return item.name.cat_egory
        end)
        GUI.elms.list_category.category_en_list = table.map(data, function(item) -- 强制启用英文主分类列表
            return item.name.en
        end)
        if category_index and category_index >= 1 and category_index <= #GUI.elms.list_category.list then
            GUI.elms.list_category:val(category_index)
        else
            GUI.elms.list_category:val(1)
        end
        GUI.elms.list_category:redraw()
    end

    function update_subcategory(category_index, subcategory_index)
        if #data < 1 or category_index == nil or category_index < 1 or category_index > #data then
            GUI.elms.list_subcategory.list = {}
            GUI.elms.list_subcategory:redraw()
            return
        end
        local locale = get_locale()
        if is_cat_id_enable() then
            GUI.elms.list_subcategory.list = table.map(data[category_index].children, function (item)
                return item.name:get(locale) .. "  [" .. item.cat_id .. "]"
            end)
        else
            GUI.elms.list_subcategory.list = table.map(data[category_index].children, function (item)
                return item.name:get(locale)
            end)
        end
        GUI.elms.list_subcategory.name_list = table.map(data[category_index].children, function (item)
            return item.name:get(locale)
        end)
        GUI.elms.list_subcategory.cat_list = table.map(data[category_index].children, function (item)
            return item.cat_id
        end)
        GUI.elms.list_subcategory.subcategory_en_list = table.map(data[category_index].children, function (item) -- 强制启用英文子分类列表
            return item.name.en
        end)
        if subcategory_index and subcategory_index >= 1 and subcategory_index <= #GUI.elms.list_subcategory.list then
            GUI.elms.list_subcategory:val(subcategory_index)
        else
            GUI.elms.list_subcategory:val(1)
        end
        GUI.elms.list_subcategory:redraw()
    end

    function update_synonym(category_index, subcategory_index, synonym_index)
        if  #data < 1 
            or category_index == nil 
            or category_index < 1 
            or category_index > #data 
            or #data[category_index].children < 1
            or subcategory_index == nil or subcategory_index < 1 or subcategory_index > #data[category_index].children
        then
            GUI.elms.list_synonym.list = {}
            GUI.elms.list_synonym:redraw()
            return
        end

        local locale = get_locale()
        GUI.elms.list_synonym.list = data[category_index].children[subcategory_index].synonyms:get(locale)
        GUI.elms.list_synonym.synonyms_en_list = data[category_index].children[subcategory_index].synonyms.en -- 强制启用英文同义词列表
        if synonym_index and synonym_index >= 1 and synonym_index <= #GUI.elms.list_synonym.list then
            GUI.elms.list_synonym:val(synonym_index)
        else
            GUI.elms.list_synonym:val(1)
        end
        GUI.elms.list_synonym:redraw()
    end

    update_category(orig_list_category_val)
    update_subcategory(GUI.elms.list_category:val(), orig_list_subcategory_val)
    update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), orig_list_synonym_val)

    function GUI.elms.list_category:ondoubleclick()
        if is_cat_short_enable() then
            if is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) then
                append_search(self.name_list[self:val()])
            elseif is_key_active(KEYS.SHIFT) then
                if not is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search(self.cat_egory_list[self:val()])
                elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search_hyphen(self.cat_egory_list[self:val()])
                end
                if is_key_active(KEYS.ALT) then
                    append_search_none(self.cat_egory_list[self:val()])
                end
            elseif is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) and not is_key_active(KEYS.CONTROL) then
                append_search(self.cat_short_list[self:val()])
            else
                append_search(self.cat_short_list[self:val()])
            end
        else
            if is_key_active(KEYS.SHIFT) then
                if not is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search(self.cat_egory_list[self:val()])
                elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search_hyphen(self.cat_egory_list[self:val()])
                end
                if is_key_active(KEYS.ALT) then
                    append_search_none(self.cat_egory_list[self:val()])
                end
            elseif is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) and not is_key_active(KEYS.CONTROL) then
                append_search(self.cat_short_list[self:val()])
            elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) then
                append_search(self.name_list[self:val()])
            else
                append_search(self.name_list[self:val()])
            end
        end
    end

    function GUI.elms.list_category:onvalchange()
        update_subcategory(self:val(), 1)
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), GUI.elms.list_synonym:val())
        --if is_key_active(KEYS.CONTROL) then append_search(self.list[self:val()]) end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.list_subcategory:ondoubleclick()
        if is_cat_id_enable() then
            if is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) then
                append_search(self.name_list[self:val()])
            elseif is_key_active(KEYS.SHIFT) then
                if not is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search(self.subcategory_en_list[self:val()])
                elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search_hyphen(self.subcategory_en_list[self:val()])
                end
                if is_key_active(KEYS.ALT) then
                    append_search_none(self.subcategory_en_list[self:val()])
                end
            elseif is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) and not is_key_active(KEYS.CONTROL) then
                prepend_cat_id(self.cat_list[self:val()])
            else
                prepend_cat_id(self.cat_list[self:val()])
            end
        else
            if is_key_active(KEYS.SHIFT) then
                if not is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search(self.subcategory_en_list[self:val()])
                elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                    append_search_hyphen(self.subcategory_en_list[self:val()])
                end
                if is_key_active(KEYS.ALT) then
                    append_search_none(self.subcategory_en_list[self:val()])
                end
            elseif is_key_active(KEYS.ALT) and not is_key_active(KEYS.SHIFT) and not is_key_active(KEYS.CONTROL) then
                prepend_cat_id(self.cat_list[self:val()])
            else
                append_search(self.name_list[self:val()])
            end
        end
    end

    function GUI.elms.list_subcategory:onvalchange()
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), 1)
        --if is_key_active(KEYS.CONTROL) then self:ondoubleclick() end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.list_synonym:ondoubleclick()
        if is_key_active(KEYS.SHIFT) then
            if not is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                append_search(self.synonyms_en_list[self:val()])
            elseif is_key_active(KEYS.CONTROL) and not is_key_active(KEYS.ALT) then
                append_search_hyphen(self.synonyms_en_list[self:val()])
            end
            if is_key_active(KEYS.ALT) and not is_key_active(KEYS.CONTROL) then
                append_search_none(self.synonyms_en_list[self:val()])
            end
        else
            append_search(self.list[self:val()])
        end
    end

    function GUI.elms.list_synonym:onvalchange()
        --if is_key_active(KEYS.CONTROL) then append_search(self.list[self:val()]) end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.btn_filter:func()
        if #GUI.elms.edittext_filter:val() < 1 then return end
        current_filter_pattern = GUI.elms.edittext_filter:val()
        update_usc_data()

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
        GUI.elms.edittext_filter.focus = true
    end
    
    function GUI.elms.btn_clear:func()
        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
        GUI.elms.edittext_filter.focus = true
    end

    function GUI.elms.menu_lang:onvalchange()
        switch_lang(GUI.elms.menu_lang:val())
        display_usc_data(cur_usc_data)
    end

    function GUI.elms.btn_search:func()
        renaming()
    end

    function GUI.elms.edittext_search:onmousedown()
        GUI.elms.edittext_search:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")
        end
    end

    function GUI.elms.edittext_filter:onmousedown()
        GUI.elms.edittext_filter:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")
        end
    end

    function GUI.elms.edittext_search:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        end
    end

    function GUI.elms.edittext_filter:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        end
    end

    function GUI.elms.edittext_filter:onr_doubleclick() -- onr_doubleclick() 双击 onmouser_down() 单击
        self:val("")
    end

    function GUI.elms.edittext_search:onr_doubleclick()
        self:val("")
    end

    -- function GUI.elms.edittext_search:onr_doubleclick()
        -- self:undo()
    -- end
end

function update_usc_data()
    cur_usc_data = filter(full_usc_data, current_filter_pattern)
    display_usc_data(cur_usc_data)
end

GUI.Init()

if reaper.APIExists("JS_Window_Find") then
    hwnd = reaper.JS_Window_Find(GUI.name, true)
    if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
else
    reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'. Then restart REAPER and run the script again. Thank you!\n\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動 REAPER 並再次運行腳本。謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, "Error", 0)
    end
    return reaper.defer(function() end)
end

local fonts = GUI.get_OS_fonts()
GUI.fonts.monospace = {fonts.mono, 14}
GUI.fonts[4] = {fonts.sans, 16}
GUI.fonts[3] = {fonts.sans, 16}
GUI.fonts.version = {fonts.sans, 12, "i"}
GUI.colors.white = {225, 225, 225, 255} -- Set gui.lua [color = "white"]
GUI.Draw_Version = function ()
    if not GUI.version then return 0 end
    local str = "Script by 再補一刀  -  using Lokasenna_GUI " .. GUI.version
    GUI.font("version")
    GUI.color("txt")
    local str_w, str_h = gfx.measurestr(str)
    -- gfx.x = gfx.w/2 - str_w/2
    -- gfx.y = gfx.h - str_h - 4
    gfx.x = gfx.w - str_w - 6
    gfx.y = gfx.h - str_h - 4
    gfx.drawstr(str)
end

GUI.elms.check_cat:val({[1] = true, [2] = false, [3] = true, [4] = true, [5] = false})
switch_lang(1)

local load_system_usc_data_enabled = should_load_system_usc_data()
local load_user_usc_data_enabled = should_load_user_usc_data()
function check_cat_change()
    local new_load_system_usc_data_enabled = should_load_system_usc_data()
    local new_load_user_usc_data_enabled = should_load_user_usc_data()
    if new_load_system_usc_data_enabled ~= load_system_usc_data_enabled or new_load_user_usc_data_enabled ~= load_user_usc_data_enabled then
        reload_usc_data()
        update_usc_data()
    end
    load_system_usc_data_enabled = new_load_system_usc_data_enabled
    load_user_usc_data_enabled = new_load_user_usc_data_enabled
end

local load_is_cat_id_enable = is_cat_id_enable()
local load_is_cat_short_enable = is_cat_short_enable()
function check_cat_id_change()
    local new_load_is_cat_id_enable = is_cat_id_enable()
    local new_load_is_cat_short_enable = is_cat_short_enable()
    if new_load_is_cat_id_enable ~= load_is_cat_id_enable or new_load_is_cat_short_enable ~= load_is_cat_short_enable then
        display_usc_data(cur_usc_data)
    end
    load_is_cat_id_enable = new_load_is_cat_id_enable
    load_is_cat_short_enable = new_load_is_cat_short_enable
end

reload_usc_data()
update_usc_data()

GUI.freq = 0
-- text_box = true
GUI.elms.edittext_filter.focus = true

local function force_size() -- 锁定GUI边界
    gfx.quit()
    gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock, GUI.x, GUI.y)
    GUI.cur_w, GUI.cur_h = GUI.w, GUI.h
end

function GUI.func()
    process = GUI.elms.radio_pro.optarray[GUI.elms.radio_pro:val()]
    take_order = GUI.elms.radio_order.optarray[GUI.elms.radio_order:val()]

    -- val改变事件处理
    for _, elm in pairs(GUI.elms) do
        if elm.onvalchange == nil then
            goto continue
        end
        if elm.last_val == nil then
            elm.last_val = elm:val()
            goto continue
        end
        if elm:val() ~= elm.last_val then
            elm:onvalchange()
            elm.last_val = elm:val()
        end
        ::continue::
    end

    -- 选择框改变
    check_cat_change()
    check_cat_id_change()

    -- 键值处理
    local char = GUI.char
    -- print(char)
    if char == 13 then -- Enter 键
        if is_key_active(KEYS.CONTROL) then -- 同时按住Ctrl
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()

            if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
            GUI.elms.edittext_filter.focus = true
        elseif is_key_active(KEYS.ALT) then -- 同时按住Alt
            renaming()
        else
            renaming()
        end
    end

    if char == 26165 then -- F5 键
        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
        GUI.elms.edittext_filter.focus = true
    end

    if char == 26161 then -- F1 键
        if is_cat_id_enable() then
            GUI.elms.check_cat:val({[1] = false})
        else
            GUI.elms.check_cat:val({[1] = true})
        end
    end

    if char == 26162 then -- F2 键
        if is_cat_short_enable() then
            GUI.elms.check_cat:val({[2] = false})
        else
            GUI.elms.check_cat:val({[2] = true})
        end
    end

    if char == 26163 then -- F3 键
        if should_load_system_usc_data() then
            GUI.elms.check_cat:val({[3] = false})
        else
            GUI.elms.check_cat:val({[3] = true})
        end
    end

    if char == 26164 then -- F4 键
        if should_load_user_usc_data() then
            GUI.elms.check_cat:val({[4] = false})
        else
            GUI.elms.check_cat:val({[4] = true})
        end
    end

    if char == 26166 then -- F6 键
        GUI.elms.radio_connect:val(1)
    elseif char == 26167 then -- F7 键
        GUI.elms.radio_connect:val(2)
    elseif char == 26168 then -- F8 键
        GUI.elms.radio_connect:val(4)
    end

    if char == 9 then -- TAB 键
        if GUI.elms.edittext_filter.focus == false then
            GUI.elms.edittext_search.focus = false
            GUI.elms.edittext_filter.focus = true
            GUI.elms.edittext_filter.show_caret = true
        else
            GUI.elms.edittext_filter.focus = false
            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_search.show_caret = true
        end
        -- if text_box == false then
        --     GUI.elms.edittext_search.focus = false
        --     GUI.elms.edittext_filter.focus = true
        --     GUI.elms.edittext_filter.show_caret = true
        --     --GUI.elms.edittext_filter.caret = GUI.elms.edittext_search:carettoend()
        --     --GUI.elms.edittext_filter:redraw()
        --     text_box = true
        -- else
        --     GUI.elms.edittext_filter.focus = false
        --     GUI.elms.edittext_search.focus = true
        --     GUI.elms.edittext_search.show_caret = true
        --     GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
        --     --GUI.elms.edittext_search:redraw()
        --     text_box = false
        -- end
    end

    GUI.onresize = force_size
end

GUI.Main()