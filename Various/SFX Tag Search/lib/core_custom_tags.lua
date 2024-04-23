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

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end
    
    reaper.defer(function ()
        reaper.JS_Window_SetTitle(search, text)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    end)
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

	dbList = getDbList()
	if dbList == false then return end

    local readDBCount = 0
    for _, db in ipairs(dbList) do
        if not excludeDbName[db.name] then
            local excludeOriginSet = {}
            for columnName, _ in pairs(excludeColumnName) do
                excludeOriginSet[columnName] = true  -- 使用集合来标记排除的列，便于查找
            end
            --print("Excluding columns: " .. table.concat(table.keys(excludeOriginSet), ", "))
    
            local keywords = readViewModelFromReaperFileList(db.path, {
                excludeOrigin = excludeOriginSet,  -- 传递集合而非数组
                --指定分隔符列表
                delimiters = {
                    -- ["Album"] = {}, -- List of separators for Custom Tags
                    -- ["Comment"] = {}, -- List of separators for Description
                    -- ["Custom Tags"] = {}, -- List of separators for Keywords
                    -- ["Description"] = {}, -- List of separators for File
                    -- ["File"] = {}, -- List of separators for File
                    -- ["Genre"] = {}, -- List of separators for File
                    -- ["Keywords"] = {}, -- List of separators for File
                    default = {} -- Default list of separators 示例 default = {" ", ",", ";"}
                },
                containsAllParentDirectories = INCLUDE_PARENT_DIRECTORIES,
            })
    
            if keywords then
                readDBCount = readDBCount + 1
                for v, keyword in pairs(keywords) do
                    table.insert(tTagData, {
                        db = db.name,
                        value = keyword.value,
                        from = keyword.from,
                        fromString = table.concat(table.keys(keyword.from), ", ")
                    })
                end
            end
        end
    end
    
    local file, err = io.open(csvFilePath , "w+")

    if not file then
        print("Error opening file:", err)
        return
    end

    -- 写入CSV头部(取决于tTagData的结构)
    file:write("db,value,from,fromString\n")

    -- 遍历tTagData，将其写入CSV文件
    for _, entry in ipairs(tTagData) do
        local db = entry.db
        local value = entry.value
        local fromString = entry.fromString
    
        -- 如果字段包含逗号，则将其包裹在引号内
        if value:find(",") then
            value = '"' .. value .. '"'
        end
    
        file:write(string.format("%s,%s,%s,%s\n",
            db,
            value,
            table.concat(table.keys(entry.from), ";"),
            fromString
        ))
    end

    -- 关闭文件
    io.close(file)

	-- 从评分文件读取评分信息
	local ratings = jReadTagData(DATA_INI_FILE) -- 确保这是评分信息存储的正确路径

	-- 更新tTagData中的评分信息
	for _, item in ipairs(tTagData) do
		if ratings[item.value] then
			item.rating = tonumber(ratings[item.value].rating) or 0
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

-- 自定义排序函数，针对具有 value 的表结构
function custom_sort(a, b, cn_first)
    local a_key = a.value or "" -- 根据 value 排序
    local b_key = b.value or ""

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

function readReaperFileList(path, processItem)
    local file = io.open(path, "r")
    if not file then return false end
    while true do
        local line = file:read()
        if line == nil then break end
        processItem(line:match("(%w+) (.+)"))
    end
    return true
end

function readReaperFileListAsync(path)
    local file = io.open(path, "r")
    if not file then return end

    local line = file:read()

    local function nextItem()
        if line ~= nil then
            return line:match("(%w+) (.+)")
        end
        line = file:read()
    end

    local function hasNext()
        return line ~= nil
    end

    return hasNext, nextItem
end

function readDataItemEntry(entry)
    return entry:match("(%w+):(.+)")
end

function string.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function string.trimFileExtension(s)
    return (s:gsub("%..+$", ""))
end

function simplifyPath(path)
    local delimiter = path:match("[/%\\]")
    local parts = {}
    for part in path:gmatch("[^/%\\]+") do
        table.insert(parts, part)
    end
    if #parts <= 3 then
        return path
    end
    return table.concat({ parts[1], "...", parts[#parts - 1], parts[#parts] }, delimiter)
end

function table.keys(tab)
    local keys = {}
    for k, _ in pairs(tab) do
        table.insert(keys, k)
    end
    return keys
end

function table.map(tab, f)
    local res = {}
    for k, v in pairs(tab) do
        res[k] = f(v)
    end
    return res
end

function table.arrayToTable(tab)
    local r = {}
	for k, v in ipairs(tab) do
		r[v] = true
	end
	return r
end

function table.bininsert(t, value, fcomp)
    --  Initialise numbers
    local iStart,iEnd,iMid,iState = 1,#t,1,0
    -- Get insert position
    while iStart <= iEnd do
        -- calculate middle
        iMid = math.floor( (iStart+iEnd)/2 )
        -- compare
        if fcomp( value,t[iMid] ) then
        iEnd,iState = iMid - 1,0
        else
        iStart,iState = iMid + 1,1
        end
    end
    table.insert( t,(iMid+iState),value )
    return (iMid+iState)
end

function table.assign(target, source)
    for k, v in pairs(source) do
        target[k] = v
    end
    return target
end

function table.arrayToTable(tab)
    local r = {}
	for k, v in ipairs(tab) do
		r[v] = true
	end
	return r
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

function readViewModelFromReaperFileList(dbPath, config, async)
    config = config or {}
    local excludeOrigin = config.excludeOrigin or {}
    local delimiters = config.delimiters or {}

    local function iteratorOf(origin, source)
        if not delimiters[origin] then
            if not delimiters.default or #delimiters.default == 0 then
                return source:gmatch(".+")
            end
            return source:gmatch("[^" .. table.concat(delimiters.default) .. "]+")
        end
        if #delimiters[origin] == 0 then
            return source:gmatch(".+")
        end
        return source:gmatch("[^" .. table.concat(delimiters[origin]) .. "]+")
    end

    local keywords = {}

    local function processItem(itemType, content)
        if itemType == "FILE" and not excludeOrigin["File"] then
            local p = (parseCSVLine(content, " "))[1]
            local matchPattern = "[^/%\\]+$"
            if config.containsAllParentDirectories then
                matchPattern = "[^/%\\]+"
            end
            for w in p:gmatch(matchPattern) do
                if not w:match("^%w+:$") then
                    local value = w:trimFileExtension()
                    keywords[value] = keywords[value] or { value = value, from = {} }
                    keywords[value].from["File"] = true
                end
            end
        elseif itemType == "DATA" then
            local ok, entries = pcall(parseCSVLine, content, " ")
            if not ok then goto continue end
            for _, entry in ipairs(entries) do
                local k, v = readDataItemEntry(entry)
                if k and v then
                    if k:lower() == 'u' and not excludeOrigin["Custom Tags"] then
                        for w in iteratorOf("Custom Tags", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Custom Tags"] = true
                        end
                    end
                    if k:lower() == 'd' and not excludeOrigin["Description"] then
                        for w in iteratorOf("Description", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Description"] = true
                        end
                    end
                    if  k:lower() == 'b' and not excludeOrigin["Album"] then
                        for w in iteratorOf("Album", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Album"] = true
                        end
                    end
                    if k:lower() == 'c' and not excludeOrigin["Comment"] then
                        for w in iteratorOf("Comment", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Comment"] = true
                        end
                    end
                    if k:lower() == 'g' and not excludeOrigin["Genre"] then
                        for w in iteratorOf("Genre", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Genre"] = true
                        end
                    end
                    if k:lower() == 'k' and not excludeOrigin["Keywords"] then
                        for w in iteratorOf("Keywords", v) do
                            local value = w:trim():trimFileExtension()
                            keywords[value] = keywords[value] or { value = value, from = {} }
                            keywords[value].from["Keywords"] = true
                        end
                    end
                end
            end
        elseif itemType == "USER" and not excludeOrigin["Keywords"] then
            local ok, entries = pcall(parseCSVLine, content, " ")
            if not ok then goto continue end
            if entries[1] then
                if entries[1]:find("IXML:USER:Keywords") and entries[2] then
                    for w in iteratorOf("Keywords", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["Keywords"] = true
                    end
                end
                if entries[1]:find("IXML:USER:CatID") and entries[2] then
                    for w in iteratorOf("CatID", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["CatID"] = true
                    end
                end
                if entries[1]:find("IXML:USER:FXName") and entries[2] then
                    for w in iteratorOf("FXName", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["FXName"] = true
                    end
                end
                if entries[1]:find("IXML:USER:Category") and entries[2] then
                    for w in iteratorOf("Category", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["Category"] = true
                    end
                end
                if entries[1]:find("IXML:USER:SubCategory") and entries[2] then
                    for w in iteratorOf("SubCategory", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["SubCategory"] = true
                    end
                end
                if entries[1]:find("IXML:USER:CategoryFull") and entries[2] then
                    for w in iteratorOf("CategoryFull", entries[2]) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["CategoryFull"] = true
                    end
                end
            end
        end
        ::continue::
    end

    if async then
        local hasNext, _nextItem = readReaperFileList(dbPath)
        local function nextItem()
            return processItem(_nextItem)
        end
        return hasNext, nextItem
    end
    
    if readReaperFileList(dbPath, processItem) then
        return keywords
    end
end

local function PostText(hwnd, str) -- https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-char
    for char in string.gmatch(str, ".") do
        ret = reaper.JS_WindowMessage_Post(hwnd, "WM_CHAR", string.byte(char),0,0,0)
        if not ret then break end
    end
end

function SetExplorerPath(hwnd, folder)
    local cbo = reaper.JS_Window_FindChildByID(hwnd, 1002)
    local edit = reaper.JS_Window_FindChildByID(cbo, 1001)

    if edit then
        reaper.JS_Window_SetTitle(edit, "")
        -- PostText(edit, folder) -- 中文乱码
        reaper.JS_Window_SetTitle(edit, folder)
        -- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
        reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
        reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
        reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE
        reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE
        reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x0D, 0,0,0) -- ENTER
        -- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x0D, 0,0,0) -- ENTER
        -- reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x28, 0,0,0) -- DOWN ARROW
        -- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x28, 0,0,0) -- DOWN ARROW
    end
end

function setReaperExplorerPath(f)
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    SetExplorerPath(hwnd, f)
end

function getReaperExplorerPath()
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local path_hwnd = reaper.JS_Window_FindChildByID(hWnd, 1002)
    return reaper.JS_Window_GetTitle(path_hwnd, "", 255)
end

function table.keys(tab)
    local keyset = {}
    for k, v in pairs(tab) do
        table.insert(keyset, k)
    end
    return keyset
end

function edit_tag(key)
    local titles = {
        "Edit metadata tag",
        "编辑元数据标签",
        "編輯元數據標簽"
    }
    
    local parent = nil
    local title_top = nil

    -- 遍历所有可能的标题，尝试查找窗口
    for _, title in ipairs(titles) do
        title_top = reaper.JS_Localize(title, "common")
        parent = reaper.JS_Window_Find(title_top, true)
        if parent then break end
    end
    
    if parent then
        reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1007), key)
        reaper.JS_Window_OnCommand(parent, 1) -- OK = 1, Cancel = 2
    else
        reaper.defer(function() edit_tag(key) end)
    end
end