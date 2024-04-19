-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

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

function parseCSVLine(line, sep)
	local res = {}
	local pos = 1
	sep = sep or ','
	while true do 
		local c = string.sub(line,pos,pos)
		if (c == "") then break end
        if (c == "`") then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,"^%b``",pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == "`") then txt = txt.."`" end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= "`")
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
        elseif (c == "'") then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,"^%b''",pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == "'") then txt = txt.."'" end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= "'")
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
		elseif (c == '"') then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,'^%b""',pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == '"') then txt = txt..'"' end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= '"')
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
		else	
			-- no quotes used, just look for the first separator
			local startp,endp = string.find(line,sep,pos)
			if (startp) then 
				table.insert(res,string.sub(line,pos,startp-1))
				pos = endp + 1
			else
				-- no separator found -> use rest of string and terminate
				table.insert(res,string.sub(line,pos))
				break
			end 
		end
	end
	return res
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
    tTagData = {}
    local file = io.open(KEYWORDS_CSV_FILE, "r") -- script_path .. "keywords_favorite.csv" -- script_path .. getPathDelimiter() .. "keywords_favorite.csv"

    local lineNumber = 1
    while true do
        local line = file:read()
        if line == nil then break end -- 如果读到文件末尾，退出循环

        -- 检查解析得到的部分是否有效，且第一个字段（key）不为空
        local parts = parseFavoriteCSVLine(line, ",", lineNumber) -- 解析CSV行
        if parts == false then return end  -- 如果解析失败（parseCSVLine返回false），则退出函数

        if not line:match("^#") and not line:match("^;") then
            if parts ~= nil and parts[1] ~= "" then
                -- 直接使用parts[2]和parts[3]，哪怕它们是空字符串""
                local alias = parts[2] or ""
                local type = parts[3] or ""
                
                -- 将数据插入到tTagData表中
                table.insert(tTagData, {
                    name = parts[1],
                    alias = alias,
                    type = type
                })
            end
        end

        lineNumber = lineNumber + 1
    end
    io.close(file)

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
