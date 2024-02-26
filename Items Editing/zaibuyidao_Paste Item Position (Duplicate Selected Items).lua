-- @description Paste Item Position (Duplicate Selected Items)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ")
    end
    reaper.ShowConsoleMsg("\n")
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
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁體中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
end
  
if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
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
  
if not reaper.APIExists("JS_Window_Find") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
end

local function unserialize(lua)
    if lua == nil or lua == "" then
        return nil
    end
    local func, err = load("return " .. lua)
    if not func then error("cannot unserialize: " .. err) end
    return func()
end

local EXT_SECTION = 'COPY_ITEM_POSITION'
reaper.Undo_BeginBlock()

local cur_pos = reaper.GetCursorPosition()
local positionsStr = reaper.GetExtState(EXT_SECTION, "Position")
if positionsStr == "" then
    if language == "简体中文" then
        reaper.ShowMessageBox("未找到保存的对象位置数据。", "错误", 0)
    elseif language == "繁體中文" then
        reaper.ShowMessageBox("未找到保存的對象位置數據。", "錯誤", 0)
    else
        reaper.ShowMessageBox("Saved project position data not found.", "Error", 0)
    end
    return
end

local positions = unserialize(positionsStr)
if positions == nil then
    if language == "简体中文" then
        reaper.ShowMessageBox("位置数据格式错误或损坏。", "错误", 0)
    elseif language == "繁體中文" then
        reaper.ShowMessageBox("位置數據格式錯誤或損壞。", "錯誤", 0)
    else
        reaper.ShowMessageBox("Position data format error or corruption.", "Error", 0)
    end
    return
end

local itemCount = reaper.CountSelectedMediaItems(0)
if itemCount > #positions then
    if language == "简体中文" then
        reaper.ShowMessageBox("粘贴的对象数量不能超过复制的对象数量。", "错误", 0)
    elseif language == "繁體中文" then
        reaper.ShowMessageBox("貼上的對象數量不能超過複製的對象數量。", "錯誤", 0)
    else
        reaper.ShowMessageBox("The number of pasted items cannot exceed the number of copied items.", "Error", 0)
    end
    return
end

reaper.Main_OnCommand(40698, 0) -- 编辑: 复制对象 ⇌ Edit: Copy items

if #positions > 0 then
    reaper.SetEditCurPos(positions[1], false, false)
    reaper.Main_OnCommand(42398, 0) -- 对象: 粘贴对象/轨道 ⇌ Item: Paste items/tracks
end

local new_items = reaper.CountSelectedMediaItems(0)
for i = 0, new_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if positions[i+1] then
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", positions[i+1])
    end
end

reaper.SetEditCurPos(cur_pos, false, false)
if language == "简体中文" then
    reaper.Undo_EndBlock("粘贴对象位置(重复选定对象)", -1)
elseif language == "繁體中文" then
    reaper.Undo_EndBlock("貼上對象位置(重複選取對象)", -1)
else
    reaper.Undo_EndBlock("Paste Item Position (Duplicate Selected Items)", -1)
end