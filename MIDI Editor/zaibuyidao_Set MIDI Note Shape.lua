--[[
 * ReaScript Name: Set MIDI Note Shape
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-10)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function SaveView()
	start_time_view, end_time_view = reaper.BR_GetArrangeView( 0 )
end

function RestoreView()
	reaper.BR_SetArrangeView( 0, start_time_view, end_time_view )
end

local function SaveSelectedItems(t)
    for i = 0, reaper.CountSelectedMediaItems(0)-1 do
        t[i+1] = reaper.GetSelectedMediaItem(0, i)
    end
end

local function RestoreSelectedItems(t)
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
    for _, item in ipairs(t) do
        reaper.SetMediaItemSelected(item, true)
    end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

init_sel_items = {}
SaveSelectedItems(init_sel_items)

is_drum_mode, drum_mode = reaper.GetUserInputs( 'Set MIDI Note Shape', 1, '0=Triangle 1=Normal 2=Diamond', '0' )
if not is_drum_mode then return end

-- for i = 0, reaper.CountSelectedTracks(0)-1 do

--     local track = reaper.GetSelectedTrack(0, i)
--     local item_num = reaper.CountTrackMediaItems(track)

--     for i = 0, item_num-1 do

--         -- local item = reaper.GetTrackMediaItem(track, i)
--         -- local take = reaper.GetTake(item, 0)
--         -- if not take or not reaper.TakeIsMIDI(take) then return end

--     end

-- end

editor = reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(editor)
if not take or not reaper.TakeIsMIDI(take) then return end

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
    
    for i = 0, count_sel_items-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if drum_mode == '0' then
            if reaper.GetToggleCommandStateEx(32060, 40448) ~= 1 then -- View: Show events as triangles (drum mode)
                reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40448) -- View: Show events as triangles (drum mode) 切換模式為三角形
            end
        elseif drum_mode == '1' then
            if reaper.GetToggleCommandStateEx(32060, 40449) ~= 1 then -- View: Show events as rectangles (normal mode)
                reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40449) -- View: Show events as rectangles (normal mode) 切換模式為長方形
            end
        elseif drum_mode == '2' then
            if reaper.GetToggleCommandStateEx(32060, 40450) ~= 1 then -- View: Show events as diamonds (drum mode)
                reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40450) -- View: Show events as diamonds (drum mode) 切換模式為菱形
            end
        end
        reaper.MIDIEditor_OnCommand(editor , 40500)
    end

end

RestoreSelectedItems(init_sel_items)

-- local window, _, _ = reaper.BR_GetMouseCursorContext()
-- local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
-- if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor

reaper.Undo_EndBlock("Set MIDI Note Shape", -1)
reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()