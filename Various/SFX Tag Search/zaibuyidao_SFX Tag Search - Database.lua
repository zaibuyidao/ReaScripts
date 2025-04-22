-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require ('req.j_file_functions')
require ('req.JProjectClass')
require ('req.j_tables')
require ('req.jGui')
require ('req.j_trackstatechunk_functions')
require ('req.j_settings_functions')
require ('lib.core_database')
pinyin = require('lib.pinyin')
LIP = require('LIP')

local delimiter = getPathDelimiter()
local language = getSystemLanguage()

-- SOME SETUP
SETTINGS_BASE_FOLDER = script_path
SETTINGS_INI_FILE = script_path .. "config-database.ini"
SETTINGS_DEFAULT_FILE = script_path .. "lib/config-database-default.ini"

if language == "简体中文" then
	SFX_TAG_TITLE = "音效标签搜索器: 数据库 (Script by 再補一刀)"
	MEDIA_EXPLORER_NOT_OPEN = "媒体资源管理器未打开。"
	INPUT_TITLE = "过滤器"
	INPUT_CAPTION = "标签:"
	FIRST_TIME_MSG = "未找到数据库。请创建数据库以继续。"
	FIRST_TIME_TITLE = "错误"
elseif language == "繁體中文: 數據庫" then
	SFX_TAG_TITLE = "音效標簽搜索器 (Script by 再補一刀)"
	MEDIA_EXPLORER_NOT_OPEN = "媒體資源總管未打開。"
	INPUT_TITLE = "過濾器"
	INPUT_CAPTION = "標簽:"
	FIRST_TIME_MSG = "未找到數據庫。請創建數據庫以繼續。"
	FIRST_TIME_TITLE = "錯誤"
else
	SFX_TAG_TITLE = "SFX Tag Search: Database (Script by zaibuyidao)"
	MEDIA_EXPLORER_NOT_OPEN = "Media Explorer is not opened."
	INPUT_TITLE = "Filter"
	INPUT_CAPTION = "Tags:"
	FIRST_TIME_MSG = "No database found. Please create a database to continue."
	FIRST_TIME_TITLE = "Error"
end

-- 10组高亮文本颜色
accent_text_color_01 = jColor:new({0.6, 0.6, 0.6, 1})
accent_text_color_02 = jColor:new({0.8, 0.8, 0.5, 1})
accent_text_color_03 = jColor:new({0.5, 0.5, 0.8, 1})
accent_text_color_04 = jColor:new({0.5, 0.7, 0.5, 1})
accent_text_color_05 = jColor:new({0.7, 0.5, 0.5, 1})
accent_text_color_06 = jColor:new({0.5, 0.5, 0.7, 1})
accent_text_color_07 = jColor:new({0.5, 0.7, 0.7, 1})
accent_text_color_08 = jColor:new({0.8, 0.5, 0.5, 1})
accent_text_color_09 = jColor:new({0.9, 0.6, 0.2, 1})
accent_text_color_10 = jColor:new({0.4, 0.3, 0.2, 1})

local themes = {
	default = {
		theme_background = { 220, 222, 222 }, -- 背景颜色
		cursor_focus_border = {70/255, 97/255, 104/255, .5}, -- 光标聚焦颜色
		default_text_color = {36/255, 43/255, 43/255, 1}, -- 默认文本颜色
		text_box_label_normal = {36/255, 43/255, 43/255, 0.8}, -- 文本框文字正常
		text_box_label_hover = {.4, .4, .4, 1}, -- 文本框文字悬停
		text_box_label_focus = {30/255, 34/255, 34/255, 1}, -- 文本框文字聚焦
		text_box_label_active = {30/255, 34/255, 34/255, 1}, -- 文本框文字激活
		text_box_background = {222/255, 224/255, 224/255, 1}, -- 文本框背景颜色
		text_box_border = {0/255, 103/255, 192/255, .3}, -- 文本框边框颜色
		text_box_carret = {30/255, 34/255, 34/255, 1}, -- 文本框光标颜色
		text_highlight = {37/255, 70/255, 110/255, .5}, -- 高亮过滤词
	},
	imgui = {
		theme_background = { 18, 18, 18 }, -- 背景颜色
		cursor_focus_border = {57/255, 124/255, 204/255, .5}, -- 光标聚焦颜色
		default_text_color = {215/255, 215/255, 215/255, 1}, -- 默认文本颜色
		text_box_label_normal = {215/255, 215/255, 215/255, 1}, -- 文本框文字正常
		text_box_label_hover = {.8, .8, .8, 1}, -- 文本框文字悬停
		text_box_label_focus = {215/255, 215/255, 215/255, 1}, -- 文本框文字聚焦
		text_box_label_active = {215/255, 215/255, 215/255, 1}, -- 文本框文字激活
		text_box_background = {31/255, 48/255, 74/255, .5}, -- 文本框背景颜色
		text_box_border = {31/255, 48/255, 74/255, .1}, -- 文本框边框颜色
		text_box_carret = {.8, .8, .8, 1}, -- 文本框光标颜色
		text_highlight = {43/255, 76/255, 116/255, 1}, -- 高亮过滤词
	},
	n0ne = {
		theme_background = { 51, 51, 51 }, -- 背景颜色
		cursor_focus_border = {1, .9, 0, .5}, -- 光标聚焦颜色
		default_text_color = {.8, .8, .8, .8}, -- 默认文本颜色
		text_box_label_normal = {.8, .8, .8, .8}, -- 文本框文字正常
		text_box_label_hover = {.8, .8, .8, 1}, -- 文本框文字悬停
		text_box_label_focus = {.5, .5, .5, 1}, -- 文本框文字聚焦
		text_box_label_active = {1, .9, 0, .5}, -- 文本框文字激活
		text_box_background = {.5, .5, .5, .2}, -- 文本框背景颜色
		text_box_border = {1, 1, 0, 0.2}, -- 文本框边框颜色
		text_box_carret = {1, .9, .5, 1}, -- 文本框光标颜色
		text_highlight = {1, .9, 0, .2}, -- 高亮过滤词
	}
}

function setTheme(themeName)
	local theme = themes[themeName]
	if not theme then
		print("Theme not found: " .. themeName)
		return
	end

	theme_background = theme.theme_background
	cursor_focus_border = jColor:new(theme.cursor_focus_border)
	default_text_color = jColor:new(theme.default_text_color)
	text_box_background = theme.text_box_background
	text_box_label_normal = theme.text_box_label_normal
	text_box_label_hover = theme.text_box_label_hover
	text_box_label_focus = theme.text_box_label_focus
	text_box_label_active = theme.text_box_label_active
	text_box_carret = theme.text_box_carret
	text_box_border = theme.text_box_border
	text_highlight = theme.text_highlight
end

function set_explorer_path(hwnd, folder)
	local cbo = reaper.JS_Window_FindChildByID(hwnd, 1002)
	local edit = reaper.JS_Window_FindChildByID(cbo, 1001)

	if edit then
		reaper.JS_Window_SetTitle(edit, "")
		reaper.JS_Window_SetTitle(edit, folder)
		-- -- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
		reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
		reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x20, 0, 0, 0) -- SPACEBAR
		reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x08, 0, 0, 0) -- BACKSPACE
		reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE
		reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x0D, 0,0,0) -- ENTER
		-- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x0D, 0,0,0) -- ENTER
		-- reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x28, 0,0,0) -- DOWN ARROW
		-- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x28, 0,0,0) -- DOWN ARROW
	end
end

function set_reaper_explorer_path(f)
	local title = reaper.JS_Localize("Media Explorer", "common")
	local hwnd = reaper.JS_Window_Find(title, true)
	set_explorer_path(hwnd, f)
end

function msg(m)
	return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function jTooltip(str)
	local x, y = reaper.GetMousePosition()
	reaper.TrackCtl_SetToolTip(str, x + 10, y + 10, true)
end

function isMediaExplorerOpen()
	-- Command ID for Media Explorer is 50124
	return reaper.GetToggleCommandState(50124) == 1
end

function jWriteTagData(file_name, t)
	-- Write extended tag usage data
	local sContent = ""
	
	for i, l in ipairs(t) do -- this prolly doesn't have to write 0 ratings as that is the default...
		if not l.action then -- for now don't store action ratings
			sContent = sContent .. l.name .. "," .. l.rating .. "\n"
		end
	end
	
	local file = io.open(file_name, "w")
	file:write(sContent)
	file:close()
end

function jReadTagData(file_name)
    -- Reads extended tag usage data
    local tagData = {}
    local file = io.open(file_name, "r")  -- 尝试读取文件
    if not file then 
        return tagData  -- 如果文件不存在，则返回空的数据表
    end

    -- 如果文件存在，继续读取数据
    for line in file:lines() do
        local tagName, tagRating = line:match("(.+),(.+)")
        if tagName and tagRating then
            tagData[tagName] = {rating = tonumber(tagRating)}
        end
    end
    file:close()  -- 关闭文件
    return tagData
end

function findTag(tagTable, sPattern, iInstance, iMaxResults, find_plain)
	local iInstance = iInstance or false
	local find_plain = find_plain or true
	local iMaxResults = iMaxResults or false

	local tResult = {}
    local iCount = 0

	if type(iInstance) == "number" and iInstance <= 0 then 
		jError("findTag(), instance <= 0. First instance is 1! iInstance: " .. tostring(iInstance), J_ERROR_ERROR) 
		return false
	end	

	for i, t in ipairs(tagTable) do
		local bMatch = true
		for token in string.gmatch(sPattern, "[^%s]+") do
			local name = t.name or ""  -- 确保name不为nil
			local alias = t.alias or ""
			local type = t.type or ""
			token = token:lower()

			if token:sub(1, 1) == "@" then  -- 如果token以@开头
				-- local filterAtType = token:sub(2):gsub("_", " ")  -- 获取@后面的文本并将下划线转换回空格
				-- -- 检查类型是否匹配，这里忽略大小写进行匹配
				-- if not (t.type and t.type:lower() == filterAtType) then
				-- 	bMatch = false
				-- 	break
				-- end

				local filterAtType = token:sub(2)
				-- 预处理输入，将下划线和空格统一替换为特定的占位符，这里用下划线作为占位符
				filterAtType = filterAtType:gsub("[ _]", "_")
				-- 预处理类型字段，同样将空格替换为下划线
				local processedType = type:gsub(" ", "_"):lower()
				-- 检查类型是否匹配，这里忽略大小写进行匹配
				if not (processedType == filterAtType:lower()) then
					bMatch = false
					break
				end
			else
				token = token:gsub("\\@", "@") -- 替换转义的'@'

				-- 当两者都关闭时，默认为两者都开
				if not FILTER_NAME and not FILTER_ALIAS and FILTER_CATEGORY then
					FILTER_NAME, FILTER_ALIAS = true, true
				end

				-- 根据开关状态匹配name或alias或两者
				if FILTER_NAME and FILTER_ALIAS and FILTER_CATEGORY then
					bMatch = name:lower():find(token, 1, true) or alias:lower():find(token, 1, true) or type:lower():find(token, 1, true)
				elseif FILTER_NAME and FILTER_ALIAS and not FILTER_CATEGORY then
					bMatch = name:lower():find(token, 1, true) or alias:lower():find(token, 1, true)
				elseif FILTER_NAME and not FILTER_ALIAS and not FILTER_CATEGORY then
					bMatch = name:lower():find(token, 1, true)
				elseif FILTER_ALIAS and not FILTER_NAME and not FILTER_CATEGORY then
					bMatch = alias:lower():find(token, 1, true)
				elseif FILTER_CATEGORY and not FILTER_NAME and not FILTER_ALIAS then
					bMatch = type:lower():find(token, 1, true)
				end

				if not bMatch then
					break
				end
			end
		end

		if bMatch then
			iCount = iCount + 1
			if iInstance == false then
				t.id = i -- keep track of position in main table
				tResult[#tResult + 1] = t
				if iMaxResults == 0 then iMaxResults = false end
				if iMaxResults ~= false then
					if #tResult >= iMaxResults then -- check if we already heave enough results
						return tResult
					end
				end
			elseif iInstance == iCount then
				return t
			end
		end
	end

	-- 如果没有指定实例编号，返回匹配的结果集
	if not iInstance then
		if #tResult == 0 then
			return {} -- Used to return false but should be empty table
		else
			return tResult
		end
	else
    	-- 指定的实例编号没有找到匹配项
		return false
	end
end

function _jScroll(amount)
	SCROLL_RESULTS = SCROLL_RESULTS + amount
	local maxScroll = RESULT_COUNT - RESULTS_PER_PAGE
	if SCROLL_RESULTS > maxScroll then SCROLL_RESULTS = maxScroll end
	if SCROLL_RESULTS < 0 then SCROLL_RESULTS = 0 end
	UPDATE_RESULTS = true
end

function createResultButtons(gui, tControls, n, height, y_start)
	local x_start = 10
	local y_space = 0
	local n_to_remove = 0
	
	for i = 1, math.max(#tControls, n) do
		if i > #tControls and i <= n then
			local c = jGuiHighlightControl:new()
			c.height = height
			c.label_fontsize = height - 2
			c.label_align = "l"
			c.label_font = DEFALUT_FONT -- "Calibri"
			c.color_focus_border = cursor_focus_border -- 选中项颜色
			c.border = false
			c.focus_index = i+1 --gui:getFocusIndex()
			c.border_focus = true

			c.x = x_start
			c.y = y_start + (i-1) * (c.height + y_space)
			
			local info = jGuiText:new()
			info.width = 40
			info.height = height
			info.label_fontsize = math.floor( ((height-2) / 2 + FONT_SIZE_ADJUSTMENT) + 0.5 ) -- math.tointeger( (height-2) / 2 + 3)
			info.label_font = DEFALUT_FONT
			info.label_align = "r"
			info.label_valign = "m"
			info.border = false
			info.y = c.y
			
			function c:onMouseClick()
				local fx = tSearchResults[self.fxIndex]  -- 使用self.fxIndex来访问对应的FX条目
				if fx then
					local name = fx.name
					local alias = fx.alias
					local type = fx.type
					local rating = fx.rating
					if UPDATE_RATINGS then
						fx.rating = fx.rating + 1  -- 增加评分
					end

					if not isMediaExplorerOpen() then return jTooltip(MEDIA_EXPLORER_NOT_OPEN) end
					
					if gui.kb.shift() then
						
						if alias == "" then return end
						reaper.defer(function ()
							set_reaper_explorer_path(alias or "")
						end)
						return
					elseif gui.kb.control() then
						--send_search_text(name .. " ".. alias)
					elseif gui.kb.alt() then
						-- reaper.CF_SetClipboard(name)
					else
						reaper.defer(function ()
							set_reaper_explorer_path(name or "")
						end)
					end
				end

				-- returnValue = selectFx(i + SCROLL_RESULTS)

				-- gui:setFocus(textBox)
				-- UPDATE_RESULTS = true
				-- if not gui.kb.shift() and returnValue then
				-- 	self.parentGui:exit()
				-- end
			end

			function c:onRightMouseClick()
				local fx = tSearchResults[self.fxIndex]
				if fx then
					if gui.kb.control() then
						-- 右键单击+ctrl 复制处理后的type字段到textbox
						-- local typeModified = fx.type:gsub("%s", "_")  -- 将type中的空格替换为下划线
						-- if textBox.value == "" then
						-- 	textBox.value = "@" .. typeModified .. " "
						-- else
						-- 	textBox.value = textBox.value .. " " .. "@" .. typeModified
						-- end
						-- textBox.label = textBox.value

						local typeModified = fx.type
						-- 将空格替换为下划线，以符合查询格式的需求
						typeModified = typeModified:gsub("%s+", "_")
						-- 更新文本框内容
						if textBox.value == "" then
							textBox.value = "@" .. typeModified .. " "
						else
							textBox.value = textBox.value .. " " .. "@" .. typeModified
						end
						textBox.label = textBox.value

						reaper.defer(function()
							-- GUI:setReaperFocus()
							textBox:__setCarretPos(#textBox.value)
							textBox:_draw()

							GUI:setFocus(textBox)
							UPDATE_RESULTS = true
						end)
					elseif gui.kb.alt() then
						-- 右键单击+alt 复制内容: name, alias, type
						reaper.CF_SetClipboard(fx.type)

						local message
						local title = 'Information'  -- Default title in English
					
						if language == "简体中文" then
							message = "复制成功。"
							title = "信息"
							reaper.MB(message, title, 0)  -- 0 for OK button only
						elseif language == "繁體中文" then
							message = "複製成功。"
							title = "信息"
							reaper.MB(message, title, 0)
						else  -- Default to English
							message = "Copy successful."
							title = "Information"
							reaper.MB(message, title, 0)
						end

						return
					end
				end
			end

			function c:onMouseWheel(mw) -- it looks like SCROLL_RESULTS can be a value between 0 and 1, should be a whole number?
				_jScroll(mw/120 * -1)
			end

			function c:onArrowDown()
				return c:onTab()
			end

			function c:onArrowUp()
				return c:onShiftTab()
			end

			function c:onShiftTab()
				if i == 1 and SCROLL_RESULTS~= 0 then
					_jScroll(-1)
					return false
				end
				return true -- else
			end

			function c:onTab()
				if i == #tControls then
					_jScroll(1)
					return false
				end
				return true -- else
			end

			gui:controlAdd(c)
			gui:controlAdd(info)
			tControls[i] = {c, info}
		elseif i > n then

			local b = tControls[i][1]
			local info = tControls[i][2]
			gui:controlDelete(b)
			gui:controlDelete(info)
			n_to_remove = n_to_remove + 1
		end

		if i <= #tControls and i <= n then
			local b = tControls[i][1]
			local info = tControls[i][2]

			b.width = gui.width - 20
			info.x = 10 + b.width - info.width
		end
	end

	for i = 1, n_to_remove do
		table.remove(tControls, #tControls)
	end

end

function _round(inValue)
	return math.floor(inValue+0.5)
end

function _makeColorsCatagory(b, info, color)
	b.colors_label = {}
	b.colors_label.normal = color
	b.colors_label.hover = color:lighter(0.2)
	-- b.colors_label.hover = jColor:new("white")
	info.colors_label = color
end

function showSearchResults(tButtons, tResults)    
	for i, cIds in ipairs(tButtons) do
		local b = cIds[1]  -- 主要文本显示控件，用于显示描述等
		local info = cIds[2]  -- 右侧辅助文本控件，用于显示类型等额外信息
		local iStart = _round(i + SCROLL_RESULTS)
		local highlights = jStringExplode(textBox.value, " ")

		local showing
		if iStart <= #tResults then showing = iStart else showing = #tResults end
		LABEL_STATS.label = "(" .. showing  .. "/" .. #tResults .. ")"

		if tResults and iStart <= #tResults then
			b.fxIndex = iStart  -- 标记此按钮对应的tSearchResults中的项
			local fx = tResults[iStart]
			b.highlight = highlights
			-- b.label = fx.name  -- 使用fx的名称作为主要显示文本
			-- 在这里同时显示name和alias
			if fx.alias ~= "" and fx.alias:match("%S") then
				b.label = fx.name .. (fx.alias and " (" .. fx.alias .. ")" or "")
			else
				b.label = fx.name
			end
			b.visible = true
			
			-- 直接使用fx的type作为类型信息，并在info.label中显示
			info.label = fx.type
			info.visible = true  -- 确保类型信息可见
			
			-- 根据类型设置不同的颜色
			local color = getColorForType(fx.type) -- 基于类型返回相应的颜色
			_makeColorsCatagory(b, info, color)
		else
			b.visible = false
			info.visible = false
		end
	end
end

function getColorForType(type)
    -- 移除头尾空格，然后将内部所有空格替换为下划线，最后转换为小写
	type = type:match("^%s*(.-)%s*$"):gsub("%s+", "_"):lower()
    -- 定义颜色与类型的映射，这里也处理键值的字符串，保证键的格式与输入格式一致
    local types = {
        [COLOR_ROW_HIGHLIGHT_01] = accent_text_color_01,
        [COLOR_ROW_HIGHLIGHT_02] = accent_text_color_02,
        [COLOR_ROW_HIGHLIGHT_03] = accent_text_color_03,
        [COLOR_ROW_HIGHLIGHT_04] = accent_text_color_04,
		[COLOR_ROW_HIGHLIGHT_05] = accent_text_color_05,
		[COLOR_ROW_HIGHLIGHT_06] = accent_text_color_06,
		[COLOR_ROW_HIGHLIGHT_07] = accent_text_color_07,
		[COLOR_ROW_HIGHLIGHT_08] = accent_text_color_08,
		[COLOR_ROW_HIGHLIGHT_09] = accent_text_color_09,
		[COLOR_ROW_HIGHLIGHT_10] = accent_text_color_10
    }
    
    -- 先将键的格式也统一处理
    local normalizedTypes = {}
    for key, color in pairs(types) do
		normalizedTypes[key:match("^%s*(.-)%s*$"):gsub("%s+", "_"):lower()] = color
    end

    -- 使用处理后的类型进行匹配，并返回对应的颜色
    local color = normalizedTypes[type]
    if color then
        return color
    else
        return default_text_color  -- 如果没有匹配项，返回默认颜色
    end
end

function sortByRating(a, b)
	if a.rating > b.rating then
		return true
	elseif a.rating == b.rating then
		return a.name < b.name
	else
		return false
	end
end

function _jPath(p)
	if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
		local r = p:gsub("/", "\\"):gsub("\\+","\\")
		return r
	else
		local r = p:gsub("\\", "/"):gsub("/+","/")
		return r
	end
end

EXCLUDE_DB_KEYS = {}
tTagData = {}

function init()
	-- reaper.ClearConsole()

	p = JProject:new()

	--UPDATE_RATINGS = false
	UPDATE_RESULTS = false
	SCROLL_RESULTS = 0
	RESULT_COUNT = 0

	if not loadSettings() then
		msg("Something went wrong with loading of settings, aborting. Please check your settings file: \n" .. SETTINGS_INI_FILE)
		return false
	end

	setTheme(SET_THEME) -- 设置主题

	jGuiHighlightControl = jGuiControl:new({highlight = {}, color_highlight = text_highlight,})

	function jGuiHighlightControl:_drawLabel()
		-- msg(self.label)
		
		-- gfx.setfont(1, self.label_font, self.label_fontsize)
		gfx.setfont(1, DEFALUT_FONT, DEFALUT_FONT_SIZE)
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

	function getDbType(name)
		for _, rule in ipairs(EXCLUDE_DB_KEYS) do
			local keyPattern, typeName = rule[1], rule[2]
			if name:sub(1, #keyPattern) == keyPattern then
				return typeName
			end
		end
		return DEFAULT_CATEGORY_NAME  -- 如果没有匹配的规则，默认为"DATABASE"
	end

	dbList = getDbList()
	-- if dbList == false then return end
	if dbList == false or #dbList == 0 then  -- 检查数据库列表是否为空
        -- 如果没有数据库，显示错误消息并提供创建数据库的选项
        reaper.MB(FIRST_TIME_MSG, FIRST_TIME_TITLE, 0)  -- 显示消息框
        return false
    end
	
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

	-- Create the GUI
	GUI = jGui:new({
		title = SFX_TAG_TITLE,
		width = WINDOW_WIDTH,
		height = WINDOW_HEIGHT,
		x=WINDOW_X,
		y=WINDOW_Y,
		dockstate=WINDOW_DOCK_STATE,
		background_color = theme_background[1] + theme_background[2] * 256 + theme_background[3] * 65536
	})

	tResultButtons = {}

	textBox = jGuiTextInput:new()
	textBox.x = 10
	textBox.y = 10
	textBox.width = 480
	textBox.height = math.floor( GUI_SIZE * 1.5 + 0.5 ) -- 文本框高度
	textBox.label_fontsize = math.floor( GUI_SIZE * 1.5 + 0.5 ) -- 文本框字体大小
	textBox.label_align = "l"
	textBox.label_font = DEFALUT_FONT -- "Calibri"
	textBox.focus_index = GUI:getFocusIndex()
	textBox.label_padding = 3
	textBox.color_focus_border = cursor_focus_border -- 光标聚焦颜色
	textBox.color_border = text_box_border -- 文本框边框颜色
	textBox.color_background = text_box_background -- 文本框背景颜色
	textBox.carret_color = text_box_carret -- 文本框光标颜色
	textBox.colors_label.normal = text_box_label_normal -- 正常
	textBox.colors_label.hover = text_box_label_hover -- 悬停
	textBox.colors_label.focus = text_box_label_focus -- 聚焦
	textBox.colors_label.active = text_box_label_active -- 激活

	function textBox:onEnter()
		if not isMediaExplorerOpen() then return jTooltip(MEDIA_EXPLORER_NOT_OPEN) end
		send_search_text(self.value)
		-- GUI:exit()
	end

	function textBox:onRightMouseClick() 
		if self.parentGui.kb:alt() then
			-- 右键单击+Alt 清空媒体资源管理器搜索框的内容
			send_search_text(" ")
		else
			-- 右键单击 清空textbox的内容
			self.value = ""
			self.label = ""
		end
	end
	
	GUI:controlAdd(textBox)

	LABEL_STATS = jGuiControl:new()
	LABEL_STATS.width = 50
	LABEL_STATS.x = GUI.width - LABEL_STATS.width - 12
	LABEL_STATS.y = 10
	LABEL_STATS.label_fontsize = math.floor( GUI_SIZE * 0.75 + 0.5 )
	LABEL_STATS.label_align = "r"
	LABEL_STATS.border = false

	GUI:controlAdd(LABEL_STATS)

	-- 标签列表起始高度
	BUTTON_Y_START = GUI_SIZE * 1.5 + 15
	-- createResultButtons(GUI, tResultButtons, RESULTS_PER_PAGE, GUI_SIZE, BUTTON_Y_START)
	
	GUI:setFocus(textBox)

	function GUI:onResize()
		textBox.width = self.width - 20
		LABEL_STATS.x = GUI.width - LABEL_STATS.width - 12

		local buttonsSpaceH = GUI.height - BUTTON_Y_START - 4
		RESULTS_PER_PAGE = buttonsSpaceH // GUI_SIZE -- math.tointeger(buttonsSpaceH // GUI_SIZE)
		-- msg(buttonsSpaceN)
		createResultButtons(GUI, tResultButtons, RESULTS_PER_PAGE, GUI_SIZE, BUTTON_Y_START)
		UPDATE_RESULTS = true
		self:controlInitAll()
	end

	function jGuiControl:_draw()
		self:update()
		if not self.visible then
			return false
		end
		
		self:_drawLabel()
		
		-- Draw a border around the control
		if self.border then
			gfx.rect(self.x, self.y, self.width, self.height, 0)
		end
	
		-- Draw a border if the element has focus
		if self.focus == true and self.border_focus then
			self:__setGfxColor(self.color_focus_border)
			if CURSOR_FOCUS_STYLE >= 1 then
				gfx.rect(self.x, self.y, self.width, self.height, 1)
			elseif CURSOR_FOCUS_STYLE == 0 then
				local distance = 2
				gfx.rect(self.x - distance, self.y - distance, self.width + distance*2, self.height + distance*2, 0)
			end
		end
	end

	function jGui:processKeyboard()
		self.lastChar = gfx.getchar()
		if self.lastChar > 0 then
			-- 翻页和快速跳转
			if self.lastChar == self.kb.page_up or self.lastChar == self.kb.arrow_left then
				GUI:prevPage()
				return
			elseif self.lastChar == self.kb.page_down or self.lastChar == self.kb.arrow_right then
				GUI:nextPage()
				return
			elseif self.lastChar == self.kb.home then
				GUI:firstPage()
				return
			elseif self.lastChar == self.kb._end then
				GUI:lastPage()
				return
			end

			-- F1-F12 的特定操作
			if self.lastChar == self.kb.f1 then
				-- openUrl(KEYWORDS_CSV_FILE)
				-- return
			elseif self.lastChar == self.kb.f2 then
				openUrl(SETTINGS_INI_FILE)
				return
			elseif self.lastChar == self.kb.f3 then
				self:setFocus(textBox)
				return
			elseif self.lastChar == self.kb.f4 then
				if self.kb:shift() then
					send_search_text(" ")
				else
					textBox.value = ""
					textBox.label = ""
					self:setFocus(textBox)
				end
				return
			elseif self.lastChar == self.kb.f5 then
				reloadDbData()
			elseif self.lastChar == self.kb.f12 then
				-- 弹出提示，让用户输入内容的逻辑
				textBox:promptForContent()
				return
			end

			-- TODO process ESC here too!
			if self.lastChar == self.kb.escape then
				-- The escape closes the script and is not passed on to the control
				self:onEsc()
			elseif self.lastChar == self.kb.enter and self.focus then -- ENTER
				if not isMediaExplorerOpen() then return jTooltip(MEDIA_EXPLORER_NOT_OPEN) end
				self.focus:_onEnter()
			elseif self.lastChar == self.kb.tab and not self.kb.shift() then -- TAB
				if self.focus then
					self.focus:_onTab()
				else
					self:focusNext()
				end
			elseif self.lastChar == self.kb.arrow_down then -- ARROW DOWN
				if self.focus then
					self.focus:_onArrowDown()
				else
					self:focusNext()
				end
			elseif (self.lastChar == self.kb.tab and self.kb.shift()) then -- SHIFT TAB
				if self.focus then
					self.focus:_onShiftTab()
				else
					self:focusPrev()
				end		
			elseif self.lastChar == self.kb.arrow_up then -- ARROW UP
				if self.focus then
					self.focus:_onArrowUp()
				else
					self:focusPrev()
				end			
			else -- A key was pressed. Send it to the control with keyboard focus
				if self.focus then
					self.focus:_onKeyboard(self.lastChar)
				end
			end
		elseif self.lastChar == -1 then
			-- 窗口被关闭
			self:onClose()
		end
		return self.lastChar
	end
	
    -- 加入双击功能
	-- function textBox:onMouseClick()
	-- 	local last_click_clock = self.last_click_clock
	-- 	self.last_click_clock = os.clock()
	-- 	if last_click_clock and self.last_click_clock - last_click_clock < 1 then
	-- 		self:onMouseDoubleClick(x, y)
	-- 		return
	-- 	end
	-- end
	
	-- -- textBox双击触发用户输入
	-- function textBox:onMouseDoubleClick()
	-- 	self:promptForContent()
	-- end

	-- 用户输入函数
	function textBox:promptForContent()
		local retval, retvals_csv = reaper.GetUserInputs(INPUT_TITLE, 1, INPUT_CAPTION .. ",extrawidth=100", self.value)
		if retval then
			self.value = retvals_csv
			self.label = self.value
			self:__setCarretPos(#self.value)
			self:_draw()

			GUI:setReaperFocus()
		end
		-- reaper.defer(function()
		-- 	GUI:setFocus(textbox)
		-- 	GUI:setReaperFocus()
		-- end)
	end
	
	GUI:init()

	function GUI:update()
		if lastSearch ~= textBox.value then
			SCROLL_RESULTS = 0 -- reset scrollbar on search update
		end

		if(lastSearch ~= textBox.value or UPDATE_RESULTS) then
			-- search changed, update results
			UPDATE_RESULTS = false
			if UPDATE_RATINGS then
				table.sort(tTagData, sortByRating)
			end
			if lastSearch ~= textBox.value then -- only search again when input changes, not on scroll
				tSearchResults = findTag(tTagData, textBox.value, false, MAX_RESULTS)
				--tSearchResults = findTag(tTagData, textBox.value, false, false)
				lastSearch = textBox.value
			end
			RESULT_COUNT = #tSearchResults
			showSearchResults(tResultButtons, tSearchResults)
		end
	end
	
	function GUI:onExit()
		if UPDATE_RATINGS then
			table.sort(tTagData, sortByRating)
			jWriteTagData(DATA_INI_FILE, tTagData)
		end

		if WINDOW_SAVE_STATE then
			local dockstate, wx, wy, ww, wh = gfx.dock(-1, 0, 0, 0, 0)
			local dockstr = string.format("%d", dockstate)
			jSettingsWriteToFileMultiple(SETTINGS_INI_FILE, {
				{"gui", "window_x", math.tointeger(wx)}, 
				{"gui", "window_y", math.tointeger(wy)},
				{"gui", "window_width", math.tointeger(ww)},
				{"gui", "window_height", math.tointeger(wh)},
				{"gui", "window_dock_state", dockstr}
			}, true)
		end
	end

	return true
end

function loop()
	if GUI:loop() then 
		reaper.defer(loop)
	else
		gfx.quit()
	end
end

function _joinSettingsTables(keys, values)
	local tResult = {}
	for i = 1, #keys do
		tResult[i] = {keys[i], values[i]}
	end
	return tResult
end

function loadSettings()
	jSettingsCreate(SETTINGS_INI_FILE, SETTINGS_DEFAULT_FILE)
	SETTINGS = assert(jSettingsReadFromFile(SETTINGS_INI_FILE), "Could not open settings file.")

	-- new settings since 0.7.16, will be created if not present
	if not SETTINGS['window_save_state'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "window_save_state", "true", true)
		SETTINGS['window_save_state'] = {true}
	end

	if not SETTINGS['window_dock_state'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "window_dock_state", "0", true)
		SETTINGS['window_dock_state'] = {0}
	end

	if not SETTINGS['gui_size'] then
		jSettingsWriteToFile(SETTINGS_INI_FILE, "gui", "gui_size", "20", true)
		SETTINGS['gui_size'] = {20}
	end

	CURSOR_FOCUS_STYLE = jSettingsGet(SETTINGS, 'cursor_focus_style', "number")
	SET_THEME = jSettingsGet(SETTINGS, 'default_theme', "string")
	ENGLISH_FIRST = jSettingsGet(SETTINGS, 'english_first', "boolean")

	-- if true then return false end
	DATA_INI_FILE = _jPath(SETTINGS_BASE_FOLDER .. jSettingsGet(SETTINGS, 'sfx_tag_data_file', "string"))
	KEYWORDS_CSV_FILE = _jPath(SETTINGS_BASE_FOLDER .. jSettingsGet(SETTINGS, 'keywords_csv_file', "string"))

	UPDATE_RATINGS = jSettingsGet(SETTINGS, 'update_ratings', "boolean")
	
	-- RESULTS_PER_PAGE = jSettingsGet(SETTINGS, 'results_per_page', "number")
	MAX_RESULTS = jSettingsGet(SETTINGS, 'max_results', "number")

	FILTER_NAME = jSettingsGet(SETTINGS, 'filter_name', "boolean")
	FILTER_ALIAS = jSettingsGet(SETTINGS, 'filter_alias', "boolean")
	FILTER_CATEGORY = jSettingsGet(SETTINGS, 'filter_category', "boolean")

	COLOR_ROW_HIGHLIGHT_01 = jSettingsGet(SETTINGS, 'color_row_highlight_01', "string")
	COLOR_ROW_HIGHLIGHT_02 = jSettingsGet(SETTINGS, 'color_row_highlight_02', "string")
	COLOR_ROW_HIGHLIGHT_03 = jSettingsGet(SETTINGS, 'color_row_highlight_03', "string")
	COLOR_ROW_HIGHLIGHT_04 = jSettingsGet(SETTINGS, 'color_row_highlight_04', "string")
	COLOR_ROW_HIGHLIGHT_05 = jSettingsGet(SETTINGS, 'color_row_highlight_05', "string")
	COLOR_ROW_HIGHLIGHT_06 = jSettingsGet(SETTINGS, 'color_row_highlight_06', "string")
	COLOR_ROW_HIGHLIGHT_07 = jSettingsGet(SETTINGS, 'color_row_highlight_07', "string")
	COLOR_ROW_HIGHLIGHT_08 = jSettingsGet(SETTINGS, 'color_row_highlight_08', "string")
	COLOR_ROW_HIGHLIGHT_09 = jSettingsGet(SETTINGS, 'color_row_highlight_09', "string")
	COLOR_ROW_HIGHLIGHT_10 = jSettingsGet(SETTINGS, 'color_row_highlight_10', "string")

	DEFALUT_FONT = jSettingsGet(SETTINGS, 'default_font', "string")
	DEFALUT_FONT_SIZE = jSettingsGet(SETTINGS, 'default_font_size', "number")
	FONT_SIZE_ADJUSTMENT = jSettingsGet(SETTINGS, 'font_size_adjustment', "number")

	WINDOW_WIDTH = jSettingsGet(SETTINGS, 'window_width', "number")
	WINDOW_HEIGHT = jSettingsGet(SETTINGS, 'window_height', "number")
	WINDOW_X = jSettingsGet(SETTINGS, 'window_x', "number")
	WINDOW_Y = jSettingsGet(SETTINGS, 'window_y', "number")
	WINDOW_SAVE_STATE = jSettingsGet(SETTINGS, 'window_save_state', "boolean")
	WINDOW_DOCK_STATE = jSettingsGet(SETTINGS, 'window_dock_state', "number")
	GUI_SIZE = jSettingsGet(SETTINGS, 'gui_size', "number")

	DEFAULT_CATEGORY_NAME = jSettingsGet(SETTINGS, 'default_category_name', "string")
	EXCLUDE_DB_ENABLE = jSettingsGet(SETTINGS, 'category_by_prefix_enable', "boolean")
	if EXCLUDE_DB_ENABLE then
		local keys = jSettingsGet(SETTINGS, 'type_prefix', "table")
		local values = jSettingsGet(SETTINGS, 'category_name', "table")
		EXCLUDE_DB_KEYS = _joinSettingsTables(keys, values)
	else
		EXCLUDE_DB_KEYS = {{"", "DATABASE"}}  -- 默认不排除任何DB类型
	end

	return true
end

if init() then
	GUI:setReaperFocus()
	loop()

	if reaper.JS_Window_FindEx then
		local hwnd = reaper.JS_Window_Find(SFX_TAG_TITLE, true)
		if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
	end
end
