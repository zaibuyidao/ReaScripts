-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua"

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

setGlobalStateSection("KEYWORD_SEARCH")

function getConfig(configName, default, convert)
	local cur = CONFIG
	for k in configName:gmatch("[^%.]+") do
		if not cur then return default end
		cur = cur[k]
	end
	if not cur then return default end
	if convert then
		return convert(cur)
	end
	return cur
end

SIZE_UNIT = getConfig("ui.global.size_unit", 20)
dbList = getDbList()
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

local data = (function ()
	local data = {}
	local excludeDbName = getConfig("db.exclude_db", {}, table.arrayToTable)
	for _, db in ipairs(dbList) do
		if not excludeDbName[db.name] then
			local path, keywords = readViewModelFromReaperFileList(db.path, {
				excludeOrigin = getConfig("db.exclude_keyword_origin", {}, table.arrayToTable),
				delimiters = getConfig("db.delimiters", {})
			})
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
	return data
end)()

function searchKeyword(value, rating)
	local res = {}
	local index = 1
	for _, item in ipairs(data) do
		local caseSensitive = getConfig("search.case_sensitive")
		if value == "" or (caseSensitive and item.value:find(value)) or (not caseSensitive and item.value:lower():find(value:lower())) then
			table.insert(res, {
				index = index, -- for stable sort
				db = item.db,
				path = item.path,
				value = item.value,
				from = item.from,
				fromString = item.fromString
			})
			index = index + 1
		end
	end
	
	table.sort(res, function(a, b)
		local ra = getRating(a.value)
		local rb = getRating(b.value)
		if ra == rb then
			return a.index < b.index
		end
		return ra > rb
	end)
	return res
end

function init()
	JProject:new()
	window = jGui:new({
        title = getConfig("ui.window.title"),
        width = getState("WINDOW_WIDTH", nil, tonumber),
        height = getState("WINDOW_HEIGHT", nil, tonumber),
        x = getState("WINDOW_X", nil, tonumber),
        y = getState("WINDOW_Y", nil, tonumber),
        dockstate=getState("WINDOW_DOCK_STATE")
    })

	local lastSearchText
	local searchTextBox = jGuiTextInput:new()
	searchTextBox.x = 10
	searchTextBox.y = 10
	searchTextBox.width = 480
	searchTextBox.height = math.floor( SIZE_UNIT * 1.5 )
	searchTextBox.label_fontsize = math.floor( SIZE_UNIT * 1.5 )
	searchTextBox.label_align = "l"
	searchTextBox.label_font = getConfig("ui.global.font", "微软雅黑")
	searchTextBox.colors_label = getConfig("ui.search_box.colors_label") or searchTextBox.colors_label
	searchTextBox.color_focus_border = getConfig("ui.search_box.color_focus_border") or searchTextBox.color_focus_border
	searchTextBox.focus_index = window:getFocusIndex()
	searchTextBox.label_padding = 3
	function searchTextBox:onRightMouseClick() 
		searchTextBox.value = ""
		searchTextBox.label = ""
	end

	window:controlAdd(searchTextBox)

	local stateLabel = jGuiControl:new()
	stateLabel.width = SIZE_UNIT * 2.5
	stateLabel.x = window.width - stateLabel.width - 12
	stateLabel.y = 10
	stateLabel.label_fontsize = math.floor(SIZE_UNIT * 0.75)
	stateLabel.label_align = "r"
	stateLabel.label_font = getConfig("ui.global.font", "微软雅黑")
	stateLabel.border = false
	stateLabel.label = "()"
	window:controlAdd(stateLabel)
	
	window:setFocus(searchTextBox)

	jGuiHighlightControl = jGuiControl:new({highlight = {}, color_highlight = {1, .9, 0, .2},})
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
			c.label_fontsize = listView.itemHeight - 2
			c.label_align = "l"
			c.label_font = getConfig("ui.global.font", "微软雅黑") -- "Calibri"
			c.border = false
			c.border_focus = true
			c.x = x
			c.y = y

			local info = jGuiText:new()
			info.width = 40
			info.height = listView.itemHeight
			info.label_fontsize = math.floor((listView.itemHeight-2) / 2 + 4)
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
				incRating(listView.data[dataIndex].value)
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
		elseif key == 26162 then --f2
			resultListView:promptForJump()
		elseif key == 26163 then --f3
			resultListView:randomJump()
		elseif key == 26164 then --f4
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
			title = "跳轉目標",
			inputs = {
				{
					label = "行數",
					default = self.value,
					converter = tonumber
				}
			}
		})
		if args then
			self:jump(args[1])
		end
		HWND_KS = reaper.JS_Window_Find(getConfig("ui.window.title"),0)
		reaper.BR_Win32_SetFocus(HWND_KS)
		return
	end

	function resultListView:randomJump()
		if self.data and #self.data > 1 then
			self:jump(math.random(1, #self.data))
		end
	end

	function searchTextBox:promptForContent()
		local args = prompt({
			title = "音效搜索",
			inputs = {
				{
					label = "關鍵詞",
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
		window:setFocus(self)
		HWND_KS = reaper.JS_Window_Find(getConfig("ui.window.title"),0)
		reaper.BR_Win32_SetFocus(HWND_KS)
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
			resultListView:promptForJump()
		end
	end

	function searchTextBox:onMouseDoubleClick(x, y)
		self:promptForContent()
	end

	resultListView:addScrollListener(function () 
		stateLabel.label = "(" .. resultListView.firstIndex .. "/" .. #resultListView.data .. ")"
	end)

	function window:onResize()
		searchTextBox.width = self.width - 20
		stateLabel.x = window.width - stateLabel.width - 12
		resultListView.height = window.height - (SIZE_UNIT * 1.5 + 15) - 4
		resultListView:draw()
		self:controlInitAll()
	end

	function window:update()
		if lastSearchText ~= searchTextBox.value then
			lastSearchText = searchTextBox.value
			resultListView.data = searchKeyword(searchTextBox.value, ratings)
			resultListView.firstIndex = 1
			resultListView:draw()
			stateLabel.label = "(" .. resultListView.firstIndex .. "/" .. #resultListView.data .. ")"
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
		writeRatings()
	end

	window:onResize()
	window:init()
	window:controlInitAll()
	gfx.clear = getConfig("ui.window.background_color", 0, function (t) return t.r+t.g*256+t.b*65536 end)
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