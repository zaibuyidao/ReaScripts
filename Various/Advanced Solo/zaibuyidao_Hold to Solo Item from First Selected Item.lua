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

local proj = reaper.EnumProjects(-1, "") or 0

function find_max_value(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

function find_min_value(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

function un_solo_all_tracks()
    -- 取消所有轨道的Solo状态
    for i = 0, reaper.CountTracks(proj) - 1 do
        local track = reaper.GetTrack(proj, i)
        if track then
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
        end
    end
end

local function is_valid_track(track)
    return track and (not reaper.ValidatePtr2 or reaper.ValidatePtr2(proj, track, "MediaTrack*"))
end

local function is_valid_item(item)
    return item and (not reaper.ValidatePtr2 or reaper.ValidatePtr2(proj, item, "MediaItem*"))
end

local function get_item_guid(item)
    if not is_valid_item(item) then return nil end
    return reaper.BR_GetMediaItemGUID(item)
end

local function build_item_lookup()
    local lookup = {}
    for i = 0, reaper.CountMediaItems(proj) - 1 do
        local item = reaper.GetMediaItem(proj, i)
        local guid = get_item_guid(item)
        if guid then
            lookup[guid] = item
        end
    end
    return lookup
end

local function build_track_lookup()
    local lookup = {}
    for i = 0, reaper.CountTracks(proj) - 1 do
        local track = reaper.GetTrack(proj, i)
        if track then
            lookup[reaper.GetTrackGUID(track)] = track
        end
    end
    return lookup
end

local function unselect_all_items()
    for i = 0, reaper.CountMediaItems(proj) - 1 do
        local item = reaper.GetMediaItem(proj, i)
        if item then
            reaper.SetMediaItemSelected(item, false)
        end
    end
end

function un_sel_all_tracks()
    -- 反选所有轨道
    for i = 0, reaper.CountTracks(proj) - 1 do
        local track = reaper.GetTrack(proj, i)
        if track then
            reaper.SetTrackSelected(track, false)
        end
    end
end

function save_selected_items(t)
    -- 保存当前选中的items到表t
    for i = 0, reaper.CountSelectedMediaItems(proj) - 1 do
        local guid = get_item_guid(reaper.GetSelectedMediaItem(proj, i))
        if guid then
            t[#t + 1] = guid
        end
    end
end

function restore_selected_items(t)
    -- 恢复之前保存的选中的items
    if not t then return end
    unselect_all_items()
    local item_lookup = build_item_lookup()
    for _, saved_item in ipairs(t) do
        local item = type(saved_item) == "string" and item_lookup[saved_item] or saved_item
        if is_valid_item(item) then
            reaper.SetMediaItemSelected(item, true)
        end
    end
end

function save_selected_tracks(t)
    -- 保存当前选中的轨道到表t
    for i = 0, reaper.CountSelectedTracks(proj) - 1 do
        local track = reaper.GetSelectedTrack(proj, i)
        if track then
            t[#t + 1] = reaper.GetTrackGUID(track)
        end
    end
end

function restore_selected_tracks(t)
    -- 恢复之前保存的选中的轨道
    if not t then return end
    un_sel_all_tracks()
    local track_lookup = build_track_lookup()
    for _, saved_track in ipairs(t) do
        local track = type(saved_track) == "string" and track_lookup[saved_track] or saved_track
        if is_valid_track(track) then
            reaper.SetTrackSelected(track, true)
        end
    end
end

function save_solo_tracks(t)
    -- 保存所有轨道的Solo状态到表t
    for i = 1, reaper.CountTracks(proj) do
        local tr = reaper.GetTrack(proj, i - 1)
        if tr then
            t[#t + 1] = {GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO")}
        end
    end
end

function restore_solo_tracks(t)
    -- 恢复之前保存的轨道Solo状态
    if not t then return end
    for i = 1, #t do
        local saved_track = t[i]
        local src_tr = saved_track and saved_track.GUID and reaper.BR_GetMediaTrackByGUID(proj, saved_track.GUID)
        if is_valid_track(src_tr) then
            reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", saved_track.solo or 0)
        end
    end
end

local item_restores = {}
local item_restore_order = {}

function restore_items()
    -- 恢复items的状态
    local item_lookup = build_item_lookup()
    for i = #item_restore_order, 1, -1 do
        local guid = item_restore_order[i]
        local item = item_lookup[guid]
        if is_valid_item(item) then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", item_restores[guid] or 0)
        end
    end
    item_restores = {}
    item_restore_order = {}
end

function set_item_mute(item, value)
    -- 设置item的静音状态，并记录原始状态以便恢复
    if not is_valid_item(item) then return end
    local guid = get_item_guid(item)
    if not guid then return end
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    if item_restores[guid] == nil then
        item_restores[guid] = orig
        item_restore_order[#item_restore_order + 1] = guid
    end
    if value == orig then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
end

function check_for_midi_takes()
    -- 检查当前选中的items中是否包含MIDI take
    local count = reaper.CountSelectedMediaItems(proj)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(proj, i)
        local take = is_valid_item(item) and reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            return true -- 找到MIDI take
        end
    end
    return false -- 没有找到MIDI take
end

if reaper.CountMediaItems(proj) == 0 then return end
local start_time = reaper.time_precise()
local key_state = reaper.JS_VKeys_GetState(start_time - 2)
-- local custom_cursor_path = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Various/Advanced Solo/lib/speaker.cur'
local custom_cursor_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]] .. '/speaker.cur'
local is_playing = false
local custom_cursor = reaper.JS_Mouse_LoadCursorFromFile(custom_cursor_path)
local cursor_pos = 0
local init_sel_items = {}
local init_solo_tracks = {}
local released = false

local function detect_key_press()
    -- 检测被按下的按键
    if not key_state then return nil end
    for key_code = 1, 255 do
        local state = key_state:byte(key_code)
        if state and state ~= 0 then
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
    local state = key_state and key_state:byte(key)
    return state == 1
end

local function release()
    if released then return end
    released = true

    -- 恢复初始状态并释放资源
    local default_cursor = reaper.JS_Mouse_LoadCursor(32512)
    if default_cursor then
        reaper.JS_Mouse_SetCursor(default_cursor) -- 加载默认光标（箭头）
    end
    if key then
        reaper.JS_VKeys_Intercept(key, -1)
    end
    reaper.CF_Preview_StopAll()
    if is_playing then
        reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    end

    restore_selected_items(init_sel_items)
    restore_solo_tracks(init_solo_tracks)
    restore_items()

    is_playing = false
    reaper.UpdateArrange()
end

local function update_cursor_on_hold()
    -- 当按键持续按下时更新光标
    if not is_key_held() then return end
    local cursor = custom_cursor or reaper.JS_Mouse_LoadCursorFromFile(custom_cursor_path)
    if cursor then
        reaper.JS_Mouse_SetCursor(cursor)
    end
end

local function main_impl()
    local count_sel_items = reaper.CountSelectedMediaItems(proj)
    local play_state = reaper.GetPlayState() -- 1 = playing, 2 = paused, 0 = stopped

    if not is_playing then
        reaper.CF_Preview_StopAll()
        cursor_pos = reaper.GetCursorPosition()
        if play_state == 1 then reaper.Main_OnCommand(1016, 0) end -- Transport: Stop

        if custom_cursor then
            reaper.JS_Mouse_SetCursor(custom_cursor) -- 设置自定义播放光标
        end
        is_playing = true

        local screen_x, screen_y = reaper.GetMousePosition()
        local item_ret, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
        local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

        local snap_t = {}
        local snap
        local snap_pos
        if count_sel_items > 0 then
            for i = 0, count_sel_items-1 do
                local item = reaper.GetSelectedMediaItem(proj, i)
                if is_valid_item(item) then
                    local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
                    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    snap_t[#snap_t + 1] = item_pos + item_snap
                end
            end
            snap_pos = find_min_value(snap_t)
        end
    
        if is_valid_item(item_ret) then
            local item_snap = reaper.GetMediaItemInfo_Value(item_ret, "D_SNAPOFFSET")
            local item_pos = reaper.GetMediaItemInfo_Value(item_ret, "D_POSITION")
            snap = item_pos + item_snap
        end

        init_sel_items = {}
        save_selected_items(init_sel_items) -- 保存当前选中的items
        init_solo_tracks = {}
        save_solo_tracks(init_solo_tracks) -- 保存轨道Solo状态

        if count_sel_items == 0 then
            if is_valid_item(item_ret) then
                un_solo_all_tracks()
                local track = reaper.GetMediaItem_Track(item_ret) -- 获取鼠标下item所属的轨道
                if is_valid_track(track) then
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活该轨道的Solo按钮
                    local item_num = reaper.CountTrackMediaItems(track) -- 计算轨道中item的数量

                    for i = 0, item_num - 1 do
                        local item = reaper.GetTrackMediaItem(track, i) -- 获取轨道中的每个item
                        set_item_mute(item, 1) -- 将item静音
                    end
                    if reaper.GetMediaItemInfo_Value(item_ret, "B_MUTE") == 1 then
                        set_item_mute(item_ret, 0) -- 将选中的item取消静音
                    end
                    reaper.SetEditCurPos(snap or cursor_pos, false, false)
                end
                reaper.Main_OnCommand(1007, 0) -- Transport: Play
            else
                if is_valid_track(track_ret) then
                    reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2) -- 激活轨道的Solo按钮
                end
                reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
                reaper.Main_OnCommand(1007, 0) -- Transport: Play
            end
        else
            un_solo_all_tracks()
            local selected_track = {} -- 保存选中的轨道

            for m = 0, count_sel_items - 1 do
                local item = reaper.GetSelectedMediaItem(proj, m)
                local track = is_valid_item(item) and reaper.GetMediaItem_Track(item)
                if (track and not selected_track[track]) then
                    selected_track[track] = true
                end
            end
            for track, _ in pairs(selected_track) do
                if is_valid_track(track) then
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活轨道的Solo按钮
                    local item_num = reaper.CountTrackMediaItems(track)

                    for i = 0, item_num - 1 do
                        local item = reaper.GetTrackMediaItem(track, i)
                        set_item_mute(item, 1) -- 静音轨道中的所有item
                        if is_valid_item(item) and reaper.IsMediaItemSelected(item) == true then
                            set_item_mute(item, 0) -- 取消静音选中的item
                        end
                    end
                end
            end
            reaper.SetEditCurPos(snap_pos or cursor_pos, false, false)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    end

    reaper.SetEditCurPos(cursor_pos, false, false)
    update_cursor_on_hold()
end

local function main()
    if not is_key_held() then return end
    reaper.PreventUIRefresh(1)
    local ok, err = xpcall(main_impl, debug.traceback)
    reaper.PreventUIRefresh(-1)
    if not ok then
        release()
        error(err)
    end
    reaper.defer(main)
end

reaper.defer(main)
reaper.atexit(release)
