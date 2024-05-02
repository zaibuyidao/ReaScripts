-- @description Hold to Solo MIDI Item from Mouse Position
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor] .
-- @about Intelligent SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

--[[
1.Once activated, the script will operate in the background. To deactivate it, simply run the script once more, or alternatively, configure the script as a toolbar button to conveniently toggle its activation status.
2.If the virtual key activates a system alert, please bind the key to 'Action: No-op (no action)
3.If you want to reset the shortcut key, please run the script: zaibuyidao_Hold to Solo MIDI Item Setting.lua
4.To remove the shortcut key, navigate to the REAPER installation folder, locate the 'reaper-extstate.ini' file, and then find and delete the following lines:
[HOLD_TO_SOLO_MIDI_ITEM_SETTING]
VirtualKey=the key you set
--]]

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

local language = getSystemLanguage()

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

function CheckShortcutSetting()
    local shortcutSetting = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/MIDI Editor/zaibuyidao_Hold to Solo MIDI Item Setting.lua'
  
    if reaper.file_exists(shortcutSetting) then
        dofile(shortcutSetting)
    else
        reaper.MB(shortcutSetting:gsub('%\\', '/')..' not found. Please ensure the script is correctly placed.', '', 0)
        if reaper.APIExists('ReaPack_BrowsePackages') then
            reaper.ReaPack_BrowsePackages('zaibuyidao Hold to Solo MIDI Item Setting')
        else
            reaper.MB('ReaPack extension not found', '', 0)
        end
    end
end

local key = reaper.GetExtState("HOLD_TO_SOLO_MIDI_ITEM_SETTING", "VirtualKey")
if key == "" then
    CheckShortcutSetting()
    reaper.defer(function() end) -- 终止执行
    key = reaper.GetExtState("HOLD_TO_SOLO_MIDI_ITEM_SETTING", "VirtualKey")
end

key_map = generateKeyMap()
VirtualKeyCode = key_map[key]
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
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
            -- reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
            flag = 1
        elseif state:byte(VirtualKeyCode) == 0 and flag == 1 then
            -- reaper.ShowConsoleMsg("按键释放" .. "\n")
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop
            restore_items() -- 恢复item静音状态
            flag = 0
        end
        -- if not inline_editor then reaper.SN_FocusMIDIEditor() end
    else
        if state:byte(VirtualKeyCode) ~= 0 and flag == 0 then
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
            reaper.Main_OnCommand(40513, 0) -- View: Move edit cursor to mouse cursor
            -- reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
            flag = 1
        elseif state:byte(VirtualKeyCode) == 0 and flag == 1 then
            -- reaper.ShowConsoleMsg("按键释放" .. "\n")
            reaper.Main_OnCommand(1016, 0) -- Transport: Stop
            restore_items() -- 恢复item静音状态
            flag = 0
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