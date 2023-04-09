-- NoIndex: true
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

setGlobalStateSection("UCS_TAG_SEARCH")

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
    WINDOW_NAME = "UCS 标签搜索器"
    FONT_SANS = "SimSun" -- "SimSun"、"Microsoft YaHei"、"Calibri"、"华文中宋"、"华文宋体"、"华文细黑"
    FONT_MONO = "SimSun"
    FONT_SIZE_2 = 14
    FONT_SIZE_3 = 14
    FONT_SIZE_4 = 14
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "搜索"
    SEARCH_TITLE_KEY = "关键词"
    FILTER_TITLE = "过滤"
    FILTER_TITLE_KEY = "关键词"
elseif language == "繁体中文" then
    WINDOW_NAME = "UCS 標簽搜索器"
    FONT_SANS = "SimSun" -- "SimSun" "Microsoft YaHei" "Calibri"
    FONT_MONO = "SimSun"
    FONT_SIZE_2 = 14
    FONT_SIZE_3 = 14
    FONT_SIZE_4 = 14
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "搜索"
    SEARCH_TITLE_KEY = "关键词"
    FILTER_TITLE = "過濾"
    FILTER_TITLE_KEY = "关键词"
else
    WINDOW_NAME = "UCS Tag Search"
    FONT_SANS = "Calibri"
    FONT_MONO = "Consolas"
    FONT_SIZE_2 = 16
    FONT_SIZE_3 = 16
    FONT_SIZE_4 = 16
    FONT_SIZE_M = 14
    FONT_SIZE_V = 12
    SEARCH_TITLE = "Search"
    SEARCH_TITLE_KEY = "Keywords"
    FILTER_TITLE = "Filter"
    FILTER_TITLE_KEY = "Keywords"
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
require('guis')

GUI.name = WINDOW_NAME
GUI.x = getState("WINDOW_X", 50, tonumber)
GUI.y = getState("WINDOW_Y", 50, tonumber)
GUI.w = getState("WINDOW_WIDTH", 752, tonumber)
GUI.h = getState("WINDOW_HEIGHT", 456, tonumber)
dockstate = getState("WINDOW_DOCK_STATE")

local full_usc_data
local cur_usc_data
local current_filter_pattern = ""

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

function is_immediately_enable() -- 启用立刻搜索
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
    reaper.SetExtState("UCS_TAG_SEARCH", "SEARCH_TEXT", text, false)

    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    else
        if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then
            reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0) -- reaper.SetToggleCommandState(32063, 42051, 0) -- 无效
        end
        -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
        -- reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x20, 0, 0, 0) -- 空格
        reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x20, 0,0,0)
    end
end

function replace_cat_id(cat_id)
    local et = GUI.elms.edittext_search
    local orig = et:val() or ""

    -- 分割原始文本
    local words = {}
    for word in orig:gmatch("%S+") do
        table.insert(words, word)
    end

    -- 查找并替换旧的 cat_id
    local replaced = false
    for i, word in ipairs(words) do
        local cat_word = word

        -- 检查连接符并保存连接符
        local prefix_connector = ""
        local suffix_connector = ""

        if cat_word:match("^\"") and cat_word:match("\"$") then
            cat_word = cat_word:gsub("^\"", ""):gsub("\"$", "")
            prefix_connector = "\""
            suffix_connector = "\""
        elseif cat_word:match("^%^") then
            cat_word = cat_word:gsub("^%^", "")
            prefix_connector = "^"
        elseif cat_word:match("%$$") then
            cat_word = cat_word:gsub("%$$", "")
            suffix_connector = "$"
        end

        if cat_word == et.cat_id then
            words[i] = prefix_connector .. cat_id .. suffix_connector
            replaced = true
            break
        end
    end

    -- 如果没有找到旧的 cat_id，将新的 cat_id 添加到末尾
    if not replaced then
        local connect = GUI.elms.radio_connect.optarray[GUI.elms.radio_connect:val()]
        local append_after = ""
        if connect == "Default" then
            append_after = cat_id
        elseif connect == "$" then
            append_after = cat_id .. connect
        elseif connect == "\"\"" then
            append_after = "\"" .. cat_id .. "\""
        elseif connect == "^" then
            append_after = connect .. cat_id
        else
            append_after = connect .. " " .. cat_id
        end
        table.insert(words, append_after)
    end

    -- 更新搜索文本和 cat_id
    local new_val = table.concat(words, " ")
    et:val(new_val)
    et.cat_id = cat_id
    et.caret = et:carettoend()
    et:redraw()
end

function replace_cat_short(cat_short)
    local et = GUI.elms.edittext_search
    local orig = et:val() or ""

    -- 分割原始文本
    local words = {}
    for word in orig:gmatch("%S+") do
        table.insert(words, word)
    end

    -- 查找并替换旧的 cat_short
    local replaced = false
    for i, word in ipairs(words) do
        local cat_word = word

        -- 检查连接符并保存连接符
        local prefix_connector = ""
        local suffix_connector = ""

        if cat_word:match("^\"") and cat_word:match("\"$") then
            cat_word = cat_word:gsub("^\"", ""):gsub("\"$", "")
            prefix_connector = "\""
            suffix_connector = "\""
        elseif cat_word:match("^%^") then
            cat_word = cat_word:gsub("^%^", "")
            prefix_connector = "^"
        elseif cat_word:match("%$$") then
            cat_word = cat_word:gsub("%$$", "")
            suffix_connector = "$"
        end

        if cat_word == et.cat_short then
            words[i] = prefix_connector .. cat_short .. suffix_connector
            replaced = true
            break
        end
    end

    -- 如果没有找到旧的 cat_short，将新的 cat_short 添加到末尾
    if not replaced then
        local connect = GUI.elms.radio_connect.optarray[GUI.elms.radio_connect:val()]
        local append_after = ""
        if connect == "Default" then
            append_after = cat_short
        elseif connect == "$" then
            append_after = cat_short .. connect
        elseif connect == "\"\"" then
            append_after = "\"" .. cat_short .. "\""
        elseif connect == "^" then
            append_after = connect .. cat_short
        else
            append_after = connect .. " " .. cat_short
        end
        table.insert(words, append_after)
    end

    -- 更新搜索文本和 cat_short
    local new_val = table.concat(words, " ")
    et:val(new_val)
    et.cat_short = cat_short
    et.caret = et:carettoend()
    et:redraw()
end

function append_search(text)
    local orig = GUI.elms.edittext_search:val()
    local append_pre = ""
    if #orig > 0 then append_pre = " " end
    local connect = GUI.elms.radio_connect.optarray[GUI.elms.radio_connect:val()]
    local append_after = ""
    if connect == "Default" then
        append_after = text
    elseif connect == "$" then
        append_after = text .. connect
    elseif connect == "\"\"" then
        append_after = "\"" .. text .. "\""
    elseif connect == "^" then
        append_after = connect .. text
    else
        append_after = connect .. " " .. text
    end
    if append_after == nil then append_after = "" end
    GUI.elms.edittext_search:val(orig .. append_pre .. append_after)
    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    GUI.elms.edittext_search:redraw()
end

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
            if is_immediately_enable() then
                local text = ""
                if is_key_active(KEYS.CONTROL) then
                    text = self.name_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.SHIFT) then
                    text = self.cat_egory_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.ALT) then
                    text = self.cat_short_list[self:val()]
                    send_search_text(text)
                else
                    text = self.cat_short_list[self:val()]
                    send_search_text(text)
                end

                GUI.elms.edittext_search:val(text)
                GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
                GUI.elms.edittext_search:redraw()
    
                GUI.elms.edittext_search.focus = true
                GUI.elms.edittext_filter.focus = false
            else
                if is_key_active(KEYS.CONTROL) then
                    append_search(self.name_list[self:val()])
                elseif is_key_active(KEYS.SHIFT) then
                    append_search(self.cat_egory_list[self:val()])
                elseif is_key_active(KEYS.ALT) then
                    replace_cat_short(self.cat_short_list[self:val()])
                else
                    replace_cat_short(self.cat_short_list[self:val()])
                end
            end
        else
            if is_immediately_enable() then
                local text = ""
                if is_key_active(KEYS.SHIFT) then
                    text = self.cat_egory_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.ALT) then
                    text = self.cat_short_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.CONTROL) then
                    text = self.name_list[self:val()]
                    send_search_text(text)
                else
                    text = self.name_list[self:val()]
                    send_search_text(text)
                end

                GUI.elms.edittext_search:val(text)
                GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
                GUI.elms.edittext_search:redraw()
    
                GUI.elms.edittext_search.focus = true
                GUI.elms.edittext_filter.focus = false
            else
                if is_key_active(KEYS.SHIFT) then
                    append_search(self.cat_egory_list[self:val()])
                elseif is_key_active(KEYS.ALT) then
                    replace_cat_short(self.cat_short_list[self:val()])
                elseif is_key_active(KEYS.CONTROL) then
                    append_search(self.name_list[self:val()])
                else
                    append_search(self.name_list[self:val()])
                end
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
            if is_immediately_enable() then -- 激活立即发送
                local text = ""
                if is_key_active(KEYS.CONTROL) then
                    text = self.name_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.SHIFT) then
                    text = self.subcategory_en_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.ALT) then
                    text = self.cat_list[self:val()]
                    send_search_text(text)
                else
                    text = self.cat_list[self:val()]
                    send_search_text(text) -- 替換cat_id
                end

                GUI.elms.edittext_search:val(text)
                GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
                GUI.elms.edittext_search:redraw()
    
                GUI.elms.edittext_search.focus = true
                GUI.elms.edittext_filter.focus = false
            else
                if is_key_active(KEYS.CONTROL) then
                    append_search(self.name_list[self:val()])
                elseif is_key_active(KEYS.SHIFT) then
                    append_search(self.subcategory_en_list[self:val()])
                elseif is_key_active(KEYS.ALT) then
                    replace_cat_id(self.cat_list[self:val()])
                else
                    -- append_search(self.cat_list[self:val()])
                    replace_cat_id(self.cat_list[self:val()]) -- 替換cat_id
                end
            end
        else
            if is_immediately_enable() then
                local text = ""
                if is_key_active(KEYS.SHIFT) then
                    text = self.subcategory_en_list[self:val()]
                    send_search_text(text)
                elseif is_key_active(KEYS.ALT) then
                    text = self.cat_list[self:val()]
                    replace_cat_id(text)
                else
                    text = self.name_list[self:val()]
                    send_search_text(text)
                end

                GUI.elms.edittext_search:val(text)
                GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
                GUI.elms.edittext_search:redraw()
    
                GUI.elms.edittext_search.focus = true
                GUI.elms.edittext_filter.focus = false
            else
                if is_key_active(KEYS.SHIFT) then
                    append_search(self.subcategory_en_list[self:val()])
                elseif is_key_active(KEYS.ALT) then
                    replace_cat_id(self.cat_list[self:val()])
                else
                    append_search(self.name_list[self:val()])
                end
            end
        end
    end

    function GUI.elms.list_subcategory:onvalchange()
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), 1)
        --if is_key_active(KEYS.CONTROL) then self:ondoubleclick() end -- Ctrl+单击添加关键词进搜索框
        GUI.elms.list_synonym:scroll_to_top()
    end

    function GUI.elms.list_synonym:ondoubleclick()
        if is_immediately_enable() then
            local text = ""
            if is_key_active(KEYS.SHIFT) then
                text = self.synonyms_en_list[self:val()]
                send_search_text(text)
            else
                text = self.list[self:val()]
                send_search_text(text)
            end

            GUI.elms.edittext_search:val(text)
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            GUI.elms.edittext_search:redraw()

            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_filter.focus = false
        else
            if is_key_active(KEYS.SHIFT) then
                append_search(self.synonyms_en_list[self:val()])
            else
                append_search(self.list[self:val()])
            end
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
        send_search_text(GUI.elms.edittext_search:val())

        GUI.elms.edittext_filter.focus = false
        GUI.elms.edittext_search.focus = true
        GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    end

    function GUI.elms.btn_search_close:func()
        gfx.quit()
    end

    function GUI.elms.edittext_search:onmousedown()
        GUI.elms.edittext_search:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")

            search_text = ""
            reaper.SetExtState("UCS_TAG_SEARCH", "SEARCH_TEXT", search_text, false)
        end
        if is_key_active(KEYS.SHIFT) then -- 发送搜索
            send_search_text(GUI.elms.edittext_search:val())

            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            GUI.elms.edittext_search:redraw()

            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_filter.focus = false
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
            local userok, text = reaper.GetUserInputs(FILTER_TITLE, 1, FILTER_TITLE_KEY .. ",extrawidth=200", text)
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
            local userok, text = reaper.GetUserInputs(SEARCH_TITLE, 1, SEARCH_TITLE_KEY .. ",extrawidth=200", text)
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
    --     self:undo()
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

local search_text = reaper.GetExtState("UCS_TAG_SEARCH", "SEARCH_TEXT") -- 搜索框默认值
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

-- if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then -- 获取切换Enter搜素的状态
--     local title = reaper.JS_Localize("Media Explorer", "common")
--     local hwnd = reaper.JS_Window_Find(title, true)
--     reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
--     --reaper.SetToggleCommandState(32063, 42051, 1)
-- end

function GUI.func()

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

    if char == 13 then -- Enter 键
        if is_key_active(KEYS.CONTROL) then -- 同时按住Ctrl
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()

            GUI.elms.edittext_search.focus = false
            GUI.elms.edittext_filter.focus = true
        else 
            send_search_text(GUI.elms.edittext_search:val())

            GUI.elms.edittext_filter.focus = false
            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
        end
    elseif char == 26165 then -- F5 键
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

    -- if char == 26162 then -- F2 键
    --     if is_cat_short_enable() then
    --         GUI.elms.check_cat:val({[2] = false})
    --     else
    --         GUI.elms.check_cat:val({[2] = true})
    --     end
    -- end

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

    if char == 26162 then -- F2 键
        if is_immediately_enable() then
            GUI.elms.check_cat:val({[5] = false})
        else
            GUI.elms.check_cat:val({[5] = true})
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
        local userok, text = reaper.GetUserInputs(FILTER_TITLE, 1, FILTER_TITLE_KEY .. ",extrawidth=200", text)
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
        userok, text = reaper.GetUserInputs(SEARCH_TITLE, 1, SEARCH_TITLE_KEY .. ",extrawidth=200", text)
        if not userok then return setFocusToWindow(WINDOW_NAME) end

        if is_immediately_enable() then
            send_search_text(text)
            GUI.elms.edittext_search:val(text)
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            GUI.elms.edittext_search:redraw()

            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_filter.focus = false
        else
            reaper.SetExtState("UCS_TAG_SEARCH", "SEARCH_TEXT", text, false)
            GUI.elms.edittext_search:val(text)
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            GUI.elms.edittext_search:redraw()

            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_filter.focus = false
        end

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
