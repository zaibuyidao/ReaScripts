--[[
 * ReaScript Name: Solo MIDI Item Play Edit Cursor Position (Perform Until Shortcut Released)
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

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

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

key = reaper.GetExtState("SoloMIDIItemPlayEditCursorPosition", "VirtualKey")
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
        reaper.SetExtState("SoloMIDIItemPlayEditCursorPosition", "VirtualKey", key, true)
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

function NoUndoPoint() end -- 不撤銷

flag = 0
show_select_key_dialog() -- 顯示快捷鍵設置對話框

function main()
    reaper.PreventUIRefresh(1)
    cur_pos = reaper.GetCursorPosition() -- 獲取光標位置

    count_sel_items = reaper.CountSelectedMediaItems(0) -- 計算選中的item
    count_sel_track = reaper.CountSelectedTracks(0) -- 計算選中的軌道
    count_tracks = reaper.CountTracks(0)
    state = reaper.JS_VKeys_GetState(0) -- 獲取按鍵的狀態
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
            -- reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
            reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
        else
            -- reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40443) -- View: Move edit cursor to mouse cursor
            reaper.SetEditCurPos(cur_pos, 0, 0)
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
        end
        flag = 1
    elseif state:byte(VirtualKeyCode) == 0 and flag==1 then
        -- reaper.ShowConsoleMsg("按键释放" .. "\n")
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop
        restore_items() -- 恢复item静音状态
        flag = 0
    end
    reaper.SetEditCurPos(cur_pos, false, false) -- 恢復光標位置
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.defer( main )
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