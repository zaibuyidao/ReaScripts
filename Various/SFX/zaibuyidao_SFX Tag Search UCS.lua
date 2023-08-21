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
CONFIG = require('config-ucs')
ListView = require('ListView')
pinyin = require('pinyin')

setGlobalStateSection("SFX_TAG_SEARCH_CUSTOM")

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
    if countSeparator(line, sep) ~= 7 then
		local retval
		if language == "简体中文" then
			retval = reaper.MB(string.format("ucs_keywords.csv 自定义关键词格式错误：第 %d 行的分隔符数量不正确。\n请修改自定义关键词文件，并重新启动脚本。\n\n要现在打开 ucs_keywords.csv 吗？", lineNumber), '错误', 1)
		elseif language == "繁体中文" then
			retval = reaper.MB(string.format("ucs_keywords.csv 自訂關鍵詞格式錯誤：第 %d 行的分隔符數量不正確。\n請修改自訂關鍵詞文件，並重新啟動腳本。\n\n要現在打開 ucs_keywords.csv 嗎？", lineNumber), '錯誤', 1)
		else
			retval = reaper.MB(string.format("ucs_keywords.csv custom keyword format error: The number of separators on line %d is incorrect.\nPlease modify the custom keyword file and restart the script.\n\nDo you want to open ucs_keywords.csv now?", lineNumber), 'Error', 1)
		end

		if retval == 1 then
			openUrl(script_path .. "ucs_keywords.csv")
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

SIZE_UNIT = getConfig("ui.global.size_unit", 20)
local data = {}

function loadCSVData(columns)
	data = {} -- 清空旧数据
	local f = io.open(script_path .. getPathDelimiter() .. "ucs_keywords.csv", "r")

	local lineNumber = 1
	while true do
			local line = f:read()
			if line == nil then break end

			-- 如果是第一行，跳过处理
			local parts = parseCSVLine(line, ",", lineNumber)
			if parts == nil then return end

			if lineNumber ~= 1 and parts[1] ~= "" then
					table.insert(data, {
							key = parts[columns[1]],
							name = parts[columns[2]],
							remark = parts[columns[3]],
							name2 = parts[columns[4]],
							remark2 = parts[columns[5]],
							name3 = parts[columns[6]],
							remark3 = parts[columns[7]]
					})
			end

			lineNumber = lineNumber + 1
	end
end

--loadCSVData({1, 2, 3, 4, 5, 6, 7}) -- 英文
loadCSVData({1, 4, 5, 2, 3, 6, 7}) -- 默认简中
--loadCSVData({1, 6, 7, 2, 3, 4, 5}) -- 繁中
local currentMode = 2 -- 1 英文 2 简中 3 繁中

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

function searchKeyword(value, rating) -- 过滤搜索
	local res = {}
	local caseSensitive = getConfig("search.case_sensitive")
	local includeName = getConfig("search.include_name")
	local includeRemark = getConfig("search.include_remark")
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

	return res
end

--local timer = reaper.time_precise() -- 定时器
local executeSecondCommand = false

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

	local resultListView = ListView.new({
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
			local function getValueForMode(data, mode, defaultField, modeField)
				if mode == 1 then
						return data[defaultField]
				else
						return data[modeField]
				end
			end
		  -- 任何语言模式下仍然发送英文
			local currentCatID = data.key
			local currentCatFull = getValueForMode(data, currentMode, "remark", "remark2") .. "-" .. getValueForMode(data, currentMode, "name", "name2")
			local currentCategory = getValueForMode(data, currentMode, "remark", "remark2")
			local currentSubCategory = getValueForMode(data, currentMode, "name", "name2")
			-- 任何语言模式下仍然发送中文
			local currentCatFullCH = getValueForMode(data, currentMode, "remark2", "remark") .. "-" .. getValueForMode(data, currentMode, "name2", "name")
			local currentCategoryCH = getValueForMode(data, currentMode, "remark2", "remark")
			local currentSubCategoryCH = getValueForMode(data, currentMode, "name2", "name")
			local currentCatFullCH = getValueForMode(data, currentMode, "remark2", "remark") .. "-" .. getValueForMode(data, currentMode, "name2", "name")

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
				if not data then return end -- 如果没有找到当前项，直接返回

				if self.parentGui.kb:shift() and self.parentGui.kb:control() and self.parentGui.kb:alt() then -- Shift+Ctrl+Alt+左键点击
					if currentMode == 1 then
						local combinedText = (data.remark2 or "") .. " " .. (data.name2 or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					else
						local combinedText = (data.remark or "") .. " " .. (data.name or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					end
					return
				elseif self.parentGui.kb:shift() and self.parentGui.kb:control() then -- Shift+Ctrl+左键点击
					if currentMode == 1 then
						local combinedText = (data.name2 or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					else
						local combinedText = (data.name or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					end
					return
				elseif self.parentGui.kb:shift() and self.parentGui.kb:alt() then -- Shift+Alt+左键点击
					if currentMode == 1 then
						local combinedText = (data.remark2 or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					else
						local combinedText = (data.remark or "")
						if combinedText and combinedText ~= " " then
							reaper.defer(function ()
									send_search_text(combinedText)
							end)
						end
					end
					return
				elseif self.parentGui.kb:shift() then -- Shift+左键点击
					if currentMode == 1 then
						local combinedText = (data.remark or "") .. " " .. (data.name or "")
						if combinedText and combinedText ~= " " then
								reaper.defer(function ()
										send_search_text(combinedText)
								end)
						end
					else
						local combinedText = (data.remark2 or "") .. " " .. (data.name2 or "")
						if combinedText and combinedText ~= " " then
								reaper.defer(function ()
										send_search_text(combinedText)
								end)
						end
					end
					return
				elseif self.parentGui.kb:control() then -- Control+左键点击
					if currentMode == 1 then
						if data.name and data.name ~= "" then
							reaper.defer(function ()
								send_search_text(data.name)
							end)
						end
					else
						if data.name2 and data.name2 ~= "" then
							reaper.defer(function ()
								send_search_text(data.name2)
							end)
						end
					end
					return
				elseif self.parentGui.kb:alt() then -- Alt+左键点击
					if currentMode == 1 then
						if data.remark and data.remark ~= "" then
							reaper.defer(function ()
								send_search_text(data.remark)
							end)
						end
					else
						if data.remark2 and data.remark2 ~= "" then
							reaper.defer(function ()
								send_search_text(data.remark2)
							end)
						end
					end
					return
				end
				reaper.defer(function ()
						send_search_text(data.key)
				end)
				-- reaper.CF_SetClipboard(data.key) -- 复制
			end

			-- function c:onRightMouseClick() -- Defer版本无效
			-- 	edit_tag(currentCatID)
			-- 	reaper.JS_WindowMessage_Post(reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true), "WM_COMMAND", getConfig("ucs.catid"), 0, 0, 0) -- Edit metadata tag: CatID

			-- 	reaper.defer(function ()
			-- 		edit_tag(currentCatFull)
			-- 		reaper.JS_WindowMessage_Post(reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true), "WM_COMMAND", getConfig("ucs.category_full"), 0, 0, 0) -- Edit metadata tag: CategoryFull
			-- 	end)
			-- end

			-- function c:onRightMouseClick() -- 定时器版本 V1
			-- 	timer = reaper.time_precise()  -- 重置timer的值
		
			-- 	edit_tag(currentCatID)
			-- 	reaper.JS_WindowMessage_Post(reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true), "WM_COMMAND", getConfig("ucs.catid"), 0, 0, 0) -- Edit metadata tag: CatID
		
			-- 	local function executeSecondOperation()
			-- 			local now = reaper.time_precise()
			-- 			if now - timer >= 0.3 then -- 检查是否已经过去了0.1秒
			-- 					edit_tag(currentCatFull)
			-- 					reaper.JS_WindowMessage_Post(reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true), "WM_COMMAND", getConfig("ucs.category_full"), 0, 0, 0) -- Edit metadata tag: CategoryFull
			-- 			else
			-- 					reaper.defer(executeSecondOperation) -- 如果还没有过去0.1秒，再次延迟执行
			-- 			end
			-- 	end
		
			-- 	reaper.defer(executeSecondOperation)
			-- end

			-- function c:onRightMouseClick() -- 定时器版本 V2
			-- 	timer = reaper.time_precise()  -- 重置timer的值
			-- 	local function sendCommandToMediaExplorer(commandID, tagValue)
			-- 		local mediaExplorerWindow = reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true)
			-- 		if mediaExplorerWindow then
			-- 				edit_tag(tagValue)
			-- 				reaper.JS_WindowMessage_Post(mediaExplorerWindow, "WM_COMMAND", commandID, 0, 0, 0)
			-- 		end
			-- 	end
		
			-- 	-- 发送第一个命令
			-- 	sendCommandToMediaExplorer(getConfig("ucs.catid"), currentCatID)
		
			-- 	local function executeSecondOperation()
			-- 			local now = reaper.time_precise()
			-- 			local delay = getConfig("ucs.delay_time")
			-- 			if now - timer >= delay then -- 检查是否已经过去了 delay 秒
			-- 				sendCommandToMediaExplorer(getConfig("ucs.category_full"), currentCatFull)
			-- 			else
			-- 					reaper.defer(executeSecondOperation) -- 如果还没有过去0.3秒，再次延迟执行
			-- 			end
			-- 	end
		
			-- 	reaper.defer(executeSecondOperation)
			-- end

			-- function c:onRightMouseClick() -- 定时器版本 V4
			-- 	timer = reaper.time_precise()  -- 重置timer的值
		
			-- 	local function sendCommandToMediaExplorer(commandID, tagValue)
			-- 			local mediaExplorerWindow = reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true)
			-- 			if mediaExplorerWindow then
			-- 					edit_tag(tagValue)
			-- 					reaper.JS_WindowMessage_Post(mediaExplorerWindow, "WM_COMMAND", commandID, 0, 0, 0)
			-- 			end
			-- 	end
		
			-- 	-- 发送第一个命令
			-- 	sendCommandToMediaExplorer(getConfig("ucs.catid"), currentCatID)
		
			-- 	local commandQueue = {
			-- 			{getConfig("ucs.category_full"), currentCatFull},
			-- 			{getConfig("ucs.category"), currentCategory},
			-- 			{getConfig("ucs.sub_category"), currentSubCategory}
			-- 	}
		
			-- 	local function executeNextOperation()
			-- 			local now = reaper.time_precise()
			-- 			local delay = getConfig("ucs.tag_write_delay")
			-- 			if now - timer >= delay then
			-- 					if #commandQueue > 0 then
			-- 							local nextCommand = table.remove(commandQueue, 1)
			-- 							sendCommandToMediaExplorer(nextCommand[1], nextCommand[2])
			-- 							timer = reaper.time_precise()  -- 重置timer的值
			-- 							reaper.defer(executeNextOperation) -- 继续执行下一个命令
			-- 					end
			-- 			else
			-- 					reaper.defer(executeNextOperation) -- 如果还没有过去指定的延迟时间，再次延迟执行
			-- 			end
			-- 	end
		
			-- 	reaper.defer(executeNextOperation)
			-- end

			function searchTextBox:onRightMouseClick() -- Alt+右键单击 清空 Media Explorer 的搜索框
				if self.parentGui.kb:alt() then
					send_search_text(" ")
				else
					self.value = ""
					self.label = ""
				end
			end

			function c:onRightMouseClick() -- 定时器版本 V5
				-- 创建一个命令队列
				local commandQueue = {}
		
				-- 根据设置添加命令到队列
				if getConfig("ucs.write_catid") then
						table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_catid"), tagValue = currentCatID})
				end
				if getConfig("ucs.write_category_full") then
						table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_category_full"), tagValue = currentCatFull})
				end
				if getConfig("ucs.write_category") then
						table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_category"), tagValue = currentCategory})
				end
				if getConfig("ucs.write_sub_category") then
						table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_sub_category"), tagValue = currentSubCategory})
				end
				if getConfig("ucs.write_category_full_ch") then
					table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_category_full_ch"), tagValue = currentCatFullCH})
				end
				if getConfig("ucs.write_category_ch") then
					table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_category"), tagValue = currentCategoryCH})
				end
				if getConfig("ucs.write_sub_category_ch") then
						table.insert(commandQueue, {commandID = getConfig("ucs.cmd_id_sub_category"), tagValue = currentSubCategoryCH})
				end
		
				local function sendCommandToMediaExplorer(commandID, tagValue)
						local mediaExplorerWindow = reaper.JS_Window_Find(reaper.JS_Localize("Media Explorer", "common"), true)
						if mediaExplorerWindow then
								edit_tag(tagValue)
								reaper.JS_WindowMessage_Post(mediaExplorerWindow, "WM_COMMAND", commandID, 0, 0, 0)
						end
				end
		
				local timer = reaper.time_precise()
				local delay = getConfig("ucs.tag_write_delay")
		
				local function executeCommands()
						local now = reaper.time_precise()
						if now - timer >= delay then
								if #commandQueue > 0 then
										local command = table.remove(commandQueue, 1) -- 获取并移除队列的第一个命令
										sendCommandToMediaExplorer(command.commandID, command.tagValue)
										timer = now -- 重置计时器
										reaper.defer(executeCommands) -- 继续执行队列中的下一个命令
								end
						else
								reaper.defer(executeCommands) -- 如果还没有过去delay秒，再次延迟执行
						end
				end
		
				executeCommands() -- 开始执行命令队列
			end

		end
	})

	function onKeyboardGlobal(key)
		local originalPosition = resultListView.firstIndex

		if key == 1818584692 or key == 1885828464 then -- left arrow 1818584692 page up 1885828464
			-- print("page up")
			resultListView:scroll(0-getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		elseif key == 1919379572 or key == 1885824110 then -- right arrow 1919379572 page down 1885824110
			-- print("page down")
			resultListView:scroll(getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		elseif key == 26161 then --编辑关键词 f1
			openUrl(script_path .. "ucs_keywords.csv")
		elseif key == 26162 then --编辑配置表 f2
			openUrl(script_path .. "lib/config-ucs.lua")
		elseif key == 26163 then --随机行 f3
			resultListView:randomJump()
		elseif key == 26164 then --跳转目标 f4
			resultListView:promptForJump()
		elseif key == 26165 then --F5
			reaper.Main_OnCommand(50124, 0) -- Media explorer: Show/hide media explorer
		elseif key == 26166 then --F6
			loadCSVData({1, 2, 3, 4, 5, 6, 7})
			startSearch(searchTextBox.value) -- 刷新列表
			resultListView:jump(originalPosition)
			currentMode = 1
		elseif key == 26167 then --F7
			loadCSVData({1, 4, 5, 2, 3, 6, 7})
			startSearch(searchTextBox.value) -- 刷新列表
			resultListView:jump(originalPosition)
			currentMode = 2
		elseif key == 26168 then --F8
			loadCSVData({1, 6, 7, 2, 3, 4, 5})
			startSearch(searchTextBox.value) -- 刷新列表
			resultListView:jump(originalPosition)
			currentMode = 3
		elseif key == 26169 then --F9
			if currentMode == 1 then
				loadCSVData({1, 4, 5, 2, 3, 6, 7})
					currentMode = 2
			elseif currentMode == 2 then
				loadCSVData({1, 6, 7, 2, 3, 4, 5})
					currentMode = 3
			else
				loadCSVData({1, 2, 3, 4, 5, 6, 7})
					currentMode = 1
			end
			startSearch(searchTextBox.value) -- 刷新列表
			resultListView:jump(originalPosition)
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

		-- local focusedData = resultListView.data[resultListView.firstIndex] -- 打印聚焦行标签
		-- if focusedData and focusedData.synonym2 then
		-- 		print(focusedData.synonym2)
		-- else
		-- 		print("No data or name for the focused row.")
		-- end
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