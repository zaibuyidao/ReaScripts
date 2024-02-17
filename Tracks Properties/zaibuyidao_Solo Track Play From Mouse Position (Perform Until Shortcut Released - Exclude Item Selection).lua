-- @description Solo Track Play From Mouse Position (Perform Until Shortcut Released - Exclude Item Selection)
-- @version 1.0.5
-- @author zaibuyidao
-- @changelog
--   # Fixed brief audio burst when stopping playback
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

--[[
1.Once activated, the script will operate in the background. To deactivate it, simply run the script once more, or alternatively, configure the script as a toolbar button to conveniently toggle its activation status.
2.If the virtual key activates a system alert, please bind the key to 'Action: No-op (no action)
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Solo Track Shortcut Setting.lua
4.To remove the shortcut key, navigate to the REAPER installation folder, locate the 'reaper-extstate.ini' file, and then find and delete the following lines:
[SOLO_TRACK_SHORTCUT_SETTING]
VirtualKey=the key you set
--]]

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
    title = "独奏轨道快捷键设置"
    lable = "输入 (0-9,A-Z,使用';;'代替','或.)"
    err_title = "不能设置这个按键，请改其他按键"
elseif language == "繁體中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    title = "獨奏軌道快捷鍵設置"
    lable = "輸入 (0-9,A-Z,使用';;'代替','或.)"
    err_title = "不能設置這個按鍵，請改其他按鍵"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    title = "Solo Track Shortcut Settings"
    lable = "Enter (0-9, A-Z, use ';;' for ',' or .)"
    err_title = "This key can't be set. Please choose another."
end

if not reaper.SNM_GetIntConfigVar then
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

if not reaper.APIExists("JS_Localize") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
end

local function generateKeyMap()
    local map = {}
    for i = 0, 9 do
        map[tostring(i)] = 0x30 + i
    end
    for i = 0, 25 do
        local char = string.char(65 + i)  -- Uppercase A-Z
        map[char] = 0x41 + i
        char = string.char(97 + i)  -- Lowercase a-z
        map[char] = 0x41 + i  -- Virtual Key Codes are the same for uppercase
    end
    map[','] = 0xBC
    map['.'] = 0xBE
    map['<'] = 0xE2
    map['>'] = 0xE2
    return map
end

local function UnsoloAllTrack()
    for i = 0, reaper.CountTracks(0)-1 do
        local track = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
    end
end

local function UnselectAllTracks() -- 反選所有軌道
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

local function SaveSelectedItems(t) -- 保存選中的item
    for i = 0, reaper.CountSelectedMediaItems(0)-1 do
        t[i+1] = reaper.GetSelectedMediaItem(0, i)
    end
end

local function RestoreSelectedItems(t) -- 恢復選中的item
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
    for _, item in ipairs(t) do
        reaper.SetMediaItemSelected(item, true)
    end
end

local function SaveSelectedTracks(t)
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        t[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(t)
    UnselectAllTracks()
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
end

local function SaveSoloTracks(t) -- 保存Solo的軌道
    for i = 1, reaper.CountTracks(0) do 
      local tr= reaper.GetTrack(0, i-1)
      t[#t+1] = {tr_ptr = tr, GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") }
    end
end

local function RestoreSoloTracks(t) -- 恢復Solo的軌道状态
    for i = 1, #t do
        local src_tr = reaper.BR_GetMediaTrackByGUID(0, t[i].GUID)
        reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", t[i].solo)
    end
end

-- 检查选中的items中是否存在MIDI takes
function checkForMidiTakes()
    local count = reaper.CountSelectedMediaItems(0)
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            return true -- 找到MIDI take
        end
    end
    return false -- 没找到MIDI take
end

local key = reaper.GetExtState("SOLO_TRACK_SHORTCUT_SETTING", "VirtualKey")
if key == "" then
    CheckShortcutSetting()
    reaper.defer(function() end) -- 终止执行
    key = reaper.GetExtState("SOLO_TRACK_SHORTCUT_SETTING", "VirtualKey")
end

key_map = generateKeyMap()
VirtualKeyCode = key_map[key]
flag = 0

function main()
    reaper.PreventUIRefresh(1)
    cur_pos = reaper.GetCursorPosition()
    count_sel_track = reaper.CountSelectedTracks(0)
    state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態

    if state:byte(VirtualKeyCode) ~= 0 and flag == 0 then
        -- 取消主控轨道静音状态
        local masterTrack = reaper.GetMasterTrack(0)
        reaper.SetMediaTrackInfo_Value(masterTrack, 'B_MUTE', 0)

        local screen_x, screen_y = reaper.GetMousePosition()
        local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

        init_sel_tracks = {}
        SaveSelectedTracks(init_sel_tracks)
        init_solo_tracks = {}
        SaveSoloTracks(init_solo_tracks) -- 保存選中的軌道

        if count_sel_track <= 1 then
            if track_ret then
                reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            end
        elseif count_sel_track > 1 then
            if track_ret then
                reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks

                for i = 0, count_sel_track-1 do
                    local track = reaper.GetSelectedTrack(0, i)
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                end
            end
        end
        reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
        flag = 1
    elseif state:byte(VirtualKeyCode) == 0 and flag == 1 then
        reaper.Main_OnCommand(18, 0) -- Track: Set mute for master track (MIDI CC/OSC only)
        reaper.Main_OnCommand(1016, 0) -- Transport: Stop
        RestoreSelectedTracks(init_sel_tracks)
        RestoreSoloTracks(init_solo_tracks)
        reaper.Main_OnCommand(14, 0) -- Track: Toggle mute for master track
        flag = 0

        -- 延迟取消主控轨道静音，否则会出现短暂的音频爆发
        local function checkTimeAndUnMute()
            if not startTime then startTime = reaper.time_precise() end  -- 初始化开始时间
            local now = reaper.time_precise()
            local playState = reaper.GetPlayState()
            -- 检查当前时间是否已经超过延迟时间，以及播放状态是否不是播放中（值为1表示正在播放）
            if now - startTime >= 0.07 and playState ~= 1 then
                -- 取消主控轨道静音状态
                local masterTrack = reaper.GetMasterTrack(0)
                reaper.SetMediaTrackInfo_Value(masterTrack, 'B_MUTE', 0)
                startTime = nil -- 重置计时器
            elseif playState == 1 then
                -- 如果已经在播放，则不执行取消静音，直接重置计时器
                startTime = nil
            else
                -- 如果还没到时间，且播放没开始，再次延迟执行
                reaper.defer(checkTimeAndUnMute)
            end
        end
    
        if not checkForMidiTakes() then -- 如果没有MIDI takes
            checkTimeAndUnMute()
        else
            reaper.Main_OnCommand(14, 0) -- Track: Toggle mute for master track
        end
    end

    reaper.SetEditCurPos(cur_pos, 0, 0)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.defer(main)
end

local _, _, sectionId, cmdId = reaper.get_action_context()
if sectionId ~= -1 then
    reaper.SetToggleCommandState(sectionId, cmdId, 1)
    reaper.RefreshToolbar2(sectionId, cmdId)
    main()
    reaper.atexit(function()
        reaper.SetToggleCommandState(sectionId, cmdId, 0)
        reaper.RefreshToolbar2(sectionId, cmdId)
    end)
end

reaper.defer(function() end)