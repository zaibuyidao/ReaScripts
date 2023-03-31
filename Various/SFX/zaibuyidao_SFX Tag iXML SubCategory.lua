-- NoIndex: true
EXCLUDE_DB_LIST =  { } -- 示例 exclude = { "DB: 00", "DB: 01" }
EXCLUDE_LIST = { } -- 示例 exclude = { "File", "Custom Tags", "Description", "Keywords" }

function print(...)
	local args = {...}
	local str = ""
	for i = 1, #args do
		if type(args[i]) == "table" then
			str = str .. table.tostring(args[i]) .. "\n"
		else
			str = str .. tostring(args[i]) .. "\t"
		end
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
    search_title = "搜索"
    search_title_key = "关键词"
    remaining = "剩余: "
elseif language == "繁体中文" then
    jump_title = "跳转目标"
    jump_title_line = "行数"
    search_title = "搜索"
    search_title_key = "關鍵詞"
    remaining = "剩餘: "
else
    jump_title = "Jump"
    jump_title_line = "Ln"
    search_title = "Search"
    search_title_key = "Keywords"
    remaining = "Rem: "
end

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('REQ.j_file_functions')
require('REQ.JProjectClass')
require('REQ.j_tables')
require('REQ.jGui')
require('REQ.j_trackstatechunk_functions')
require('REQ.j_settings_functions')
require('core')
require('reaper-utils')
LIP = require('LIP')
CONFIG = require('config')
ListView = require('ListView')

setGlobalStateSection("SFX_TAG_SEARCH_IXML_SUBCATEGORY")

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

    local path
    local keywords = {}

    local function processItem(itemType, content)
        if itemType == "PATH" then
            path = (parseCSVLine(content, " "))[1]
        elseif itemType == "USER" and not excludeOrigin["SubCategory"] then
            local ok, entries = pcall(parseCSVLine, content, " ")
            if not ok then
                -- print("parse DATA line failed:", content, entries)
                goto continue
            end
            if entries[1] and entries[1]:find("IXML:USER:SubCategory") and entries[2] then
                for w in iteratorOf("SubCategory", entries[2]) do
                    local value = w:trim():trimFileExtension()
                    keywords[value] = keywords[value] or { value = value, from = {} }
                    keywords[value].from["SubCategory"] = true
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
        return path, keywords
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
dbList = getDbList()
if dbList == false then return end
ratings = (function ()
	local ratings = {}
	local f = io.open(script_path .. getPathDelimiter() .. "rating.csv", "r")
	if not f then return end
	while true do
        local line = f:read()
        if line == nil then break end
		local d = parseCSVLine(line, ",")
		ratings[d[1]] = tonumber(d[2])
    end
	return ratings
end)()

function incRating(keyword)
	ratings[keyword] = (ratings[keyword] or 0) + 1
end

function getRating(keyword)
	return ratings[keyword] or 0
end

function writeRatings()
	local tmp = {}
	for k, v in pairs(ratings) do
		table.insert(tmp, {
			key = k,
			value = v
		})
	end

	table.sort(tmp, function (a, b)
		return a.value > b.value
	end)

	local f = io.open(script_path .. getPathDelimiter() .. "rating.csv", "w")
	local res = {}
	for i=1, math.min(getConfig("rating.max_record", 50), #tmp) do
		f:write("\"")
		f:write(tostring(tmp[i].key))
		f:write("\"")
		f:write(",")
		f:write(tostring(tmp[i].value))
		f:write("\n")
	end
	f:close()
end

local colorMap = getConfig("ui.result_list.db_color", {})
local defaultDbColors = getConfig("ui.result_list.default_colors", {{.6, .6, .6, 1}})
local nextColor = 1

function getColorForDb(dbName)
	if colorMap[dbName] then return jColor:new(colorMap[dbName]) end
	colorMap[dbName] = defaultDbColors[nextColor]
	nextColor = (((nextColor + 1) - 1) % #defaultDbColors) + 1
	return jColor:new(colorMap[dbName])
end

local sortResult = getConfig("search.sort_result") -- 加入排序
local data = {}
local readDBCount = 0
local excludeDbName = table.arrayToTable(EXCLUDE_DB_LIST)-- getConfig("db.exclude_db", {}, table.arrayToTable)

for _, db in ipairs(dbList) do
	if not excludeDbName[db.name] then
		local path, keywords = readViewModelFromReaperFileList(db.path, {
			excludeOrigin = table.arrayToTable(EXCLUDE_LIST), -- getConfig("db.exclude_keyword_origin", {}, table.arrayToTable),
			delimiters = getConfig("db.delimiters", {}),
			containsAllParentDirectories = getConfig("search.file.contains_all_parent_directories")
		})
	
		if path and keywords then
			readDBCount = readDBCount + 1
			for v, keyword in pairs(keywords) do

				table.insert(data, {
					db = db.name,
					path = path,
					value = keyword.value,
					from = keyword.from,
					fromString = table.concat(table.keys(keyword.from), ", ")
				})
			end
		end
	end
end

if readDBCount == 0 then
	return reaper.MB("找不到數據庫，請創建一個數據庫，並重新運行該腳本。", "錯誤", 0)
end

if sortResult then -- 加入排序
	table.sort(data, function(a, b)
		return string.lower(tostring(a.value)) < string.lower(tostring(b.value))
	end)
end

-- -- 模拟插入大量数据
-- for i=1, 50000 do
-- 	table.insert(data, {
-- 		db = "db.name",
-- 		path = "path",
-- 		value = "keyword.value" .. i,
-- 		from = "keyword.from",
-- 		fromString = "AAA" 
-- 	})
-- end

function searchKeyword(value, rating)
	local res = {}
	local index = 1
	local caseSensitive = getConfig("search.case_sensitive")
	local lowerValue = value:lower()
	for _, item in ipairs(data) do
		if value == "" or (caseSensitive and item.value:find(value)) or (not caseSensitive and item.value:lower():find(lowerValue)) then
			res[index] = {
				index = index, -- for stable sort
				db = item.db,
				path = item.path,
				value = item.value,
				from = item.from,
				fromString = item.fromString
			}
			index = index + 1
		end
	end
	
	-- table.sort(res, function(a, b)
	-- 	local ra = getRating(a.value)
	-- 	local rb = getRating(b.value)
	-- 	if ra == rb then
	-- 		return a.index < b.index
	-- 	end
	-- 	return ra > rb
	-- end)
	return res
end

function searchKeywordAsync(value, rating, result)
	local index = 1
	local caseSensitive = getConfig("search.case_sensitive")
	local function compare(a, b)
		local ra = getRating(a.value)
		local rb = getRating(b.value)
		if ra == rb then
			return a.index < b.index
		end
		return ra > rb
	end
	local function processItem(item, index)
		if value == "" or (caseSensitive and item.value:find(value)) or (not caseSensitive and item.value:lower():find(value:lower())) then
			-- table.insert(result, {
			-- 	index = index, -- for stable sort
			-- 	db = item.db,
			-- 	path = item.path,
			-- 	value = item.value,
			-- 	from = item.from,
			-- 	fromString = item.fromString
			-- })
			table.bininsert(result, {
				index = index, -- for stable sort
				db = item.db,
				path = item.path,
				value = item.value,
				from = item.from,
				fromString = item.fromString
			}, compare)
		end
	end
	local i = 1
	local function hasNext()
		return i <= #data
	end
	local function fetchNext()
		if i > #data then return end
		local res = processItem(data[i], i)
		i = i + 1
		return res
	end
	local function getNextIndex()
		return i
	end
	return hasNext, fetchNext, getNextIndex, #data
end

function init()
	JProject:new()
	window = jGui:new({
        title = getConfig("ui.window.title") .. " - iXML SubCategory",
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
		label_fontsize = math.floor( SIZE_UNIT * 1.5 ),
		label_align = "l",
		border_focus = getConfig("ui.search_box.border_focus", searchTextBox.border_focus),
		label_font = getConfig("ui.global.font", "微软雅黑"),
		carret_color = getConfig("ui.search_box.carret_color", searchTextBox.carret_color),
		colors_label = getConfig("ui.search_box.colors_label") or searchTextBox.colors_label,
		color_focus_border = getConfig("ui.search_box.color_focus_border") or searchTextBox.color_focus_border,
		focus_index = window:getFocusIndex(),
		label_padding = 3
	})
	function searchTextBox:onRightMouseClick() 
		self.value = ""
		self.label = ""
	end
	window:controlAdd(searchTextBox)

	local stateLabel = jGuiControl:new()
	table.assign(stateLabel, {
		width = SIZE_UNIT * 2.5,
		x = window.width - stateLabel.width - 12,
		y = 10,
		label_fontsize = math.floor(SIZE_UNIT * 0.75),
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
			c.width = window.width - 20
			info.x = 10 + c.width - info.width

			if getConfig("ui.result_list.show_keyword_origin", false) then
				c.label = listView.data[dataIndex].value .. " (" .. listView.data[dataIndex].fromString .. ")"
			else
				c.label = listView.data[dataIndex].value
			end
			
			info.label = listView.data[dataIndex].db
			c.highlight = { searchTextBox.value }

			c.colors_label = {}
			c.colors_label.normal = getColorForDb(listView.data[dataIndex].db)
			c.colors_label.hover = getColorForDb(listView.data[dataIndex].db):lighter(0.2)
			info.colors_label = getColorForDb(listView.data[dataIndex].db)

			c.focus_index = viewHolderIndex + 1 --gui:getFocusIndex()

			function c:onMouseClick()
				-- incRating(listView.data[dataIndex].value)
				if getReaperExplorerPath() ~= listView.data[dataIndex].db and getConfig("search.switch_database") then
					setReaperExplorerPath(listView.data[dataIndex].db)
				end
				reaper.defer(function ()
					send_search_text(listView.data[dataIndex].value)
				end)
			end

			function c:onRightMouseClick()
				reaper.CF_SetClipboard(listView.data[dataIndex].value)
			end
		end
	})

	function onKeyboardGlobal(key)
		if key == 1885828464 then
			-- print("page up")
			resultListView:scroll(0-getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		elseif key == 1885824110 then
			-- print("page down")
			resultListView:scroll(getConfig("ui.result_list.page_up_down_size", resultListView:getPageSize()))
		elseif key == 26164 then --跳转目标 f4
			resultListView:promptForJump()
		elseif key == 26163 then --随机行 f3
			resultListView:randomJump()
		elseif key == 6697266 then --过滤关键词 f12
			searchTextBox:promptForContent()
		-- elseif key == 26162 then --编辑配置表 f2
		-- 	openUrl(script_path .. "lib/config.lua")
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
		elseif key == 26165 then --F5
			reaper.Main_OnCommand(50124, 0) -- Media explorer: Show/hide media explorer
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
		if args then
			self:jump(args[1])
		end
		reaper.defer(function()
			window:setFocus(searchTextBox)
			window:setReaperFocus()
		end)
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
		if resultListView.firstIndex + resultListView:getPageSize()-1 > #resultListView.data then
			stateLabel.label = "(" .. #resultListView.data .. "/" .. #resultListView.data .. ")"
		else
			stateLabel.label = "(" .. resultListView.firstIndex + resultListView:getPageSize()-1 .. "/" .. #resultListView.data .. ")"
		end
		if remain > 0 then
			stateLabel.label = stateLabel.label .. remaining .. remain
		end
	end

	function startSearchAsync(value)
		resultListView.firstIndex = 1
		local data = {}
		resultListView.data = data
		local hasNext, fetchNext, getNextIndex, total = searchKeywordAsync(searchTextBox.value, ratings, data)
		local function fetch()
			if not hasNext or resultListView.data ~= data then return end
			fetchNext()
			remain = total - getNextIndex() + 1
			refreshResultState()
			reaper.defer(fetch)
		end
		reaper.defer(fetch)
	end

	function startSearchSync(value)
		resultListView.firstIndex = 1
		resultListView.data = searchKeyword(searchTextBox.value, ratings)
		refreshResultState()
	end

	local startSearch = startSearchSync
	if getConfig("search.async") then
		startSearch = startSearchAsync
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
		-- writeRatings()
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
		local hwnd = reaper.JS_Window_Find(getConfig("ui.window.title") .. " - iXML SubCategory", true)
		if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
	end
end