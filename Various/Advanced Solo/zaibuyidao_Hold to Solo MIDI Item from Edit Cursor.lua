-- NoIndex: true
local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
    dofile(ZBYDFuncPath)
    if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
    local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
    "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
    ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
    "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
    ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

    reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

    if reaper.APIExists('ReaPack_BrowsePackages') then
        reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
    else
        local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
        "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
        "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

        reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
    end
    return
end

item_restores = {}

function restore_items()
    -- 恢复items的状态
    for i = #item_restores, 1, -1 do
        item_restores[i]()
    end
    item_restores = {}
end

function set_item_mute(item, value)
    -- 设置item的静音状态，并记录原始状态以便恢复
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    if (value == orig) then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
    table.insert(item_restores, function()
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", orig)
    end)
end

local start_time = reaper.time_precise()
local key_state = reaper.JS_VKeys_GetState(start_time - 2)
local custom_cursor_path = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Various/Advanced Solo/lib/speaker.cur'
-- local custom_cursor_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]] .. '/speaker.cur'
local is_playing = false

local function detect_key_press()
    -- 检测被按下的按键
    for key_code = 1, 255 do
        if key_state:byte(key_code) ~= 0 then
            reaper.JS_VKeys_Intercept(key_code, 1)  -- 拦截按键，防止干扰其他操作
            return key_code  -- 返回检测到的按键码
        end
    end
    return nil -- 没有检测到按键
end

local key = detect_key_press()
if not key then return end  -- 如果没有检测到按键，结束脚本

local function is_key_held()
    -- 检测按键是否持续被按下
    key_state = reaper.JS_VKeys_GetState(start_time - 2)
    return key_state:byte(key) == 1
end

local function release()
    -- 恢复初始状态并释放资源
    reaper.JS_Mouse_SetCursor(reaper.JS_Mouse_LoadCursor(32512)) -- 加载默认光标（箭头）
    reaper.JS_VKeys_Intercept(key, -1)
    reaper.CF_Preview_StopAll()

    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    if window == "midi_editor" then
        if not inline_editor then
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop
        else
            reaper.Main_OnCommand(1016, 0) -- Transport: Stop
        end
        restore_items() -- 恢复item静音状态
    else
        reaper.Main_OnCommand(1016, 0) -- Transport: Stop
        restore_items() -- 恢复item静音状态
    end

    is_playing = false
end

local function update_cursor_on_hold()
    -- 当按键持续按下时更新光标
    if not is_key_held() then return end
    local cursor = reaper.JS_Mouse_LoadCursorFromFile(custom_cursor_path)
    if cursor then
        reaper.JS_Mouse_SetCursor(cursor)
    end
    reaper.defer(update_cursor_on_hold)
end

local function main()
    reaper.PreventUIRefresh(1)
    if not is_key_held() then return end
    local count_sel_items = reaper.CountSelectedMediaItems(0) -- 计算选中的items数量
    local count_tracks = reaper.CountTracks(0)
    local play_state = reaper.GetPlayState() -- 1 = playing, 2 = paused, 0 = stopped

    if not is_playing then
        reaper.CF_Preview_StopAll()
        cursor_pos = reaper.GetCursorPosition()
        if play_state == 1 then reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) end -- Transport: Stop

        reaper.JS_Mouse_SetCursor(custom_cursor) -- 设置自定义播放光标
        is_playing = true

        if count_sel_items > 0 then
            for i = 0, count_tracks -1 do
                track = reaper.GetTrack(0, i)
                count_items_track = reaper.CountTrackMediaItems(track)

                for i = 0, count_items_track - 1 do
                    local item = reaper.GetTrackMediaItem(track, i)
                    set_item_mute(item, 1)
                    if reaper.IsMediaItemSelected(item) == true then
                        set_item_mute(item, 0)
                    end
                end
            end
        end

        reaper.SetEditCurPos(cursor_pos, false, false)
        
        local window, _, _ = reaper.BR_GetMouseCursorContext()
        local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
        if window == "midi_editor" then
            if not inline_editor then
                reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
            else
                reaper.Main_OnCommand(1007, 0) -- Transport: Play
            end
        else
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    end

    update_cursor_on_hold()
    reaper.PreventUIRefresh(-1)
    reaper.defer(main)
end

reaper.defer(main)
reaper.atexit(release)
