--[[
 * ReaScript Name: Solo Item Play From Mouse Position (Perform Until Shortcut Released)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-9-20)
  + Initial release
--]]

function print(string) reaper.ShowConsoleMsg(tostring(string)..'\n') end

-- https://docs.microsoft.com/en-us/windows/desktop/inputdev/virtual-key-codes

key_map = { 
    ['0'] = 0x30,
    ['1'] = 0x31,
    ['2'] = 0x32,
    ['3'] = 0x33,
    ['4'] = 0x34,
    ['5'] = 0x35,
    ['6'] = 0x36,
    ['7'] = 0x37,
    ['8'] = 0x38,
    ['9'] = 0x39,
    ['A'] = 0x41,
    ['B'] = 0x42,
    ['C'] = 0x43,
    ['D'] = 0x44,
    ['E'] = 0x45,
    ['F'] = 0x46,
    ['G'] = 0x47,
    ['H'] = 0x48,
    ['I'] = 0x49,
    ['J'] = 0x4A,
    ['K'] = 0x4B,
    ['L'] = 0x4C,
    ['M'] = 0x4D,
    ['N'] = 0x4E,
    ['O'] = 0x4F,
    ['P'] = 0x50,
    ['Q'] = 0x51,
    ['R'] = 0x52,
    ['S'] = 0x53,
    ['T'] = 0x54,
    ['U'] = 0x55,
    ['V'] = 0x56,
    ['W'] = 0x57,
    ['X'] = 0x58,
    ['Y'] = 0x59,
    ['Z'] = 0x5A,
    ['a'] = 0x41,
    ['b'] = 0x42,
    ['c'] = 0x43,
    ['d'] = 0x44,
    ['e'] = 0x45,
    ['f'] = 0x46,
    ['g'] = 0x47,
    ['h'] = 0x48,
    ['i'] = 0x49,
    ['j'] = 0x4A,
    ['k'] = 0x4B,
    ['l'] = 0x4C,
    ['m'] = 0x4D,
    ['n'] = 0x4E,
    ['o'] = 0x4F,
    ['p'] = 0x50,
    ['q'] = 0x51,
    ['r'] = 0x52,
    ['s'] = 0x53,
    ['t'] = 0x54,
    ['u'] = 0x55,
    ['v'] = 0x56,
    ['w'] = 0x57,
    ['x'] = 0x58,
    ['y'] = 0x59,
    ['z'] = 0x5A
}

key = reaper.GetExtState("SoloItemPlayFromMousePosition", "VirtualKey")
VirtualKeyCode = key_map[key]
function show_select_key_dialog()
    if (not key or not key_map[key]) then
        key = '9'
        local ok, input = reaper.GetUserInputs("Set Virtual Key", 1, "Enter 0-9 or A-Z", key)
        if (not key_map[input]) then
            reaper.ShowConsoleMsg("Cannot set this Key\n無法設置此按鍵" .. "\n")
            return
        end
        key = input
        VirtualKeyCode = key_map[key]
        reaper.SetExtState("SoloItemPlayFromMousePosition", "VirtualKey", key, true)
    end
end

function Open_URL(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open ".. url)
     else
      os.execute("start ".. url)
    end
end

function CheckSWS()
    local SWS_installed
    if not reaper.BR_ItemAtMouseCursor then
        local retval = reaper.ShowMessageBox("SWS extension is required by this script.\nHowever, it doesn't seem to be present for this REAPER installation.\n\nDo you want to download it now ?", "Warning", 1)
        if retval == 1 then
          Open_URL("http://www.sws-extension.org/download/pre-release/")
        end
    else
        SWS_installed = true
    end
    return SWS_installed
end

local function UnSoloAllTrack()
    for i = 0, reaper.CountTracks(0)-1 do
        local track = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
    end
end

local function UnselAllTrack() -- 反選所有軌道
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

local function SaveSelectedTracks(t) -- 保存選中的軌道
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        t[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(t) -- 恢復選中的軌道
    UnselAllTrack()
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

function NoUndoPoint() end -- 不撤銷

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
show_select_key_dialog() -- 顯示快捷鍵設置對話框

function main()
    reaper.PreventUIRefresh(1)
    cur_pos = reaper.GetCursorPosition() -- 獲取光標位置
    count_sel_items = reaper.CountSelectedMediaItems(0) -- 計算選中的item
    count_sel_track = reaper.CountSelectedTracks(0) -- 計算選中的軌道
    state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態

    x, y = reaper.GetMousePosition()
    item_point = reaper.GetItemFromPoint(x, y, false) -- 獲取鼠標下的item

    local item_ret, item_mouse_pos = reaper.BR_ItemAtMouseCursor()
    local track_ret, context, track_mouse_pos = reaper.BR_TrackAtMouseCursor()
    
    if state:byte(VirtualKeyCode) ~= 0 and flag == 0 then
        -- reaper.ShowConsoleMsg("按键按下" .. "\n")
        
        init_sel_items = {}
        SaveSelectedItems(init_sel_items) -- 保存選中的item
        --init_sel_tracks = {}
        --SaveSelectedTracks(init_sel_tracks)
        init_solo_tracks = {}
        SaveSoloTracks(init_solo_tracks) -- 保存選中的軌道

        if count_sel_items == 0 then -- 沒有item被選中
            reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
            if item_ret then -- 在鼠標下的item
                local track = reaper.GetMediaItem_Track(item_ret) -- 獲取鼠標下item對應的軌道
                --reaper.SetTrackSelected(track, true) -- 將軌道設置為選中
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活軌道的SOLO按鈕
                local item_num = reaper.CountTrackMediaItems(track) -- 計算item的總數
                for i = 0, item_num-1 do
                    local item = reaper.GetTrackMediaItem(track, i) -- 獲取軌道下的所有item
                    set_item_mute(item, 1) -- 設置為靜音
                end
                if reaper.GetMediaItemInfo_Value( item_ret, "B_MUTE" ) == 1 then
                    set_item_mute(item_ret, 0) -- 設置為非靜音
                end
                reaper.SetEditCurPos(item_mouse_pos, 0, 0) -- 從光標位置播放
                reaper.Main_OnCommand(1007, 0) -- Transport: Play
            elseif track_ret then -- 鼠標不在item上方
                --reaper.SetTrackSelected(track_ret, true) -- 將軌道設置為選中
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2) -- 激活軌道的SOLO按鈕
                if context == 2 then
                    reaper.SetEditCurPos(track_mouse_pos, 0, 0) -- 從光標位置播放
                    reaper.Main_OnCommand(1007, 0) -- Transport: Play
                end
            end
        elseif count_sel_items > 0 then -- 如果選中item大於0
            if track_ret then
                reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
                local selected_track = {} -- 选中的轨道
    
                for m = 0, count_sel_items - 1  do
                    local item = reaper.GetSelectedMediaItem(0, m)
                    local track = reaper.GetMediaItem_Track(item)
                    if (not selected_track[track]) then
                        selected_track[track] = true
                    end
                end
    
                for track, _ in pairs(selected_track) do
                    --reaper.SetTrackSelected(track, true) -- 將軌道設置為選中
                    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
                    local item_num = reaper.CountTrackMediaItems(track)
    
                    for i = 0, item_num - 1 do
                        local item = reaper.GetTrackMediaItem(track, i)
                        set_item_mute(item, 1)
                        if reaper.IsMediaItemSelected(item) == true then
                            set_item_mute(item, 0)
                        end
                    end
                end
                reaper.SetEditCurPos(track_mouse_pos, 0, 0)
                reaper.Main_OnCommand(1007, 0) -- Transport: Play
            end
        end
        flag = 1
    elseif state:byte(VirtualKeyCode) == 0 and flag==1 then
        -- reaper.ShowConsoleMsg("按键释放" .. "\n")

        reaper.Main_OnCommand(1016, 0) -- Transport: Stop
        --reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
        RestoreSelectedItems(init_sel_items) -- 恢复选中的item状态
        --RestoreSelectedTracks(init_sel_tracks) -- 恢復選中的軌道狀態
        RestoreSoloTracks(init_solo_tracks) -- 恢復Solo的軌道狀態
        restore_items() -- 恢复item静音状态
        flag = 0
    end
    reaper.SetEditCurPos(cur_pos, false, false) -- 恢復光標位置
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.defer( main )
end

if not reaper.BR_ItemAtMouseCursor then
    local retval = reaper.ShowMessageBox("SWS extension is required by this script.\n此腳本需要 SWS 擴展。\nHowever, it doesn't seem to be present for this REAPER installation.\n然而，对于这个REAPER安装来说，它似乎并不存在。\n\nDo you want to download it now ?\n你想现在就下载它吗？", "Warning", 1)
    if retval == 1 then
      Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
    return
end

if not reaper.JS_VKeys_GetState then
    local retval = reaper.ShowMessageBox("js_ReaScriptAPI extension is required by this script.\nHowever, it doesn't seem to be present for this REAPER installation.\n\nDo you want to download it now ?", "Warning", 1)
    if retval == 1 then
        Open_URL("https://github.com/juliansader/ReaExtensions/tree/master/js_ReaScriptAPI/")
    end
    return
    --reaper.ShowConsoleMsg('Please Install js_ReaScriptAPI extension.\nhttps://forum.cockos.com/showthread.php?t=212174\n')
  else
    reaper.ClearConsole()
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
end

reaper.defer(NoUndoPoint)