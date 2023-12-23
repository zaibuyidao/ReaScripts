-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

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

-- function getPathDelimiter()
--     if package.config:sub(1,1) == '\\' then
--         -- Windows
--         return '\\'
--     else
--         -- Unix/Linux/MacOS
--         return '/'
--     end
-- end

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
	jump_title = "跳转目标"
	jump_title_line = "行数"
	search_title = "过滤"
	search_title_key = "关键词"
	remaining = "剩余: "
elseif language == "繁体中文" then
	jump_title = "跳转目标"
	jump_title_line = "行数"
	search_title = "過濾"
	search_title_key = "關鍵詞"
	remaining = "剩餘: "
else
	jump_title = "Jump"
	jump_title_line = "Ln"
	search_title = "Filter"
	search_title_key = "Keywords"
	remaining = "Rem: "
end

require('REQ.j_file_functions')
require('REQ.JProjectClass')
require('REQ.j_tables')
require('REQ.jGui')
require('REQ.j_trackstatechunk_functions')
require('REQ.j_settings_functions')
require('core')
require('reaper-utils')
LIP = require('LIP')
CONFIG = require('config-database')
ListView = require('ListView')
pinyin = require('pinyin')

setGlobalStateSection("SFX_TAG_SEARCH_DATABASE")

function getConfig(configName, default, convert)
	local cur = CONFIG
	for k in configName:gmatch("[^%.]+") do
		if not cur then return default end
		cur = cur[k]
	end
	if cur == nil then return default end
	if convert then
		return convert(cur)
	end
	return cur
end

function parseCSVLine(line, sep, lineNumber)
    if string.sub(line, 1, 1) == "#" or string.len(line) == 0 then-- 如果行以 # 开头，直接跳过
        return nil
    end

    local res = {}
    local pos = 1
    sep = sep or ','

    -- 增加一个检查分隔符数量的函数
    local function countSeparator(line, sep)
        local count = 0
        for i = 1, string.len(line) do
            if string.sub(line, i, i) == sep then
                count = count + 1
            end
        end
        return count
    end

    -- 检查分隔符数量是否为 1
    if countSeparator(line, sep) ~= 2 then
		local retval
		if language == "简体中文" then
			retval = reaper.MB(string.format("custom_database.csv 自定义关键词格式错误：第 %d 行的分隔符数量不正确。\n请修改自定义关键词文件，并重新启动脚本。\n\n要现在打开 custom_database.csv 吗？", lineNumber), '错误', 1)
		elseif language == "繁体中文" then
			retval = reaper.MB(string.format("custom_database.csv 自訂關鍵詞格式錯誤：第 %d 行的分隔符數量不正確。\n請修改自訂關鍵詞文件，並重新啟動腳本。\n\n要現在打開 custom_database.csv 嗎？", lineNumber), '錯誤', 1)
		else
			retval = reaper.MB(string.format("custom_database.csv custom keyword format error: The number of separators on line %d is incorrect.\nPlease modify the custom keyword file and restart the script.\n\nDo you want to open custom_database.csv now?", lineNumber), 'Error', 1)
		end

		if retval == 1 then
			openUrl(script_path .. "custom_database.csv")
		end
        return false
    end

    while true do
        local c = string.sub(line, pos, pos)
        if (c == "") then
            table.insert(res, "")
            break
        end

        if (c == "`" or c == "'" or c == '"') then
            local quoteChar = c
            local txt = ""
            pos = pos + 1
            while true do
                local startp, endp = string.find(line, quoteChar, pos)
                if not startp then break end
                txt = txt .. string.sub(line, pos, startp - 1)
                pos = endp + 1
                c = string.sub(line, pos, pos)
                if (c == quoteChar) then
                    txt = txt .. quoteChar
                    pos = pos + 1
                else
                    break
                end
            end
            table.insert(res, txt)
            c = string.sub(line, pos, pos)
            if (c == sep) then
                pos = pos + 1
            end
        elseif (c == sep) then
            table.insert(res, "")
            pos = pos + 1
        else
            local startp, endp = string.find(line, sep, pos)
            if (startp) then
                table.insert(res, string.sub(line, pos, startp - 1))
                pos = endp + 1
            else
                table.insert(res, string.sub(line, pos))
                break
            end
        end
    end

    if res[1] == "" then
		if language == "简体中文" then
			reaper.MB("自定义关键词文件格式错误：第一列不能出现空值。\n请按快捷键 F1 打开自定义文件修改关键词内容，并重新启动脚本。", '错误', 0)
		elseif language == "繁体中文" then
			reaper.MB("自訂關鍵詞文件格式錯誤：第一列不能出現空值。\n請按快捷鍵 F1 打開自訂文件修改關鍵詞内容，並重新啓動脚本。", '錯誤', 0)
		else
			reaper.MB("Custom keywords file format error: the first column cannot have empty values. \nPlease press the F1 shortcut key to open the custom file and modify the keywords content, then restart the script.", 'Error', 0)
		end

        return false
    else
        return res
    end
end

-- 判断字符是否为中文
function is_chinese_char(char)
	local utf8_value = string.byte(char)
	return utf8_value >= 0xE0 and utf8_value <= 0xEF
end

function get_pinyin(text)
	return pinyin(text, true, "") -- 使用空字符串作为连接符
end

function custom_sort(a, b, cn_first) -- 根据cn_first参数决定中英文顺序
	local a_key = a.key or ""
	local b_key = b.key or ""

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

SIZE_UNIT = getConfig("ui.global.size_unit", 20)

function readFromCSV(csvFilePath)
    local data = {}
    local file = io.open(csvFilePath, "r")
    
    if not file then
        print("Cannot open the CSV file!")
        return nil
    end
    
    file:read("*l") -- 跳过标题行

    for line in file:lines() do
        local key, name, remark = line:match("([^,]*),([^,]*),([^,]*)")
        table.insert(data, {
            key = key,
            name = name,
            remark = remark
        })
    end
    
    io.close(file)
    
    return data
end

dbList = getDbList()
if dbList == false then return end

-- 实时创建数据库列表版本
local data = {}
local excludeTpName = getConfig("tp.exclude_tp", {}, table.arrayToTable)

for _, db in ipairs(dbList) do
	local dbType = db.name:find("^GP:") and "GROUP" or db.name:find("^FD:") and "FOLDER" or "DATABASE"
	if not excludeTpName[dbType] then
		local modifiedName = db.name:gsub('"', '')
		table.insert(data, {
			key = modifiedName,
			name = "",  -- 预留空列
			remark = dbType
		})
	end
end

-- 创建 custom_database.csv 版本
-- local csvFilePath = script_path .. getPathDelimiter() .. "custom_database.csv"
-- local data = {}
-- local csvFile = io.open(csvFilePath, "r")

-- -- 检查是否已存在 custom_database.csv 文件
-- if csvFile then
--     io.close(csvFile)
--     -- 如果文件已存在，则读取内容
--     data = readFromCSV(csvFilePath)
-- else
--     -- 如果文件不存在，则遍历数据库列表并创建新的 custom_database.csv 文件
--     local excludeDbName = getConfig("db.exclude_db", {})
    
--     for _, db in ipairs(dbList) do
--         if not excludeDbName[db.name] then
--             local dbType = db.name:find("^GP:") and "Group" or "Database"
--             local modifiedName = db.name:gsub('"', '')
--             table.insert(data, {
--                 key = modifiedName,
--                 name = "",  -- 预留空列
--                 remark = dbType
--             })
--         end
--     end

--     -- 打开 custom_database.csv 文件进行写入
--     local file, err = io.open(csvFilePath , "w+")
--     if file then
--         -- 写入 CSV 头部
--         file:write("key,name,remark\n")

--         -- 遍历 data 数组，将其内容写入 CSV 文件
--         for _, entry in ipairs(data) do
--             file:write(string.format("%s,%s,%s\n", entry.key, entry.name, entry.remark))
--         end

--         -- 关闭文件
--         io.close(file)
--     else
--         print("Error creating file:", err)
--         return
--     end
-- end

if sortResult then
	table.sort(data, function(a, b)
		local cnFirst = getConfig("search.cn_first")
		if cnFirst == true or cnFirst == false then
			return custom_sort(a, b, cnFirst)
		else
			return string.lower(tostring(a.key)) < string.lower(tostring(b.key))
		end
	end)
end

local colorMap = getConfig("ui.result_list.remark_color", {})
local defaultColors = getConfig("ui.result_list.default_colors", {{.6, .6, .6, 1}})
local nextColor = 1

function getColorForRemark(remark)
	if colorMap[remark] then return jColor:new(colorMap[remark]) end
	colorMap[remark] = defaultColors[nextColor]
	nextColor = (((nextColor + 1) - 1) % #defaultColors) + 1
	return jColor:new(colorMap[remark])
end

function string.isEmpty(s)
	return s == nil or #s == 0
end

function string.contains(s, value, caseSensitive)
	if s == nil then
		return false
	end
	if caseSensitive then
		return s:find(value)
	end
	return s:lower():find(value:lower())
end

function set_explorer_path(hwnd, folder)
	local combo_box = reaper.JS_Window_FindChildByID(hwnd, 1002)
	local edit = reaper.JS_Window_FindChildByID(combo_box, 1001)
	-- https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
	reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0,0,0) -- SPACE 模拟用户按下空格键
	reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE 模拟用户按下退格键
	reaper.JS_Window_SetTitle(edit, "")
	reaper.JS_Window_SetTitle(edit, folder)
	reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x0D, 0,0,0) -- ENTER 模拟用户按下回车键
	-- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x0D, 0,0,0) -- ENTER
end

function set_reaper_explorer_path(f)
	local title = reaper.JS_Localize("Media Explorer", "common")
	local hwnd = reaper.JS_Window_Find(title, true)
	set_explorer_path(hwnd, f)
end

function searchKeyword(value, rating) -- 过滤搜索
	local res = {}
	local caseSensitive = getConfig("search.case_sensitive")
	local includeName = getConfig("search.include_name")
	local includeRemark = getConfig("search.include_remark")
	local sortResult = getConfig("search.sort_result")
	local keywords = string.split(value, " ") -- 分割关键词

	for i, item in ipairs(data) do
		local match = true
		for _, keyword in ipairs(keywords) do
			if not (string.contains(item.key, keyword, caseSensitive)
			or (includeName and string.contains(item.name, keyword, caseSensitive))
			or (includeRemark and string.contains(item.remark, keyword, caseSensitive))) then
			match = false
			break
	end
		end
		if match then
			table.insert(res, item)
		end
	end
	if sortResult then
		table.sort(res, function(a, b)
			local cnFirst = getConfig("search.cn_first")
			if cnFirst == true or cnFirst == false then
				return custom_sort(a, b, cnFirst)
			else
				return string.lower(tostring(a.key)) < string.lower(tostring(b.key))
			end
		end)
	end

	return res
end

function reloadDataAndUpdateUI()
	local dbList = getDbList()
	if dbList == false then return end
	
	-- 实时创建数据库列表版本
	local data = {}
	local excludeTpName = getConfig("tp.exclude_tp", {}, table.arrayToTable)
	
	for _, db in ipairs(dbList) do
		local dbType = db.name:find("^GP:") and "GROUP" or db.name:find("^FD:") and "FOLDER" or "DATABASE"
		if not excludeTpName[dbType] then
			-- 移除 db.name 中的引号，并用方括号包围
			local modifiedName = db.name:gsub('"', '')
			table.insert(data, {
				key = modifiedName,
				name = "",  -- 预留空列
				remark = dbType
			})
		end
	end

    local sortResult = getConfig("search.sort_result")
	if sortResult then
		table.sort(data, function(a, b)
			local cnFirst = getConfig("search.cn_first")
			if cnFirst == true or cnFirst == false then
				return custom_sort(a, b, cnFirst)
			else
				return string.lower(tostring(a.key)) < string.lower(tostring(b.key))
			end
		end)
	end

    if data and #data > 0 then
        resultListView.data = data
        refreshResultState()
        -- print("resultListView data updated and UI refreshed.")
    else
        print("No data to display.")
    end
end

resultListView = nil

function init()
	JProject:new()
	window = jGui:new({
        title = getConfig("ui.window.title"),
        width = getState("WINDOW_WIDTH", getConfig("ui.window.width"), tonumber),
        height = getState("WINDOW_HEIGHT", getConfig("ui.window.height"), tonumber),
        x = getState("WINDOW_X", getConfig("ui.window.x"), tonumber),
        y = getState("WINDOW_Y", getConfig("ui.window.y"), tonumber),
        dockstate = getState("WINDOW_DOCK_STATE"),
		background_color = getConfig("ui.window.background_color", 0, function (t) return t.r+t.g*256+t.b*65536 end)
    })
	
	local lastSearchText

	local searchTextBox = jGuiTextInput:new()
	table.assign(searchTextBox, {
		x = 10,
		y = 10,
		width = 480,
		height = math.floor( SIZE_UNIT * 1.5 ),
		label_fontsize = math.floor( SIZE_UNIT * 1.5 ), -- 搜索框字体大小
		label_align = "l",
		border_focus = getConfig("ui.search_box.border_focus", searchTextBox.border_focus),
		label_font = getConfig("ui.global.font", "微软雅黑"),
		carret_color = getConfig("ui.search_box.carret_color", searchTextBox.carret_color),
		colors_label = getConfig("ui.search_box.colors_label") or searchTextBox.colors_label,
		color_focus_border = getConfig("ui.search_box.color_focus_border") or searchTextBox.color_focus_border,
		focus_index = window:getFocusIndex(),
		label_padding = 3
	})
	function searchTextBox:onRightMouseClick() -- Alt+右键单击 清空 Media Explorer 的搜索框
		if self.parentGui.kb:alt() then
			set_reaper_explorer_path(" ")
		else
			self.value = ""
			self.label = ""
		end
	end
	window:controlAdd(searchTextBox)

	local stateLabel = jGuiControl:new()
	table.assign(stateLabel, {
		width = SIZE_UNIT * 2.5,
		x = window.width - stateLabel.width - 12,
		y = 10,
		label_fontsize = math.floor(SIZE_UNIT * 0.75), -- 右上角状态字体大小
		label_align = "r",
		label_font = getConfig("ui.global.font", "微软雅黑"),
		border = getConfig("ui.search_box.state_label.border", false),
		colors_label = getConfig("ui.search_box.state_label.colors_label") or stateLabel.colors_label,
		label = "()"
	})
	window:controlAdd(stateLabel)
	
	window:setFocus(searchTextBox)

	jGuiHighlightControl = jGuiControl:new({highlight = {}, color_highlight = getConfig("ui.result_list.color_highlight", {1, .9, 0, .2}),})
	function jGuiHighlightControl:_drawLabel()
		gfx.setfont(1, self.label_font, self.label_fontsize)
		self:__setLabelXY()
	
		if self.highlight and #self.highlight > 0 then
			for _, word in pairs(self.highlight) do
				if word and word ~= "" then
					local parts, r = jStringExplode(self.label, word, true)
					local totalX = 0
					if #parts>1 then
						local highLightW, highLightH = gfx.measurestr(word)
						for i = 1, #parts - 1 do -- do all but the last
							local noLightW, noLightH = gfx.measurestr(parts[i])
							-- Draw highlight
							self:__setGfxColor(self.color_highlight)
							gfx.rect(gfx.x + totalX + noLightW, gfx.y, highLightW + 1, highLightH, 1)
	
							totalX = totalX + noLightW + highLightW
						end
						-- tablePrint(parts)
					end
				end
			end
		end
		self:_setStateColor()
		gfx.drawstr(tostring(self.label))
	end

	resultListView = ListView.new({
		window = window,
		x = 10,
		y = SIZE_UNIT * 1.5 + 15,
		height = window.height - (SIZE_UNIT * 1.5 + 15) - 4,
		itemHeight = SIZE_UNIT,

		onCreateViewHolder = function(listView, x, y)
			local c = jGuiHighlightControl:new()
			c.height = listView.itemHeight
			c.width = window.width - 20
			c.label_fontsize = listView.itemHeight - 2 -- 列表字体大小
			c.label_align = "l"
			c.label_font = getConfig("ui.global.font", "微软雅黑") -- "Calibri"
			c.color_focus_border = getConfig("ui.result_list.color_focus_border", c.color_focus_border)
			c.border = false
			c.border_focus = true
			c.x = x
			c.y = y

			local info = jGuiText:new()
			info.width = 40
			info.height = listView.itemHeight
			info.label_fontsize = listView.itemHeight - 2 -- math.floor((listView.itemHeight-2) / 2 + 5) -- 列表字体大小
			info.label_font = getConfig("ui.global.font", "微软雅黑") -- "Calibri"
			info.label_align = "r"
			info.label_valign = "m"
			info.border = false
			info.y = c.y

			function c:onMouseWheel(mw) -- it looks like SCROLL_RESULTS can be a value between 0 and 1, should be a whole number?
				listView:scroll(mw/120 * -1)
			end

			function c:onArrowDown()
				return c:onTab()
			end

			function c:onArrowUp()
				return c:onShiftTab()
			end

			function c:onKeyboard(key)
				if onKeyboardGlobal then
					onKeyboardGlobal(key)
				end
			end

			-- function c:onShiftTab()
			-- 	if self.i == 1 and listView.firstIndex ~= 1 then
			-- 		listView:scroll(-1)
			-- 		return false
			-- 	end
			-- 	return true -- else
			-- end

			-- function c:onTab()
			-- 	if self.i == #viewHolders then
			-- 		listView:scroll(1)
			-- 		return false
			-- 	end
			-- 	return true -- else
			-- end

			window:controlAdd(c)
			window:controlAdd(info)

			return { c, info }
		end,
		onViewHolderRemoved = function (viewHolder)
			window:controlDelete(viewHolder[1])
			window:controlDelete(viewHolder[2])
		end,
		onBindData = function(listView, viewHolderIndex, dataIndex)
			local c = listView.viewHolders[viewHolderIndex][1]
			local info = listView.viewHolders[viewHolderIndex][2]
			local data = listView.data[dataIndex]
			local currentKey = data.key
			c.width = window.width - 20
			info.x = 10 + c.width - info.width

			if string.isEmpty(data.name) then
				c.label = listView.data[dataIndex].key
			elseif getConfig("ui.result_list.include_key", false) then
				c.label = listView.data[dataIndex].key .. " (" .. listView.data[dataIndex].name .. ")"
			else
				c.label = listView.data[dataIndex].name
			end
			
			info.label = listView.data[dataIndex].remark
			c.highlight = jStringExplode(searchTextBox.value, " ") -- 高亮不包含空格

			local color = getColorForRemark(data.remark)
			c.colors_label = {}
			c.colors_label.normal = color
			c.colors_label.hover = color:lighter(0.2)
			info.colors_label = color

			c.focus_index = viewHolderIndex + 1 --gui:getFocusIndex()

			function edit_tag1(key) -- common无法被准确识别
				local title_top = reaper.JS_Localize("Edit metadata tag", "common")
				local parent = reaper.JS_Window_Find(title_top, true)
				
				if parent then
					reaper.JS_Window_SetTitle(reaper.JS_Window_FindChildByID(parent, 1007), key)
					reaper.JS_Window_OnCommand(parent, 1) -- OK = 1, Cancel = 2
				else
					reaper.defer(function() edit_tag(key) end)
				end
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

			function c:onMouseClick()
				if self.parentGui.kb:shift() then -- Shift+左键点击 发送第二个值
					if data.name == "" then return end
					reaper.defer(function ()
						set_reaper_explorer_path(data.name or "")
					end)
					return
				elseif self.parentGui.kb:control() then -- Control+左键点击
					reaper.CF_SetClipboard(data.key)
					return
				end
				reaper.defer(function ()
					set_reaper_explorer_path(data.key)
				end)
			end

			-- function c:onRightMouseClick()
			-- 	edit_tag(currentKey)
			-- 	reaper.JS_WindowMessage_Post(reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true), "WM_COMMAND", 42053, 0, 0, 0) -- Edit metadata tag: Custom Tags
			-- end
		end
	})

	function onKeyboardGlobal(key)
		if key == 1818584692 or key == 1885828464 then
			-- print("page up")
			resultListView:scroll(0-getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		elseif key == 1919379572 or key == 1885824110 then
			-- print("page down")
			resultListView:scroll(getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		-- elseif key == 26161 then --编辑关键词 f1
		-- 	openUrl(script_path .. "custom_database.csv")
		elseif key == 26162 then --编辑配置表 f2
			openUrl(script_path .. "lib/config-database.lua")
		elseif key == 26163 then --随机行 f3
			resultListView:randomJump()
		elseif key == 26164 then --跳转目标 f4
			resultListView:promptForJump()
		elseif key == 26165 then --F5 刷新列表
			if resultListView then
				reloadDataAndUpdateUI()
			else
				print("Error: resultListView is not initialized.")
			end
		elseif key == 26166 then --F6 删除 custom_database.csv 文件
			-- local csvFilePath = script_path .. getPathDelimiter() .. "custom_database.csv"

			-- if language == "简体中文" then
			-- 	err1 = "custom_database.csv 文件已被删除。重新启动脚本将会创建最新的 custom_database.csv 文件。"
			-- 	err2 = "文件已删除"
			-- 	err3 = "该操作将删除 " ..csvFilePath .." 文件！"
			-- 	err4 = "警告"
			-- elseif language == "繁体中文" then
			-- 	err1 = "custom_database.csv 文件已被刪除。重新啓動脚本將會創建最新的 custom_database.csv 文件。"
			-- 	err2 = "文件已刪除"
			-- 	err3 = "該操作將會刪除 " ..csvFilePath .." 文件！"
			-- 	err4 = "警告"
			-- else
			-- 	err1 = "The 'custom_database.csv' file has been deleted. Restarting the script will create the latest custom_database.csv file."
			-- 	err2 = "File Deleted"
			-- 	err3 = "This action will delete  " ..csvFilePath .." !"
			-- 	err4 = "Warning"
			-- end

			-- local retval = reaper.ShowMessageBox(err3, err4, 1)
			-- if retval == 1 then
			-- 	os.remove(csvFilePath)
			-- 	-- 显示消息框
			-- 	reaper.MB(err1, err2, 0)
			-- end

		elseif key == 6697265 then --过滤关键词 f11
			reaper.Main_OnCommand(50124, 0) -- Media explorer: Show/hide media explorer
		elseif key == 6697266 then --过滤关键词 f12
			searchTextBox:promptForContent()
		elseif key == 1752132965 then --HOME
			resultListView:jump(1)
		elseif key == 6647396 then --END
			if resultListView.data and #resultListView.data > 0 then
				resultListView:jump(#resultListView.data)
			end
		elseif key == 30064 then --arrow up
			resultListView:jump(resultListView.firstIndex - 1)
		elseif key == 1685026670 then --arrow down
			resultListView:jump(resultListView.firstIndex + 1)
		end
	end

	function resultListView:promptForJump()
		local args = prompt({
			title = jump_title,
			inputs = {
				{
					label = jump_title_line .. ",extrawidth=100",
					default = self.value,
					converter = tonumber
				}
			}
		})
		-- if args then
		-- 	self:jump(args[1]) -- 以界面最顶部作为目标行
		-- end
		if args then -- 以界面底部作为目标行
			local targetLine = args[1]
			local compensation = resultListView:getPageSize() - 1
			local adjustedTargetLine = targetLine - compensation
			self:jump(adjustedTargetLine)
		end
		return 
	end

	function resultListView:randomJump()
		if self.data and #self.data > 1 then
			self:jump(math.random(1, #self.data))
		end
	end

	function searchTextBox:promptForContent()
		local args = prompt({
			title = search_title,
			inputs = {
				{
					label = search_title_key .. ",extrawidth=100",
					default = self.value
				}
			}
		})
		if args then
			-- print(string.byte(args[1], 1, #args[1]))
			self.value = args[1]
			self.label = self.value
			self:__setCarretPos(#self.value)
			self:_draw()
		end
		reaper.defer(function()
			window:setFocus(searchTextBox)
			window:setReaperFocus()
		end)
	end

	function searchTextBox:onKeyboard(key)
		onKeyboardGlobal(key)
	end

	function searchTextBox:onMouseClick(x, y)
		local last_click_clock = self.last_click_clock
		self.last_click_clock = os.clock()
		if last_click_clock and self.last_click_clock - last_click_clock < 1 then
			self:onMouseDoubleClick(x, y)
			return
		end
		if self.kb:alt() then
			searchTextBox.value = ""
			searchTextBox.label = ""
			return 
		end

		if self.kb:control() then
			searchTextBox:promptForContent()
		end
	end

	function searchTextBox:onMouseDoubleClick(x, y)
		self:promptForContent()
	end

	resultListView:addScrollListener(function ()
		--stateLabel.label = "(" .. resultListView.firstIndex .. "/" .. #resultListView.data .. ")" -- 滚动条以界面最顶部作为目标行计数
		if resultListView.firstIndex + resultListView:getPageSize()-1 > #resultListView.data then
			stateLabel.label = "(" .. #resultListView.data .. "/" .. #resultListView.data .. ")"
		else
			stateLabel.label = "(" .. resultListView.firstIndex + resultListView:getPageSize()-1 .. "/" .. #resultListView.data .. ")"
		end
	end)

	function window:onResize()
		searchTextBox.width = self.width - 20
		stateLabel.x = window.width - stateLabel.width - 12
		resultListView.height = window.height - (SIZE_UNIT * 1.5 + 15) - 4
		resultListView:draw()
		refreshResultState() -- 每次窗口大小发生变化时，stateLabel.label 都会根据新的 resultListView:getPageSize() 值进行更新
		self:controlInitAll()
	end

	local remain = 0

	function refreshResultState()
		resultListView:draw()
		--stateLabel.label = "(" .. resultListView.firstIndex .. "/" .. #resultListView.data .. ")" -- 滚动条以界面最顶部作为目标行计数
		if resultListView.firstIndex + resultListView:getPageSize()-1 > #resultListView.data then
			stateLabel.label = "(" .. #resultListView.data .. "/" .. #resultListView.data .. ")"
		else
			stateLabel.label = "(" .. resultListView.firstIndex + resultListView:getPageSize()-1 .. "/" .. #resultListView.data .. ")"
		end
		if remain > 0 then
			stateLabel.label = stateLabel.label .. remaining .. remain
		end
	end

	function startSearch(value)
		resultListView.firstIndex = 1
		resultListView.data = searchKeyword(searchTextBox.value)
		refreshResultState()
	end

	function window:update()
		if lastSearchText ~= searchTextBox.value then
			lastSearchText = searchTextBox.value
			startSearch(lastSearchText)
		end
	end
	
	function window:onExit()
		local dockstate, wx, wy, ww, wh = gfx.dock(-1, 0, 0, 0, 0)
		local dockstr = string.format("%d", dockstate)
		setState({
			WINDOW_WIDTH = math.tointeger(ww),
			WINDOW_HEIGHT = math.tointeger(wh),
			WINDOW_X = math.tointeger(wx),
			WINDOW_Y = math.tointeger(wy),
			WINDOW_DOCK_STATE = dockstr,
		})
	end

	window:onResize()
	window:init()
	window:controlInitAll()

	return true
end

function loop()
	if window:loop() then 
		reaper.defer(loop)
	else
		gfx.quit()
	end
end

if init() then
	window:setReaperFocus()
	loop()

	if reaper.JS_Window_FindEx then
		local hwnd = reaper.JS_Window_Find(getConfig("ui.window.title"), true)
		if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
	end
end