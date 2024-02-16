-- @description Solo MIDI Item Play From Edit Cursor Position (Perform Until Shortcut Released)
-- @version 1.0.6
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
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Solo MIDI Item Shortcut Setting.lua
4.To remove the shortcut key, navigate to the REAPER installation folder, locate the 'reaper-extstate.ini' file, and then find and delete the following lines:
[SOLO_MIDI_ITEM_SHORTCUT_SETTING]
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
    title = "独奏MIDI对象快捷键设置"
    lable = "输入 (0-9,A-Z,使用';;'代替','或.)"
    err_title = "不能设置这个按键，请改其他按键"
elseif language == "繁體中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    title = "獨奏MIDI對象快捷鍵設置"
    lable = "輸入 (0-9,A-Z,使用';;'代替','或.)"
    err_title = "不能設置這個按鍵，請改其他按鍵"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    title = "Solo MIDI Item Shortcut Settings"
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

key_map = generateKeyMap()

local key = reaper.GetExtState("SOLO_MIDI_ITEM_SHORTCUT_SETTING", "VirtualKey")
VirtualKeyCode = key_map[key]
shift_key = 0x10
ctrl_key = 0x11
alt_key = 0x12

if (not key or not key_map[key]) then
    key = "9"
    local retval, retvals_csv = reaper.GetUserInputs(title, 1, lable, key)

    if retval == nil or retval == false then 
        return
    end

    -- If the user entered ";;", interpret it as ","
    if retvals_csv == ";;" then
        retvals_csv = ","
    end

    if (not key_map[retvals_csv]) then
        reaper.MB(err_title, "Error", 0)
        return
    end

    key = retvals_csv
    VirtualKeyCode = key_map[key]
    reaper.SetExtState("SOLO_MIDI_ITEM_SHORTCUT_SETTING", "VirtualKey", key, true)

    if language == "简体中文" then
        okk_title = "虚拟键 ".. key .." 设置完毕。接下来，你需要将按键 ".. key .." 设置为无动作，以避免触发系统警报声。\n点击【确定】将会弹出操作列表的快捷键设置，请将快捷键设置为按键 ".. key .." 。\n\n最后，请重新运行 Solo MIDI Item 脚本，並使用快捷键 ".. key .." 进行独奏。"
        okk_box = "继续下一步"
    elseif language == "繁體中文" then
        okk_title = "虛擬鍵 ".. key .." 設置完畢。接下來，你需要將按鍵 ".. key .." 設置為無動作，以避免觸發系統警報聲。\n點擊【確定】將會彈出操作列表的快捷鍵設置，請將快捷鍵設置為按鍵 ".. key .." 。\n\n最後，請重新運行 Solo MIDI Item 腳本，並使用快捷鍵 ".. key .." 進行獨奏。"
        okk_box = "繼續下一步"
    else
        okk_title = "The virtual key " .. key .. " has been set up. Next, you need to configure the key " .. key .. " to 'No Action' to prevent triggering system alert sounds.\nClicking [OK] will open the action list's shortcut settings. Please set the shortcut to key " .. key .. ".\n\nLastly, please rerun the Solo MIDI Item script and use the shortcut " .. key .. " to solo."
        okk_box = "Proceed to the next step."
    end

    reaper.MB(okk_title, okk_box, 0) -- 继续下一步
    reaper.DoActionShortcutDialog(0, 0, 65535, -1) -- No-op (no action)
end

item_restores = {}

function restore_items() -- 恢復item狀態
    for i=#item_restores,1,-1  do
        item_restores[i]()
    end
    item_restores = {}
end
function set_item_mute(item, value)
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE" )
    if (value == orig) then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
    table.insert(item_restores, function ()
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", orig)
    end)
end

flag = 0

function main()
    reaper.PreventUIRefresh(1)
    cur_pos = reaper.GetCursorPosition() -- 獲取光標位置

    count_sel_items = reaper.CountSelectedMediaItems(0) -- 計算選中的item
    count_tracks = reaper.CountTracks(0)
    state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態

    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    if window == "midi_editor" then
        if not inline_editor then
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        else
            take = reaper.BR_GetMouseCursorContext_Take()
        end

        if state:byte(VirtualKeyCode) ~= 0 and flag == 0 then
            -- 取消主控轨道静音状态
            local masterTrack = reaper.GetMasterTrack(0)
            reaper.SetMediaTrackInfo_Value(masterTrack, 'B_MUTE', 0)

            if count_sel_items > 0 then
                --reaper.ShowConsoleMsg("按键按下" .. "\n")
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
            -- reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
            reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
            flag = 1
        elseif state:byte(VirtualKeyCode) == 0 and flag == 1 then
            -- reaper.ShowConsoleMsg("按键释放" .. "\n")
            reaper.Main_OnCommand(18, 0) -- Track: Set mute for master track (MIDI CC/OSC only)
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop
            restore_items() -- 恢复item静音状态
            reaper.Main_OnCommand(14, 0) -- Track: Toggle mute for master track
            flag = 0
        end
        -- if not inline_editor then reaper.SN_FocusMIDIEditor() end

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
    
        checkTimeAndUnMute()
    else
        if state:byte(VirtualKeyCode) ~= 0 and flag == 0 then
            -- 取消主控轨道静音状态
            local masterTrack = reaper.GetMasterTrack(0)
            reaper.SetMediaTrackInfo_Value(masterTrack, 'B_MUTE', 0)

            if count_sel_items > 0 then
                --reaper.ShowConsoleMsg("按键按下" .. "\n")
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
            -- reaper.Main_OnCommand(40513, 0) -- View: Move edit cursor to mouse cursor
            reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
            flag = 1
        elseif state:byte(VirtualKeyCode) == 0 and flag == 1 then
            -- reaper.ShowConsoleMsg("按键释放" .. "\n")
            reaper.Main_OnCommand(18, 0) -- Track: Set mute for master track (MIDI CC/OSC only)
            reaper.Main_OnCommand(1016, 0) -- Transport: Stop
            restore_items() -- 恢复item静音状态
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
        
            checkTimeAndUnMute()
        end
    end

    reaper.SetEditCurPos(cur_pos, 0, 0) -- 恢復光標位置
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