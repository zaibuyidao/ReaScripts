-- NoIndex: true
-- Script generated by Lokasenna's GUI Builder

local lib_path = reaper.GetExtState("GUILibrary", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please install 'Get Lokasenna_GUI library', available on ReaPack, then run the 'Set Lokasenna_GUI library.lua' script in your Action List.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Listbox.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Textbox.lua")()
GUI.req("Classes/Class - TextEditor.lua")()
GUI.req("Classes/Class - Menubox.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

-- GUI.name = "UCS Tag Search"
-- GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 752, 456
-- GUI.anchor, GUI.corner = "mouse", "C"

GUI.New("edittext_filter", "Textbox", {
    z = 11,
    x = 16,
    y = 16,
    w = 400,
    h = 20,
    caption = "",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("edittext_search", "Textbox", {
    z = 11,
    x = 16,
    y = 416,
    w = 608,
    h = 20,
    caption = "",
    cap_pos = "left",
    font_a = 3,
    font_b = "monospace",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})

GUI.New("btn_filter", "Button", {
    z = 11,
    x = 432,
    y = 16,
    w = 80,
    h = 24,
    caption = "Filter",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame"
})

GUI.New("btn_clear", "Button", {
    z = 11,
    x = 528,
    y = 16,
    w = 96,
    h = 24,
    caption = "Clear",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame"
})

GUI.New("btn_search", "Button", {
    z = 11,
    x = 640,
    y = 376,
    w = 96,
    h = 24,
    caption = "Search",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame"
})

GUI.New("btn_search_close", "Button", {
    z = 11,
    x = 640,
    y = 408,
    w = 96,
    h = 24,
    caption = "Close",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame"
})

GUI.New("menu_lang", "Menubox", {
    z = 11,
    x = 640,
    y = 16,
    w = 96,
    h = 20,
    caption = "",
    optarray = {"!English", "简体中文", "正體中文"},
    retval = 1,
    font_a = 3,
    font_b = 4,
    col_txt = "txt",
    col_cap = "txt",
    bg = "wnd_bg",
    pad = 4,
    noarrow = false,
    align = 0
})

GUI.New("list_category", "Listbox", {
    z = 11,
    x = 16,
    y = 48,
    w = 192,
    h = 352,
    list = {"Item 1", "Item 2", "Item 3", "Item 4"},
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4
})

GUI.New("list_subcategory", "Listbox", {
    z = 11,
    x = 224,
    y = 48,
    w = 192,
    h = 352,
    list = {"Item 1", "Item 2", "Item 3", "Item 4"},
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4
})

GUI.New("list_synonym", "Listbox", {
    z = 11,
    x = 432,
    y = 48,
    w = 192,
    h = 352,
    list = {"Item 1", "Item 2", "Item 3", "Item 4"},
    multi = false,
    caption = "",
    font_a = 3,
    font_b = 4,
    color = "txt",
    col_fill = "elm_fill",
    bg = "elm_bg",
    cap_bg = "wnd_bg",
    shadow = true,
    pad = 4
})

GUI.New("check_cat", "Checklist", {
    z = 11,
    x = 640,
    y = 48,
    w = 96,
    h = 128,
    caption = "",
    optarray = {"CatID", "CatShort", "UCS list", "Custom", "Send now"},
    dir = "v",
    pad = 4,
    font_a = 2,
    font_b = 3,
    col_txt = "txt",
    col_fill = "elm_fill",
    bg = "wnd_bg",
    frame = false,
    shadow = true,
    swap = false,
    opt_size = 20
})

GUI.New("radio_connect", "Radio", {
    z = 11,
    x = 640,
    y = 176,
    w = 96,
    h = 176,
    caption = "", -- Condition
    optarray = {"Default", "AND", "OR", "NOT", "\"\"", "^", "$"},
    dir = "v",
    font_a = 2,
    font_b = 3,
    col_txt = "txt",
    col_fill = "elm_fill",
    bg = "wnd_bg",
    frame = false,
    shadow = true,
    swap = false,
    opt_size = 20
})
