-- @description Reposition Items
-- @version 1.3.5
-- @author zaibuyidao
-- @changelog Add multilingual support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
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

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

function get_item_pos()
    local t = {}
    for i = 1, reaper.CountSelectedMediaItems(0) do
        t[i] = {}
        local item = reaper.GetSelectedMediaItem(0, i-1)
        track = reaper.GetMediaItem_Track(item)
        take = reaper.GetActiveTake(item)

        if item ~= nil then
            t[i].item = item
            t[i].pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            t[i].len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            t[i].pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
            t[i].takename = reaper.GetTakeName(take)
        end
    end
    return t
end

sort_func = function(a,b)
    if (a.pos == b.pos) then
        return a.pitch < b.pitch
    end
    if (a.pos < b.pos) then
        return true
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local interval = reaper.GetExtState("REPOSITION_ITEMS", "Interval")
local toggle = reaper.GetExtState("REPOSITION_ITEMS", "Toggle")
local mode = reaper.GetExtState("REPOSITION_ITEMS", "Mode")
if (interval == "") then interval = "1" end
if (toggle == "") then toggle = "end" end
if (mode == "") then mode = "timeline" end

if language == "简体中文" then
    title = "重新定位对象"
    uok, uinput = reaper.GetUserInputs(title, 3, "间隔 (秒),位置 (start/end),模式 (track/warp/timeline)", interval .. ',' .. toggle .. ',' .. mode)
elseif language == "繁体中文" then
    title = "重新定位對象"
    uok, uinput = reaper.GetUserInputs(title, 3, "間隔 (秒),位置 (start/end),模式 (track/warp/timeline)", interval .. ',' .. toggle .. ',' .. mode)
else
    title = "Reposition Items"
    uok, uinput = reaper.GetUserInputs(title, 3, "Time interval (s),Add to (start/end),Mode (track/warp/timeline)", interval .. ',' .. toggle .. ',' .. mode)
end

interval, toggle, mode = uinput:match("(.*),(.*),(.*)")
if not uok or not tonumber(interval) or not tostring(toggle) or not tostring(mode) then return end

reaper.SetExtState("REPOSITION_ITEMS", "Interval", interval, false)
reaper.SetExtState("REPOSITION_ITEMS", "Toggle", toggle, false)
reaper.SetExtState("REPOSITION_ITEMS", "Mode", mode, false)

if mode == "track" then
    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local track = reaper.GetMediaItem_Track(item)
        local count_track_items = reaper.CountTrackMediaItems(track)
        sel_item_track = {}
        item_num_new = {}
        item_num_order = 1 
      
        for j = 0, count_track_items - 1 do
            local item = reaper.GetTrackMediaItem(track, j)
            if reaper.IsMediaItemSelected(item) == true then
                sel_item_track[item_num_order] = item
                item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
                item_num_order = item_num_order + 1
            end
        end
  
        for k = 1, item_num_order - 1 do
            local item_next_start = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_POSITION")
            local item_next_end = reaper.GetMediaItemInfo_Value(sel_item_track[k], "D_LENGTH") + item_next_start

            if k < item_num_order - 1 then
                if toggle == "end" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item_next_end + interval)
                elseif toggle == "start" then
                    reaper.SetMediaItemInfo_Value(sel_item_track[k + 1], "D_POSITION", item_next_start + interval)
                end
            end
        end
    end
elseif mode == "warp" then
    local item_list = {}
    
    for i = 0, count_sel_items - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        table.insert(item_list, item)
    end
    
    for k, item in ipairs(item_list) do
        local item_next_start = reaper.GetMediaItemInfo_Value(item_list[k], "D_POSITION")
        local item_next_end = reaper.GetMediaItemInfo_Value(item_list[k], "D_LENGTH") + item_next_start

        if k < count_sel_items then
            if toggle == "end" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_end + interval)
            elseif toggle == "start" then
                reaper.SetMediaItemInfo_Value(item_list[k + 1], "D_POSITION", item_next_start + interval)
            end
        end
    end
elseif mode == "timeline" then
    local data = get_item_pos()
    table.sort(data, sort_func)

    for i = 1, #data do
        local item_next_start = reaper.GetMediaItemInfo_Value(data[i].item, "D_POSITION")
        local item_next_end = reaper.GetMediaItemInfo_Value(data[i].item, "D_LENGTH") + item_next_start

        if i < #data then
            if toggle == "end" then
                reaper.SetMediaItemInfo_Value(data[i+1].item, "D_POSITION", item_next_end + interval)
            elseif toggle == "start" then
                reaper.SetMediaItemInfo_Value(data[i+1].item, "D_POSITION", item_next_start + interval)
            end
        end
    end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()