-- NoIndex: true

function Msg(param) 
    reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ") 
    end
    reaper.ShowConsoleMsg("\n")
end

if not reaper.BR_Win32_SetFocus then
    local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
      Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("請右鍵單擊並安裝'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動REAPER並再次運行腳本，謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
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

base_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
    loadfile(reaper.GetResourcePath() .. "/Scripts/zaibuyidao Scripts/Development/Lokasenna_GUI Library/Set Lokasenna_GUI library.lua")()
    loadfile(base_path .. "/lib/utils.lua")()
    loadfile(base_path .. "/lib/ucs.lua")()
    loadfile(base_path .. "/lib/guis.lua")()
else
    loadfile(reaper.GetResourcePath() .. "\\Scripts\\zaibuyidao Scripts\\Development\\Lokasenna_GUI Library\\Set Lokasenna_GUI library.lua")()
    loadfile(base_path .. "\\lib\\utils.lua")()
    loadfile(base_path .. "\\lib\\ucs.lua")()
    loadfile(base_path .. "\\lib\\guis.lua")()
end

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
    
    search_text = text
    reaper.SetExtState("UCSTagSearch", "SearchText", search_text, false)

    if os ~= "Win32" and os ~= "Win64" then
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    else
        if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then
            -- reaper.SetToggleCommandState(32063, 42051, 0) -- 无效
            reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
        end
        -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
        reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x0020, 0, 0, 0) -- 空格
        reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x0008, 0, 0, 0) -- 退格
    end
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
    GUI.elms.edittext_search:val(orig .. append_pre .. append_after)
    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    GUI.elms.edittext_search:redraw()
end

function filter_pattern_match(text, pattern)
    -- 大小写敏感
    -- text:find(pattern)
    return text:lower():find(pattern:lower())
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
                return item.name:get(locale) .. "  [" .. item.name.cat_short .. "]"
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
                return item.name:get(locale) .. "  [" .. item.cat_id .. "]"
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
            if is_key_active(KEYS.CONTROL) then
                append_search(self.name_list[self:val()])
            elseif is_key_active(KEYS.SHIFT) then
                append_search(self.cat_egory_list[self:val()])
            elseif is_key_active(KEYS.ALT) then
                append_search(self.cat_short_list[self:val()])
            else
                append_search(self.cat_short_list[self:val()])
            end
        else
            if is_key_active(KEYS.SHIFT) then
                append_search(self.cat_egory_list[self:val()])
            elseif is_key_active(KEYS.ALT) then
                append_search(self.cat_short_list[self:val()])
            elseif is_key_active(KEYS.CONTROL) then
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
    end

    function GUI.elms.list_subcategory:ondoubleclick()
        if is_cat_id_enable() then
            if is_key_active(KEYS.CONTROL) then
                append_search(self.name_list[self:val()])
            elseif is_key_active(KEYS.SHIFT) then
                append_search(self.subcategory_en_list[self:val()])
            elseif is_key_active(KEYS.ALT) then
                append_search(self.cat_list[self:val()])
            else
                append_search(self.cat_list[self:val()])
            end
        else
            if is_key_active(KEYS.SHIFT) then
                append_search(self.subcategory_en_list[self:val()])
            elseif is_key_active(KEYS.ALT) then
                append_search(self.cat_list[self:val()])
            else
                append_search(self.name_list[self:val()])
            end
        end
    end

    function GUI.elms.list_subcategory:onvalchange()
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), 1)

        --if is_key_active(KEYS.CONTROL) then self:ondoubleclick() end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.list_synonym:ondoubleclick()
        if is_key_active(KEYS.SHIFT) then
            append_search(self.synonyms_en_list[self:val()])
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

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
        GUI.elms.edittext_filter.focus = true
    end

    -- function GUI.elms.btn_filter:ondoubleclick() -- 双击过滤按钮 清除
    --     GUI.elms.edittext_filter:val("")
    --     current_filter_pattern = ""
    --     GUI.elms.list_category:val(1)
    --     GUI.elms.list_subcategory:val(1)
    --     GUI.elms.list_synonym:val(1)
    --     update_usc_data()
    -- end

    function GUI.elms.btn_clear:func()
        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
        GUI.elms.edittext_filter.focus = true
    end

    function GUI.elms.menu_lang:onvalchange()
        switch_lang(GUI.elms.menu_lang:val())
        display_usc_data(cur_usc_data)
    end

    function GUI.elms.btn_search:func()
        send_search_text(GUI.elms.edittext_search:val())

        if GUI.elms.edittext_filter.focus == true then GUI.elms.edittext_filter.focus = false end
        GUI.elms.edittext_search.focus = true
        GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
    end

    function GUI.elms.edittext_search:onmousedown()
        GUI.elms.edittext_search:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")

            search_text = ""
            reaper.SetExtState("UCSTagSearch", "SearchText", search_text, false)
        end
        if is_key_active(KEYS.SHIFT) then
            send_search_text(GUI.elms.edittext_search:val())

            if GUI.elms.edittext_filter.focus == true then GUI.elms.edittext_filter.focus = false end
            GUI.elms.edittext_search.focus = true
            GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
        end
    end

    function GUI.elms.edittext_filter:onmousedown()
        GUI.elms.edittext_filter:_onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")
        end
    end

    function GUI.elms.edittext_search:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        end
    end

    function GUI.elms.edittext_filter:ondoubleclick()
        if is_key_active(KEYS.CONTROL) then
            copy_text(self:val())
        end
    end

    function GUI.elms.edittext_filter:onr_doubleclick() -- onr_doubleclick() 双击 onmouser_down() 单击
        self:val("")
    end

    function GUI.elms.edittext_search:onr_doubleclick()
        self:val("")
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

if reaper.APIExists("JS_Window_Find") then
    hwnd = reaper.JS_Window_Find(GUI.name, true)
    if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
else
    reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'. Then restart REAPER and run the script again. Thank you!\n\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。然後重新啟動 REAPER 並再次運行腳本。謝謝！", "你必須安裝 JS_ReaScriptAPI", 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, "Error", 0)
    end
    return reaper.defer(function() end)
end

local fonts = GUI.get_OS_fonts()
GUI.fonts.monospace = {fonts.mono, 14}
GUI.fonts[4] = {fonts.sans, 16}
GUI.fonts[3] = {fonts.sans, 16}
GUI.fonts.version = {fonts.sans, 12, "i"}
GUI.colors.white = {225, 225, 225, 255} -- Set gui.lua [color = "white"]
GUI.Draw_Version = function ()
    if not GUI.version then return 0 end
    local str = "Script by 再補一刀  -  using Lokasenna_GUI " .. GUI.version
    GUI.font("version")
    GUI.color("txt")
    local str_w, str_h = gfx.measurestr(str)
    -- gfx.x = gfx.w/2 - str_w/2
    -- gfx.y = gfx.h - str_h - 4
    gfx.x = gfx.w - str_w - 6
    gfx.y = gfx.h - str_h - 4
    gfx.drawstr(str)
end

GUI.elms.check_cat:val({[1] = true, [2] = false, [3] = true, [4] = true})
switch_lang(1)

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

local search_text = reaper.GetExtState("UCSTagSearch", "SearchText")
if search_text ~= "" then
    GUI.elms.edittext_search:val(search_text)
    GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
end

GUI.freq = 0 -- 或者 0.05
-- text_box = true
GUI.elms.edittext_filter.focus = true

local function force_size() -- 锁定GUI边界
    gfx.quit()
    gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock, GUI.x, GUI.y)
    GUI.cur_w, GUI.cur_h = GUI.w, GUI.h
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
    if char == 13 then -- Enter 键
        if is_key_active(KEYS.CONTROL) then -- 同时按住Ctrl
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()

            if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
            GUI.elms.edittext_filter.focus = true
        else 
            send_search_text(GUI.elms.edittext_search:val())

            if GUI.elms.edittext_filter.focus == true then GUI.elms.edittext_filter.focus = false end
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

        if GUI.elms.edittext_search.focus == true then GUI.elms.edittext_search.focus = false end
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
        -- if text_box == false then
        --     GUI.elms.edittext_search.focus = false
        --     GUI.elms.edittext_filter.focus = true
        --     GUI.elms.edittext_filter.show_caret = true
        --     --GUI.elms.edittext_filter.caret = GUI.elms.edittext_search:carettoend()
        --     --GUI.elms.edittext_filter:redraw()
        --     text_box = true
        -- else
        --     GUI.elms.edittext_filter.focus = false
        --     GUI.elms.edittext_search.focus = true
        --     GUI.elms.edittext_search.show_caret = true
        --     GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
        --     --GUI.elms.edittext_search:redraw()
        --     text_box = false
        -- end
    end

    if char == 6697266 then -- F12
        local text = reaper.GetExtState("UCSTagSearch", "Input")
        if (text == "") then text = "" end
        userok, text = reaper.GetUserInputs("UCS Tag Search", 1, "Keywords 關鍵詞,extrawidth=100", text)
        if not userok then return end
        reaper.SetExtState("UCSTagSearch", "Input", text, false)

        if GUI.elms.edittext_filter.focus == true then
            GUI.elms.edittext_filter:val(text)
            GUI.elms.edittext_filter.caret = GUI.elms.edittext_filter:carettoend()
            GUI.elms.edittext_filter:redraw()
        else
            append_search(text)
            -- GUI.elms.edittext_search:val(text)
            -- GUI.elms.edittext_search.caret = GUI.elms.edittext_search:carettoend()
            -- GUI.elms.edittext_search:redraw()
        end
        HWND_USC = reaper.JS_Window_Find("UCS Tag Search",0)
        reaper.BR_Win32_SetFocus(HWND_USC)
    end

    GUI.onresize = force_size
end

GUI.Main()
