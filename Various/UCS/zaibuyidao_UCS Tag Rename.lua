-- NoIndex: true
bias = 0.002

function print(...)
    local args = {...}
    local str = ""
    for i = 1, #args do
        str = str .. string.format("%s\t", tostring(args[i]))
    end
    reaper.ShowConsoleMsg(str .. "\n")
end

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

if not reaper.APIExists("JS_Localize") then
    reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, "錯誤", 0)
    end
    return reaper.defer(function() end)
end

function getPathDelimiter()
    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        return "/"
    else
        return "\\"
    end
end

local delimiter = getPathDelimiter()
local GUI_path = reaper.GetResourcePath() .. delimiter .. "Scripts" .. delimiter .. "zaibuyidao Scripts" .. delimiter .. "Development" .. delimiter .. "Lokasenna_GUI Library" .. delimiter .. "Set Lokasenna_GUI library.lua"
local base_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. base_path .. "?.lua" .. ";" .. base_path .. "/lib/?.lua" .. ";" .. GUI_path

local GLOBAL_STATE_SECTION

function setGlobalStateSection(section)
    GLOBAL_STATE_SECTION = section
end

function getState(key, default, convert)
	local value = reaper.GetExtState(GLOBAL_STATE_SECTION, key)
    if not value or value == "" then return default end
    if convert then return convert(value) end
    return value
end

function setState(tab)
    for k, v in pairs(tab) do
        reaper.SetExtState(GLOBAL_STATE_SECTION, k, v, true)
    end
end

function onSaveWindowSizeAndPosition() -- 保存窗口尺寸和位置
    local dockstate, wx, wy, ww, wh = gfx.dock(-1, 0, 0, 0, 0)
    local dockstr = string.format("%d", dockstate)
    setState({
        WINDOW_WIDTH = math.tointeger(ww),
        WINDOW_HEIGHT = math.tointeger(wh),
        WINDOW_X = math.tointeger(wx),
        WINDOW_Y = math.tointeger(wy),
        WINDOW_DOCK_STATE = dockstr
    })
end

setGlobalStateSection("UCS_TAG_RENAME")

function getSystemLanguage()
	local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
	local os = reaper.GetOS()
	local lang
  
	if os == "Win32" or os == "Win64" then -- Windows
		if locale == 936 then -- Simplified Chinese
			lang = "简体中文"
		elseif locale == 950 then -- Traditional Chinese
			lang = "繁體中文"
		else -- English
			lang = "English"
		end
	elseif os == "OSX32" or os == "OSX64" then -- macOS
		local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
		local result = handle:read("*a")
		handle:close()
		lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
		if lang == "zh-CN" then -- 简体中文
			lang = "简体中文"
		elseif lang == "zh-TW" then -- 繁体中文
			lang = "繁體中文"
		else -- English
			lang = "English"
		end
	elseif os == "Linux" then -- Linux
		local handle = io.popen("echo $LANG")
		local result = handle:read("*a")
		handle:close()
		lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
		if lang == "zh_CN" then -- 简体中文
			lang = "简体中文"
		elseif lang == "zh_TW" then -- 繁體中文
		    lang = "繁體中文"
		else -- English
		    lang = "English"
		end
	end

	return lang
end

local language = getSystemLanguage()

if language == "简体中文" then
    WINDOW_NAME = "UCS 标签重命名 - UCS 更新（2023年2月1日）：版本 8.2"
    FONT_SANS = "SimSun" -- "SimSun"、"Microsoft YaHei"、"Calibri"、"华文中宋"、"华文宋体"、"华文细黑"
    FONT_MONO = "SimSun"
    FONT_SIZE_2 = 14
    FONT_SIZE_3 = 14
    FONT_SIZE_4 = 14
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "重命名"
    SEARCH_TITLE_KEY = "关键词"
    FILTER_TITLE = "过滤"
    FILTER_TITLE_KEY = "关键词"
    OPT_NAME_1 = "CatID"
    OPT_NAME_2 = "CatShort"
    OPT_NAME_3 = "UCS 列表"
    OPT_NAME_4 = "定制列表"
    OPT_NAME_5 = "循环计数"
    SEARCH_BTN = "重命名"
    SEARCH_BTN_CLOSE = "关闭"
    FILTER_BTN = "过滤"
    CLEAR_BTN = "清除"
    RD_PROCESSING = "处理"
    RD_SEPARATOR = "连接符"
    RD_TAKE_ORDER = "片段排序"
    OPT_PROCESSING_1 = "区域管理器"
    OPT_PROCESSING_2 = "区域选区"
    OPT_PROCESSING_3 = "标记管理器"
    OPT_PROCESSING_4 = "标记选区"
    OPT_PROCESSING_5 = "对象/片段"
    OPT_PROCESSING_6 = "轨道"
    OPT_CONNECT_1 = "下横线"
    OPT_CONNECT_2 = "短横线"
    OPT_CONNECT_3 = "空格"
    OPT_CONNECT_4 = "无"
    OPT_TAKE_ORDER_1 = "轨道"
    OPT_TAKE_ORDER_2 = "换行"
    OPT_TAKE_ORDER_3 = "时间线"
elseif language == "繁体中文" then
    WINDOW_NAME = "UCS 標簽重命名 - UCS 更新（2023年2月1日）：版本 8.2"
    FONT_SANS = "SimSun" -- "SimSun" "Microsoft YaHei" "Calibri"
    FONT_MONO = "SimSun"
    FONT_SIZE_2 = 14
    FONT_SIZE_3 = 14
    FONT_SIZE_4 = 14
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "重命名"
    SEARCH_TITLE_KEY = "關鍵詞"
    FILTER_TITLE = "過濾"
    FILTER_TITLE_KEY = "關鍵詞"
    OPT_NAME_1 = "CatID"
    OPT_NAME_2 = "CatShort"
    OPT_NAME_3 = "UCS 列表"
    OPT_NAME_4 = "自訂列表"
    OPT_NAME_5 = "循環計數"
    SEARCH_BTN = "重命名"
    SEARCH_BTN_CLOSE = "關閉"
    FILTER_BTN = "過濾"
    CLEAR_BTN = "清除"
    RD_PROCESSING = "處理"
    RD_SEPARATOR = "連接符"
    RD_TAKE_ORDER = "片段排序"
    OPT_PROCESSING_1 = "區域管理器"
    OPT_PROCESSING_2 = "區域選區"
    OPT_PROCESSING_3 = "標記管理器"
    OPT_PROCESSING_4 = "標記選區"
    OPT_PROCESSING_5 = "對象/片段"
    OPT_PROCESSING_6 = "軌道"
    OPT_CONNECT_1 = "下橫綫"
    OPT_CONNECT_2 = "短橫綫"
    OPT_CONNECT_3 = "空格"
    OPT_CONNECT_4 = "無"
    OPT_TAKE_ORDER_1 = "軌道"
    OPT_TAKE_ORDER_2 = "換行"
    OPT_TAKE_ORDER_3 = "時間綫"
else
    WINDOW_NAME = "UCS Tag Rename - UCS Update (Feb 1st, 2023): Version 8.2"
    FONT_SANS = "Calibri"
    FONT_MONO = "Consolas"
    FONT_SIZE_2 = 16
    FONT_SIZE_3 = 16
    FONT_SIZE_4 = 16
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "Renaming"
    SEARCH_TITLE_KEY = "Keywords"
    FILTER_TITLE = "Filter"
    FILTER_TITLE_KEY = "Keywords"
    OPT_NAME_1 = "CatID"
    OPT_NAME_2 = "CatShort"
    OPT_NAME_3 = "UCS list"
    OPT_NAME_4 = "Custom"
    OPT_NAME_5 = "Loop count"
    SEARCH_BTN = "Renaming"
    SEARCH_BTN_CLOSE = "Close"
    FILTER_BTN = "Filter"
    CLEAR_BTN = "Clear"
    RD_PROCESSING = "Processing"
    RD_SEPARATOR = "Separator"
    RD_TAKE_ORDER = "Take order"
    OPT_PROCESSING_1 = "Rgn manager"
    OPT_PROCESSING_2 = "Rgn time"
    OPT_PROCESSING_3 = "Mkr manager"
    OPT_PROCESSING_4 = "Mkr time"
    OPT_PROCESSING_5 = "Take"
    OPT_PROCESSING_6 = "Track"
    OPT_CONNECT_1 = "Underscore"
    OPT_CONNECT_2 = "Hyphen"
    OPT_CONNECT_3 = "Space"
    OPT_CONNECT_4 = "None"
    OPT_TAKE_ORDER_1 = "Track"
    OPT_TAKE_ORDER_2 = "Wrap"
    OPT_TAKE_ORDER_3 = "Timeline"
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

-- loadfile(reaper.GetResourcePath() .. delimiter .. "Scripts" .. delimiter .. "zaibuyidao Scripts" .. delimiter .. "Development" .. delimiter .. "Lokasenna_GUI Library" .. delimiter .. "Set Lokasenna_GUI library.lua")()
require('Set Lokasenna_GUI library')
require('utils')
require('ucs')
require('guir')

GUI.name = WINDOW_NAME
GUI.x = getState("WINDOW_X", 50, tonumber)
GUI.y = getState("WINDOW_Y", 50, tonumber)
GUI.w = getState("WINDOW_WIDTH", 864, tonumber)
GUI.h = getState("WINDOW_HEIGHT", 456, tonumber)
dockstate = getState("WINDOW_DOCK_STATE")

local full_usc_data
local cur_usc_data
local current_filter_pattern = ""

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

function update_optarray_names(new_names) -- CatID等开关
    if #new_names ~= #GUI.elms.check_cat.optarray then
        error("new_names size does not match the original optarray size")
    end

    for i, name in ipairs(new_names) do
        GUI.elms.check_cat.optarray[i] = name
    end

    -- 刷新check_cat元素
    GUI.elms.check_cat:init()
end

function update_processing_names(new_names) -- 处理切换
    if #new_names ~= #GUI.elms.radio_pro.optarray then
        error("new_names size does not match the original optarray size")
    end

    for i, name in ipairs(new_names) do
        GUI.elms.radio_pro.optarray[i] = name
    end

    GUI.elms.radio_pro:init()
end

function update_take_order_names(new_names) -- 处理切换
    if #new_names ~= #GUI.elms.radio_order.optarray then
        error("new_names size does not match the original optarray size")
    end

    for i, name in ipairs(new_names) do
        GUI.elms.radio_order.optarray[i] = name
    end

    GUI.elms.radio_order:init()
end

function get_btn_search_caption()
    return GUI.elms.btn_search.caption
end

function set_btn_search_caption(new_caption)
    GUI.elms.btn_search.caption = new_caption

    -- 刷新btn_search元素
    GUI.elms.btn_search:init()
end

function set_btn_search_close_caption(new_caption)
    GUI.elms.btn_search_close.caption = new_caption

    -- 刷新btn_search_close元素
    GUI.elms.btn_search_close:init()
end

function set_btn_filter_caption(new_caption)
    GUI.elms.btn_filter.caption = new_caption

    -- 刷新btn_filter元素
    GUI.elms.btn_filter:init()
end

function set_btn_clear_caption(new_caption)
    GUI.elms.btn_clear.caption = new_caption

    -- 刷新btn_clear元素
    GUI.elms.btn_clear:init()
end

function set_radio_pro_caption(new_caption) -- 处理
    GUI.elms.radio_pro.caption = new_caption

    -- 刷新radio_pro元素
    GUI.elms.radio_pro:init()
end

function set_radio_connect_caption(new_caption) -- 连接符
    GUI.elms.radio_connect.caption = new_caption

    -- 刷新radio_connect元素
    GUI.elms.radio_connect:init()
end

function set_radio_order_caption(new_caption) -- 连接符
    GUI.elms.radio_order.caption = new_caption

    -- 刷新radio_order元素
    GUI.elms.radio_order:init()
end

-- 翻译文本
local new_optarray_names = {OPT_NAME_1, OPT_NAME_2, OPT_NAME_3, OPT_NAME_4, OPT_NAME_5} -- 开关
update_optarray_names(new_optarray_names)

local new_processing_names = {OPT_PROCESSING_1, OPT_PROCESSING_2, OPT_PROCESSING_3, OPT_PROCESSING_4, OPT_PROCESSING_5, OPT_PROCESSING_6} -- 处理切换
update_processing_names(new_processing_names)

local new_take_order_names = {OPT_TAKE_ORDER_1, OPT_TAKE_ORDER_2, OPT_TAKE_ORDER_3} -- 处理切换
update_take_order_names(new_take_order_names)

set_btn_search_caption(SEARCH_BTN)
set_btn_search_close_caption(SEARCH_BTN_CLOSE)
set_btn_filter_caption(FILTER_BTN)
set_btn_clear_caption(CLEAR_BTN)
set_radio_pro_caption(RD_PROCESSING)
set_radio_connect_caption(RD_SEPARATOR)
set_radio_order_caption(RD_TAKE_ORDER)

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

seperators = {
    {name = OPT_CONNECT_1, value = "_"}, --  "Underscore"
    {name = OPT_CONNECT_2, value = "-"}, -- "Hyphen"
    {name = OPT_CONNECT_3, value = " "}, -- "Space"
    {name = OPT_CONNECT_4, value = ""} -- "None"
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
    if text == nil then text = "" end
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

function replace_cat_short(cat_short)
    local et = GUI.elms.edittext_search
    local orig = et:val()

    -- 定义分隔符
    local separators = {"_", "-", " "}
    
    -- 查找并替换 cat_short
    local function replace_cat(orig, cat_short)
        local found = false
        for _, sep in ipairs(separators) do
            local pattern = "([^" .. sep .. "]+)"
            local splitted = {}
            for part in orig:gmatch(pattern) do
                table.insert(splitted, part)
            end

            for i, part in ipairs(splitted) do
                if part == et.cat_short then
                    splitted[i] = cat_short
                    found = true
                    break
                end
            end

            if found then
                local new_val = table.concat(splitted, sep)
                et:val(new_val)
                et.cat_short = cat_short
                et.caret = new_val:find(cat_short, 1, true)
                et:redraw()
                break
            end
        end
        return found
    end

    local replaced = false
    -- 检查是否成功替换了 cat_short
    if get_seperator() ~= "" then
        replaced = replace_cat(orig, cat_short)
    end

    -- 如果没有找到并替换现有的 cat_short，则添加新的 cat_short
    if not replaced then
        -- 如果原始字符串为空，则直接添加 cat_short
        if orig == "" then
            et:val(cat_short)
        -- 如果原始字符串等于 et.cat_short，则直接替换为新的 cat_short
        elseif orig == et.cat_short then
            et:val(cat_short)
        -- 否则，在原始字符串后添加指定的分隔符和新的 cat_short
        else
            local added = false
            local current_sep = get_seperator()
            for _, sep in ipairs(separators) do
                if current_sep ~= "" and orig:find(sep) then
                    et:val(orig .. sep .. cat_short) -- 三个分隔符的任何一个都作为通用分隔符，否则使用 current_sep
                    added = true
                    break
                end
            end
            if not added then
                -- 使用指定的分隔符添加新的 cat_short
                if current_sep ~= "" then
                    et:val(orig .. current_sep .. cat_short)
                else
                    -- 如果分隔符为 None，则直接添加 cat_short，不添加连接符
                    et:val(orig .. cat_short)
                end
            end
        end
        et.cat_short = cat_short
        et.caret = et:carettoend()
        et:redraw()
    end
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

function setFocusToWindow(name)
    local title = reaper.JS_Localize(name, "common")
    local hwnd = reaper.JS_Window_Find(title, 0) -- 0 代表匹配整个标题
    reaper.BR_Win32_SetFocus(hwnd)
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

    search_text = GUI.elms.edittext_search:val()
    reaper.SetExtState("UCSTagRename", "SearchText", search_text, false)

    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    GUI.elms.edittext_search.focus = true
    GUI.elms.edittext_filter.focus = false
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
                return item.name:get(locale) .. " [" .. item.name.cat_short .. "]"
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
                return item.name:get(locale) .. " [" .. item.cat_id .. "]"
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
                replace_cat_short(self.cat_short_list[self:val()])
            else
                replace_cat_short(self.cat_short_list[self:val()])
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
                replace_cat_short(self.cat_short_list[self:val()])
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
        GUI.elms.list_subcategory:scroll_to_top()
        GUI.elms.list_synonym:scroll_to_top()
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
        GUI.elms.list_synonym:scroll_to_top()
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

        GUI.elms.edittext_search.focus = false
        GUI.elms.edittext_filter.focus = true
    end
    
    function GUI.elms.btn_clear:func()
        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        GUI.elms.list_category:scroll_to_top()
        GUI.elms.list_subcategory:scroll_to_top()
        GUI.elms.list_synonym:scroll_to_top()

        GUI.elms.edittext_search.focus = false
        GUI.elms.edittext_filter.focus = true
    end

    function GUI.elms.menu_lang:onvalchange()
        switch_lang(GUI.elms.menu_lang:val())
        display_usc_data(cur_usc_data)
    end

    function GUI.elms.btn_search:func()
        renaming()
    end

    function GUI.elms.btn_search_close:func()
        gfx.quit()
    end

    function GUI.elms.edittext_search:onmousedown()
        GUI.elms.edittext_search:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")

            search_text = ""
            reaper.SetExtState("UCSTagRename", "SearchText", search_text, false)
        end
        if is_key_active(KEYS.SHIFT) then -- 发送重命名
            renaming()
        end
    end

    function GUI.elms.edittext_filter:onmousedown()
        GUI.elms.edittext_filter:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")
        end
    end

    function GUI.elms.edittext_filter:onr_doubleclick() -- 右键双击过滤框
        self:val("")

        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        GUI.elms.list_category:scroll_to_top()
        GUI.elms.list_subcategory:scroll_to_top()
        GUI.elms.list_synonym:scroll_to_top()

        GUI.elms.edittext_search.focus = false
        GUI.elms.edittext_filter.focus = true
    end

    function GUI.elms.edittext_search:onr_doubleclick() -- 右键双击搜索框
        self:val("")

        GUI.elms.edittext_filter.focus = false
        GUI.elms.edittext_search.focus = true
    end

    function GUI.elms.edittext_filter:onmouser_down() -- 右键单击过滤框
        self:val("")

        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        GUI.elms.list_category:scroll_to_top()
        GUI.elms.list_subcategory:scroll_to_top()
        GUI.elms.list_synonym:scroll_to_top()

        GUI.elms.edittext_search.focus = false
        GUI.elms.edittext_filter.focus = true
    end

    function GUI.elms.edittext_search:onmouser_down() -- 右键单击搜索框
        self:val("")

        GUI.elms.edittext_filter.focus = false
        GUI.elms.edittext_search.focus = true
    end

    function GUI.elms.edittext_filter:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        else
            local text = GUI.elms.edittext_filter:val()
            local userok, text = reaper.GetUserInputs(FILTER_TITLE, 1, FILTER_TITLE_KEY .. ",extrawidth=300", text)
            if not userok then return setFocusToWindow(WINDOW_NAME) end
    
            GUI.elms.edittext_filter:val(text)
            GUI.elms.edittext_filter.caret = GUI.elms.edittext_filter:carettoend()
            GUI.elms.edittext_filter:redraw()
    
            if #GUI.elms.edittext_filter:val() < 1 then return end
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()
    
            GUI.elms.edittext_search.focus = false
            GUI.elms.edittext_filter.focus = true
    
            setFocusToWindow(WINDOW_NAME)
        end
    end

    function GUI.elms.edittext_search:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        else
            local text = GUI.elms.edittext_search:val()
            local userok, text = reaper.GetUserInputs(SEARCH_TITLE, 1, SEARCH_TITLE_KEY .. ",extrawidth=300", text)
            if not userok then return setFocusToWindow(WINDOW_NAME) end
    
            GUI.elms.edittext_search:val(text)
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            GUI.elms.edittext_search:redraw()
    
            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_filter.focus = false
    
            setFocusToWindow(WINDOW_NAME)
        end
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

GUI.font = function (fnt)
    local font, size, str = table.unpack( type(fnt) == "table" and fnt or  GUI.fonts[fnt])
    if not string.match( reaper.GetOS(), "Win") then
        size = math.floor(size * 0.8)
    else
        size = math.floor(size)
    end

    local flags = 0
    if str then
        for i = 1, str:len() do
            flags = flags * 256 + string.byte(str, i)
        end
    end
    gfx.setfont(1, font, size, flags)
end

GUI.OS_fonts = { -- 字体设置
    Windows = {
        sans = FONT_SANS, -- "Calibri"
        mono = FONT_MONO -- "Consolas"
    },
    OSX = {
        sans = "Helvetica Neue",
        mono = "Andale Mono"
    },
    Linux = {
        sans = "Arial",
        mono = "DejaVuSansMono"
    }
}

GUI.get_OS_fonts = function()
    local os = reaper.GetOS()
    if os:match("Win") then
        return GUI.OS_fonts.Windows
    elseif os:match("OSX") then
        return GUI.OS_fonts.OSX
    else
        return GUI.OS_fonts.Linux
    end
end

local fonts = GUI.get_OS_fonts()
GUI.fonts.monospace = {fonts.mono, FONT_SIZE_M}
GUI.fonts[4] = {fonts.sans, FONT_SIZE_4}
GUI.fonts[3] = {fonts.sans, FONT_SIZE_3}
GUI.fonts[2] = {fonts.sans, FONT_SIZE_2}
GUI.fonts.version = {fonts.sans, FONT_SIZE_V, "i"}
GUI.colors.white = {225, 225, 225, 255} -- Set gui.lua [color = "white"]
GUI.Draw_Version = function ()
    if not GUI.version then return 0 end
    local str = "Script by 再補一刀 - using Lokasenna_GUI " .. GUI.version
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
current_lang_index = 1
switch_lang(current_lang_index)

function auto_switch_language()
    current_lang_index = current_lang_index + 1
    if current_lang_index > #LANGS then
        current_lang_index = 1
    end
    switch_lang(current_lang_index)
end

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

local search_text = reaper.GetExtState("UCSTagRename", "SearchText")
if search_text ~= "" then
    GUI.elms.edittext_search:val(search_text)
    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
end

GUI.freq = 0
-- GUI.elms.edittext_filter.focus = true -- 脚本启动时，默认聚焦过滤框

local function force_size() -- 锁定GUI边界
    gfx.quit()
    gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock, GUI.x, GUI.y)
    GUI.cur_w, GUI.cur_h = GUI.w, GUI.h
end

if reaper.JS_Window_FindEx then
    local hwnd = reaper.JS_Window_Find(WINDOW_NAME, true)
    if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
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

    local listboxes = {
        GUI.elms.list_category,
        GUI.elms.list_subcategory,
        GUI.elms.list_synonym
    }

    if char == 1685026670 or char == 30064 then -- Up or Down arrow key
        for _, listbox in ipairs(listboxes) do
            if listbox.focus then
                listbox:onkeydown(char)
                break
            end
        end
    end

    -- 上下左右按键发送关键词 与Listbox库关联
    function get_list_category_value(self, mode) -- 主分类
        if mode == "cat" then
            return self.cat_short_list[self:val()]
        elseif mode == "en" then
            return self.category_en_list[self:val()]
        elseif mode == "name" then
            return self.name_list[self:val()]
        end
    end

    function get_list_subcategory_value(self, mode) -- 子分类
        if mode == "cat" then
            return self.cat_list[self:val()]
        elseif mode == "en" then
            return self.subcategory_en_list[self:val()]
        elseif mode == "name" then
            return self.name_list[self:val()]
        end
    end

    function get_list_synonym_value(self, mode) -- 子分类
        if mode == "en" then
            return self.synonyms_en_list[self:val()]
        elseif mode == "name" then
            return self.list[self:val()]
        end
    end

    function on_list_left_arrow_send(char)
        local selected_item_name = nil
        local listbox = nil
    
        for _, box in ipairs(listboxes) do
            if box.focus then
                selected_item_name = box:getselectitem(char)
                listbox = box
                break
            end
        end

        if selected_item_name then
            if listbox.name == GUI.elms.list_category.name then -- 主分类
                append_search(get_list_category_value(GUI.elms.list_category, "name"))
            elseif listbox.name == GUI.elms.list_subcategory.name then -- 子分类
                append_search(get_list_subcategory_value(GUI.elms.list_subcategory, "name"))
            elseif listbox.name == GUI.elms.list_synonym.name then -- 同义词
                append_search(get_list_synonym_value(GUI.elms.list_synonym, "name"))
            end
        else
            print("没有选中的项目")
        end
    end

    function on_list_right_arrow_send(char)
        local selected_item_name = nil
        local listbox = nil
    
        for _, box in ipairs(listboxes) do
            if box.focus then
                selected_item_name = box:getselectitem(char)
                listbox = box
                break
            end
        end

        if selected_item_name then
            if listbox.name == GUI.elms.list_category.name then -- 主分类
                if is_cat_short_enable() then
                    replace_cat_short(get_list_category_value(GUI.elms.list_category, "cat"))
                else
                    append_search(get_list_category_value(GUI.elms.list_category, "en"))
                end
            elseif listbox.name == GUI.elms.list_subcategory.name then -- 子分类
                if is_cat_id_enable() then
                    prepend_cat_id(get_list_subcategory_value(GUI.elms.list_subcategory, "cat"))
                else
                    append_search(get_list_subcategory_value(GUI.elms.list_subcategory, "en"))
                end
            elseif listbox.name == GUI.elms.list_synonym.name then -- 同义词
                append_search(get_list_synonym_value(GUI.elms.list_synonym, "en"))
            end
        else
            print("没有选中的项目")
        end
    end
    
    if char == 1818584692 then -- 方向键左键1818584692 获取选中项目的值
        on_list_left_arrow_send(char)
    end

    if char == 1919379572 then -- 方向键右键1919379572 获取选中项目的值
        on_list_right_arrow_send(char)
    end
    
    if char == 13 then -- Enter 键
        if is_key_active(KEYS.CONTROL) then -- 同时按住Ctrl
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()

            GUI.elms.edittext_search.focus = false
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

        GUI.elms.list_category:scroll_to_top()
        GUI.elms.list_subcategory:scroll_to_top()
        GUI.elms.list_synonym:scroll_to_top()

        GUI.elms.edittext_search.focus = false
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
        switch_lang(1)
    end

    if char == 26167 then -- F7 键
        switch_lang(2)
    end

    if char == 26168 then -- F8 键
        switch_lang(3)
    end

    if char == 26169 then -- F9 键
        auto_switch_language()
    end

    if char == 6697264 then -- F10 键
        current_function_index = GUI.elms.radio_connect:val()

        GUI.elms.radio_connect:val(current_function_index)

        function auto_switch_function()
            current_function_index = current_function_index + 1
            if current_function_index > #GUI.elms.radio_connect.optarray then -- 分隔符长度
                current_function_index = 1
            end
            GUI.elms.radio_connect:val(current_function_index)
        end

        auto_switch_function()
    end

    if char == 6697265 then -- F11
        local text = GUI.elms.edittext_filter:val()
        local userok, text = reaper.GetUserInputs(FILTER_TITLE, 1, FILTER_TITLE_KEY .. ",extrawidth=300", text)
        if not userok then return setFocusToWindow(WINDOW_NAME) end

        GUI.elms.edittext_filter:val(text)
        GUI.elms.edittext_filter.caret = GUI.elms.edittext_filter:carettoend()
        GUI.elms.edittext_filter:redraw()

        if #GUI.elms.edittext_filter:val() < 1 then return end
        current_filter_pattern = GUI.elms.edittext_filter:val()
        update_usc_data()

        GUI.elms.edittext_search.focus = false
        GUI.elms.edittext_filter.focus = true

        setFocusToWindow(WINDOW_NAME)
    end

    if char == 6697266 then -- F12
        local text = GUI.elms.edittext_search:val()
        local userok, text = reaper.GetUserInputs(SEARCH_TITLE, 1, SEARCH_TITLE_KEY .. ",extrawidth=300", text)
        if not userok then return setFocusToWindow(WINDOW_NAME) end
    
        GUI.elms.edittext_search:val(text)
        GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
        GUI.elms.edittext_search:redraw()
    
        GUI.elms.edittext_search.focus = true
        GUI.elms.edittext_filter.focus = false
    
        setFocusToWindow(WINDOW_NAME)
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
    end

    onSaveWindowSizeAndPosition()
    GUI.onresize = force_size
end

GUI.Main()