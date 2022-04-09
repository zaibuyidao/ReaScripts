-- @description UCS Tags Search
-- @version 1.0.1
-- @author zaibuyidao
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @provides
--   [main] .
--   [nomain] lib/gui.lua
--   [nomain] lib/ucs.lua
--   [nomain] lib/utils.lua
--   UCS_list.csv
--   UCS_list_custom.csv
-- @donation http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ") 
    end
    reaper.ShowConsoleMsg("\n")
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
    { id = "tw", name = '正体中文' }
}

base_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]

loadfile(reaper.GetResourcePath() .. '\\Scripts\\zaibuyidao Scripts\\Development\\Lokasenna_GUI Library\\Set Lokasenna_GUI library path.lua')()
--loadfile(base_path .. "GUILibrary\\Set Lokasenna_GUI Library path.lua")() -- 同级目录下
loadfile(base_path .. "\\lib\\utils.lua")()
loadfile(base_path .. "\\lib\\ucs.lua")()
loadfile(base_path .. "\\lib\\gui.lua")()

local full_usc_data
local cur_usc_data
local current_filter_pattern = ""

function should_load_system_usc_data()
    return GUI.elms.check_cat:val()[2] == true
end

function should_load_user_usc_data()
    return GUI.elms.check_cat:val()[3] == true
end

function is_cat_id_enable()
    return GUI.elms.check_cat:val()[1] == true
end

function reload_usc_data()
    full_usc_data = {}
    if should_load_system_usc_data() then
        usc.read_from_csv(base_path .. "UCS_List.csv", full_usc_data)
    end
    if should_load_user_usc_data() then
        usc.read_from_csv(base_path .. "UCS_List_custom.csv", full_usc_data)
    end
end

function is_key_active(key)
    if GUI.mouse.cap & key == key then return true end
    return false
end

function switch_lang(index)
    GUI.elms.menu_lang:val(index)
    local optarray = table.map(LANGS, function (item) return item.name end)
    optarray[GUI.elms.menu_lang:val()] = "!" .. optarray[GUI.elms.menu_lang:val()]
    GUI.elms.menu_lang.optarray = optarray
end

function copy_text(text)  --复制关键词
    if text == '' then return end
    reaper.CF_SetClipboard(text)
end

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer","common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end
    reaper.JS_Window_SetTitle(search, text)

    -- https://github.com/justinfrankel/WDL/blob/main/WDL/swell/swell-types.h
    reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x0020, 0, 0, 0) -- 空格
    reaper.JS_WindowMessage_Post(search, "WM_KEYUP", 0x0008, 0, 0, 0) -- 退格
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

function display_usc_data(data)
    
    local orig_list_category_val = GUI.elms.list_category:val()
    local orig_list_subcategory_val = GUI.elms.list_subcategory:val()
    local orig_list_synonym_val = GUI.elms.list_synonym:val()

    function update_category(category_index)
        local locale = get_locale()
        GUI.elms.list_category.list = table.map(data, function(item)
            return item.name:get(locale)
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
        GUI.elms.list_subcategory.list = table.map(data[category_index].children, function (item)
            return item.name:get(locale) .. "  [" .. item.cat_id .. "]"
        end)
        GUI.elms.list_subcategory.name_list = table.map(data[category_index].children, function (item)
            return item.name:get(locale)
        end)
        GUI.elms.list_subcategory.cat_list = table.map(data[category_index].children, function (item)
            return item.cat_id
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
        append_search(self.list[self:val()])
    end

    function GUI.elms.list_category:onvalchange()
        update_subcategory(self:val(), 1)
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), GUI.elms.list_synonym:val())

        --if is_key_active(KEYS.CONTROL) then append_search(self.list[self:val()]) end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.list_subcategory:ondoubleclick()
        if is_cat_id_enable() then
            append_search(self.cat_list[self:val()])
        else 
            append_search(self.name_list[self:val()])
        end
    end

    function GUI.elms.list_subcategory:onvalchange()
        update_synonym(GUI.elms.list_category:val(), GUI.elms.list_subcategory:val(), 1)

        --if is_key_active(KEYS.CONTROL) then self:ondoubleclick() end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.list_synonym:ondoubleclick()
        append_search(self.list[self:val()])
    end

    function GUI.elms.list_synonym:onvalchange()
        --if is_key_active(KEYS.CONTROL) then append_search(self.list[self:val()]) end -- Ctrl+单击添加关键词进搜索框
    end

    function GUI.elms.btn_filter:func()
        if #GUI.elms.edittext_filter:val() < 1 then return end
        current_filter_pattern = GUI.elms.edittext_filter:val()
        update_usc_data()
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
    end

    function GUI.elms.menu_lang:onvalchange()
        switch_lang(GUI.elms.menu_lang:val())
        display_usc_data(cur_usc_data)
    end

    function GUI.elms.btn_search:func()
        send_search_text(GUI.elms.edittext_search:val())
    end

    function GUI.elms.edittext_search:onmousedown()
        if is_key_active(KEYS.ALT) then
            self:val("")
        end
        if is_key_active(KEYS.SHIFT) then
            send_search_text(GUI.elms.edittext_search:val())
        end
    end

    function GUI.elms.edittext_filter:onmousedown()
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

    function GUI.elms.edittext_filter:onmouser_down() -- onr_doubleclick() 右键双击
        self:val("")
    end

    function GUI.elms.edittext_search:onmouser_down()
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

if reaper.JS_Window_FindEx then
    hwnd = reaper.JS_Window_Find(GUI.name, true)
    if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
else
    local retval = reaper.ShowMessageBox("js_ReaScriptAPI extension is required by this script. Do you want to download it now ?", "Warning", 1)
    if retval == 1 then
      Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
end

GUI.elms.check_cat:val({[1] = false, [2] = true, [3] = true})
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

reload_usc_data()
update_usc_data()

GUI.freq = 0 -- 或者 0.05 
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

    -- 键值处理
    local char = GUI.char
    if char == 13 then -- Enter 键
        if is_key_active(KEYS.CONTROL) then    -- 同时按住Ctrl
            current_filter_pattern = GUI.elms.edittext_filter:val()
            update_usc_data()
        else 
            send_search_text(GUI.elms.edittext_search:val())
        end
    elseif char == 26165 then --F5键
        --print("f5")
        GUI.elms.edittext_filter:val("")
        current_filter_pattern = ""
        GUI.elms.list_category:val(1)
        GUI.elms.list_subcategory:val(1)
        GUI.elms.list_synonym:val(1)
        update_usc_data()
    end
end

GUI.Main()
