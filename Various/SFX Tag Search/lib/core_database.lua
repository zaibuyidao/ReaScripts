-- NoIndex: true
function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
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
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
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

function getPathDelimiter()
    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        return "/"
    else
        return "\\"
    end
end

function split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function readCsvToTagData(csvFilePath)
    local tResult = {}
    local file = io.open(csvFilePath, "r")
    if not file then return false end

	local headers = split(file:read("*l"), ",")

    for line in file:lines() do
        local cells = {}
        for cell in line:gmatch("([^,]+)") do
            table.insert(cells, cell)
        end

        if #cells >= 3 then
            table.insert(tResult, {
                name = cells[1],
                alias = cells[2],
				type = cells[3],
                --rating = tonumber(cells[3]) or 0,
            })
        end
    end

    file:close()
    return tResult
end

-- function send_search_text(text) -- 开始搜索
--     --local title = reaper.JS_Localize("Media Explorer", "common")
--     local title = reaper.JS_Localize("媒体资源管理器", "common")
--     local hwnd = reaper.JS_Window_Find(title, true)
--     local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
--     if search == nil then return end
--     reaper.JS_Window_SetTitle(search, text)
--     reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
--     reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
--     -- reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
--     -- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE
-- end

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end

    reaper.JS_Window_SetTitle(search, text)
    reaper.SetExtState("UCS_TAG_SEARCH", "SEARCH_TEXT", text, false)

    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    else
        -- if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then
        --     reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0) -- reaper.SetToggleCommandState(32063, 42051, 0) -- 无效
        -- end
        -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
        reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x20, 0,0,0) -- SPACEBAR
    end
end

function openUrl(url)
    local osName = reaper.GetOS()
    if osName:match("^OSX") then
        os.execute('open "" "' .. url .. '"')
    else
        -- chcp 65001
        os.execute('start "" "' .. url .. '"')
    end
end

function reloadData() -- 重新加载数据
    local tTagData = {}
    -- 从CSV加载数据
    tTagData = readCsvToTagData(KEYWORDS_CSV_FILE)
    if not tTagData then
        msg("Failed to load TAG data from CSV")
        return false
    end

	-- 从评分文件读取评分信息
	local ratings = jReadTagData(DATA_INI_FILE) -- 确保这是评分信息存储的正确路径

	-- 更新tTagData中的评分信息
	for _, item in ipairs(tTagData) do
		if ratings[item.name] then
			item.rating = tonumber(ratings[item.name].rating) or 0
		else
			item.rating = 0  -- 如果评分信息中没有该项，将评分设置为0
		end
	end

	if UPDATE_RATINGS then
		table.sort(tTagData, sortByRating) -- 按评分排序
	else
		table.sort(tTagData, function (a, b) return custom_sort(a, b, not ENGLISH_FIRST) end)
	end

    -- 更新界面
    tSearchResults = findTag(tTagData, "", false, MAX_RESULTS)  -- 假设 "" 会显示所有结果
    showSearchResults(tResultButtons, tSearchResults)  -- 更新显示的结果

	UPDATE_RESULTS = true
end

-- 判断字符是否为中文
function is_chinese_char(char)
	local utf8_value = string.byte(char)
	return utf8_value >= 0xE0 and utf8_value <= 0xEF
end

function get_pinyin(text)
	return pinyin(text, true, "") -- 使用空字符串作为连接符
end

-- 自定义排序函数，针对具有 name 的表结构
function custom_sort(a, b, cn_first)
    local a_key = a.name or "" -- 根据 name 排序
    local b_key = b.name or ""

    local a_pinyin = get_pinyin(a_key)
    local b_pinyin = get_pinyin(b_key)

    local a_is_chinese = is_chinese_char(a_key:sub(1, 1))
    local b_is_chinese = is_chinese_char(b_key:sub(1, 1))

    if a_is_chinese and b_is_chinese then
        if a_pinyin ~= b_pinyin then
            return a_pinyin < b_pinyin
        else
            return string.lower(a_key) < string.lower(b_key)
        end
    elseif not a_is_chinese and not b_is_chinese then
        return string.lower(a_key) < string.lower(b_key)
    else
        if cn_first then
            return a_is_chinese
        else
            return not a_is_chinese
        end
    end
end

function getDbList()
    local reaperConfig = LIP.load(reaper.GetResourcePath() .. getPathDelimiter() .. "reaper.ini")
    local reaper_explorer = reaperConfig.reaper_explorer
    if reaper_explorer == nil then 
        print("reaper_explorer is nil")
        return false 
    end

    local res = {}

    for i = 0, tonumber(reaper_explorer.NbShortcuts) - 1 do
        local shortcutKey = string.format("Shortcut%d", i)
        local shortcutTKey = string.format("ShortcutT%d", i)
        local shortcutValue = reaper_explorer[shortcutKey]
        local shortcutTValue = reaper_explorer[shortcutTKey]
        shortcutTValue = tostring(shortcutTValue)
        
        -- 排除特定的项
        if (shortcutValue == "<Track Templates>" or shortcutValue == "<Project Directory>") then
            goto continue
        end

        if shortcutValue and shortcutTValue then
            if shortcutValue:find("^.+%.ReaperFileList$") or shortcutValue:find("^<.+>$") then
                res[shortcutValue] = {
                    path = reaper.GetResourcePath() .. getPathDelimiter() .. "MediaDB" .. getPathDelimiter() .. shortcutValue,
                    name = shortcutTValue,
                    i = i
                }
            end
        end

        ::continue::
    end

    -- 对结果进行排序
    local sortedRes = {}
    for _, v in pairs(res) do
        table.insert(sortedRes, v)
    end
    table.sort(sortedRes, function(a, b)
        return a.i < b.i
    end)
    
    return sortedRes
end

function reloadDbData() -- 重新加载数据
	dbList = getDbList()
	if dbList == false then return end
	
	-- 实时创建数据库列表版本
	tTagData = {}
	
	for _, db in ipairs(dbList) do
        local dbType = getDbType(db.name)
        local modifiedName = db.name:gsub('"', '')
        table.insert(tTagData, {
            name = modifiedName,
            alias = "",  -- 预留空列
            type = dbType
        })
	end
	
	-- 打印测试数据库类型
	-- for _, item in ipairs(tTagData) do
	-- 	print(string.format("DB Name: %s, Type: %s", item.name, item.type))
	-- end

	-- 从评分文件读取评分信息
	local ratings = jReadTagData(DATA_INI_FILE) -- 确保这是评分信息存储的正确路径

	-- 更新tTagData中的评分信息
	for _, item in ipairs(tTagData) do
		if ratings[item.name] then
			item.rating = tonumber(ratings[item.name].rating) or 0
		else
			item.rating = 0  -- 如果评分信息中没有该项，将评分设置为0
		end
	end

	if UPDATE_RATINGS then
		table.sort(tTagData, sortByRating) -- 按评分排序
	else
		table.sort(tTagData, function (a, b) return custom_sort(a, b, not ENGLISH_FIRST) end)
	end

    -- 更新界面
    tSearchResults = findTag(tTagData, "", false, MAX_RESULTS)  -- 假设 "" 会显示所有结果
    showSearchResults(tResultButtons, tSearchResults)  -- 更新显示的结果

	UPDATE_RESULTS = true -- 标记界面需要更新
end