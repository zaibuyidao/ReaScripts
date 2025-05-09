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

local function stash_save_take_events(take)
    local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
    local encodedStr = reaper.NF_Base64_Encode(MIDI, true) -- 使用REAPER的函数进行Base64编码
    reaper.SetExtState("HoldtoSoloNotefromMousePosition", tostring(take), encodedStr, false)
end
  
local function stash_apply_take_events(take)
    local base64Str = reaper.GetExtState("HoldtoSoloNotefromMousePosition", tostring(take))
    local retval, decodedStr = reaper.NF_Base64_Decode(base64Str) -- 使用REAPER的函数进行Base64解码
    if retval then
        reaper.MIDI_SetAllEvts(take, decodedStr)
    end
end
  
function set_note_mute(take)
    local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
    local pos, t, offset, flags, msg = 1, {}
    while pos < #MIDI do
        offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
        local status = msg:byte(1) >> 4
        local isNoteOn = status == 9 and msg:byte(3) > 0
        local isNoteOff = status == 8 or (status == 9 and msg:byte(3) == 0)

        -- 检查音符是否被选中
        if (isNoteOn or isNoteOff) and flags & 1 == 1 then
            flags = 1 -- 保持选中的音符状态
        elseif (isNoteOn or isNoteOff) then
            flags = 2 -- 设置未选中的音符为静音
        end
        
        t[#t + 1] = string.pack("i4Bs4", offset, flags, msg)
    end
    reaper.MIDI_SetAllEvts(take, table.concat(t))
end

function set_unselect_note_mute(take)
    local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
    local pos, t, offset, flags, msg = 1, {}
    while pos < #MIDI do
        offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
        local status = msg:byte(1) >> 4
        local isNoteOn = status == 9 and msg:byte(3) > 0
        local isNoteOff = status == 8 or (status == 9 and msg:byte(3) == 0)

        -- 静音未选中的音符
        if (isNoteOn or isNoteOff) and flags & 1 == 0 then
            flags = 2 -- 设置音符为静音
        end
        
        t[#t + 1] = string.pack("i4Bs4", offset, flags, msg)
    end
    reaper.MIDI_SetAllEvts(take, table.concat(t))
end

local all_takes = getAllTakes()
local start_time = reaper.time_precise()
local key_state = reaper.JS_VKeys_GetState(start_time - 2)
local custom_cursor_path = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Various/Advanced Solo/lib/speaker.cur'
-- local custom_cursor_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]] .. '/speaker.cur'
local is_playing = false
local custom_cursor = reaper.JS_Mouse_LoadCursorFromFile(custom_cursor_path)
local cursor_pos = 0

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

    restore_solo_tracks(init_solo_tracks)

    local editor = reaper.MIDIEditor_GetActive()
    if editor == nil then return end

    for take, _ in pairs(all_takes) do
        stash_apply_take_events(take)
        reaper.MIDIEditor_OnCommand(editor, 1142) -- Transport: Stop
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
    local play_state = reaper.GetPlayState() -- 1 = playing, 2 = paused, 0 = stopped
    count_sel_items = reaper.CountSelectedMediaItems(0)

    if not is_playing then
        reaper.CF_Preview_StopAll()
        cursor_pos = reaper.GetCursorPosition()
        if play_state == 1 then reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) end -- Transport: Stop

        reaper.JS_Mouse_SetCursor(custom_cursor) -- 设置自定义播放光标
        is_playing = true

        init_solo_tracks = {}
        save_solo_tracks(init_solo_tracks) -- 保存轨道Solo状态

        local selected_track = {}

        for m = 0, count_sel_items - 1  do
            local item = reaper.GetSelectedMediaItem(0, m)
            local track = reaper.GetMediaItem_Track(item)
            if (not selected_track[track]) then
                selected_track[track] = true
            end
        end

        for track, _ in pairs(selected_track) do
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
        end

        local editor = reaper.MIDIEditor_GetActive()
        if editor == nil then return end

        local function should_mute_take(take)
            return reaper.MIDI_EnumSelNotes(take, -1) == -1
        end
        
        for take, _ in pairs(all_takes) do
            stash_save_take_events(take)
            set_unselect_note_mute(take)
        end
        reaper.SetEditCurPos(cursor_pos, false, false)
        reaper.MIDIEditor_OnCommand(editor, 1140) -- Transport: Play
    end

    update_cursor_on_hold()
    reaper.PreventUIRefresh(-1)
    reaper.defer(main)
end

reaper.defer(main)
reaper.atexit(release)
