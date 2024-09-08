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

function un_solo_all_tracks()
    -- 取消所有轨道的Solo状态
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
    end
end

function un_sel_all_tracks()
    -- 反选所有轨道
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

function save_selected_items(t)
    -- 保存当前选中的items到表t
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        t[i + 1] = reaper.GetSelectedMediaItem(0, i)
    end
end

function restore_selected_items(t)
    -- 恢复之前保存的选中的items
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    for _, item in ipairs(t) do
        reaper.SetMediaItemSelected(item, true)
    end
end

function save_selected_tracks(t)
    -- 保存当前选中的轨道到表t
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
        t[i + 1] = reaper.GetSelectedTrack(0, i)
    end
end

function restore_selected_tracks(t)
    -- 恢复之前保存的选中的轨道
    un_sel_all_tracks() -- 先取消选择所有轨道
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
end

function save_solo_tracks(t)
    -- 保存所有轨道的Solo状态到表t
    for i = 1, reaper.CountTracks(0) do
        local tr = reaper.GetTrack(0, i - 1)
        t[#t + 1] = {tr_ptr = tr, GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO")}
    end
end

function restore_solo_tracks(t)
    -- 恢复之前保存的轨道Solo状态
    for i = 1, #t do
        local src_tr = reaper.BR_GetMediaTrackByGUID(0, t[i].GUID)
        reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", t[i].solo)
    end
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

function check_for_midi_takes()
    -- 检查当前选中的items中是否包含MIDI take
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            return true -- 找到MIDI take
        end
    end
    return false -- 没有找到MIDI take
end

if reaper.CountMediaItems(0) == 0 then return end
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
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop

    restore_selected_items(init_sel_items)
    restore_solo_tracks(init_solo_tracks)
    restore_items()

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
    local play_state = reaper.GetPlayState() -- 1 = playing, 2 = paused, 0 = stopped

    if not is_playing then
        reaper.CF_Preview_StopAll()
        cursor_pos = reaper.GetCursorPosition()
        if play_state == 1 then reaper.Main_OnCommand(1016, 0) end -- Transport: Stop

        reaper.JS_Mouse_SetCursor(custom_cursor) -- 设置自定义播放光标
        is_playing = true

        local screen_x, screen_y = reaper.GetMousePosition()
        local item_ret, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
        local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

        init_sel_items = {}
        save_selected_items(init_sel_items) -- 保存当前选中的items
        init_solo_tracks = {}
        save_solo_tracks(init_solo_tracks) -- 保存轨道Solo状态

        if count_sel_items == 0 then
            if item_ret then
                un_solo_all_tracks()
                local track = reaper.GetMediaItem_Track(item_ret) -- 获取鼠标下item所属的轨道
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活该轨道的Solo按钮
                local item_num = reaper.CountTrackMediaItems(track) -- 计算轨道中item的数量

                for i = 0, item_num - 1 do
                    local item = reaper.GetTrackMediaItem(track, i) -- 获取轨道中的每个item
                    set_item_mute(item, 1) -- 将item静音
                end
                if reaper.GetMediaItemInfo_Value(item_ret, "B_MUTE") == 1 then
                    set_item_mute(item_ret, 0) -- 将选中的item取消静音
                end
            else
                if track_ret then
                    reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2) -- 激活轨道的Solo按钮
                end
            end
        else
            un_solo_all_tracks()
            local selected_track = {} -- 保存选中的轨道

            for m = 0, count_sel_items - 1 do
                local item = reaper.GetSelectedMediaItem(0, m)
                local track = reaper.GetMediaItem_Track(item)
                if (not selected_track[track]) then
                    selected_track[track] = true
                end
            end
            for track, _ in pairs(selected_track) do
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活轨道的Solo按钮
                local item_num = reaper.CountTrackMediaItems(track)

                for i = 0, item_num - 1 do
                    local item = reaper.GetTrackMediaItem(track, i)
                    set_item_mute(item, 1) -- 静音轨道中的所有item
                    if reaper.IsMediaItemSelected(item) == true then
                        set_item_mute(item, 0) -- 取消静音选中的item
                    end
                end
            end
        end

        reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
    end
    
    reaper.SetEditCurPos(cursor_pos, false, false)
    update_cursor_on_hold()
    reaper.PreventUIRefresh(-1)
    reaper.defer(main)
end

reaper.defer(main)
reaper.atexit(release)
