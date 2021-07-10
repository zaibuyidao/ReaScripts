--[[
 * ReaScript Name: Set MIDI Note Shape
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=main,midi_editor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-10)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

count_sel_track = reaper.CountSelectedTracks(0)
if count_sel_track <= 0 then return end

function SaveSelectedMIDITakes ( array )
	for i = 0, reaper.CountSelectedMediaItems( 0 )-1 do
		local item = reaper.GetSelectedMediaItem( 0, i )
		local take = reaper.GetActiveTake( item )
		if take then
			if reaper.TakeIsMIDI( take ) then
				local retval, take_midi = reaper.MIDI_GetAllEvts( take, "" )
				if take_midi:len() > 0 then
					local take_midi_decode = MIDI_Decode( take_midi )
					new_entry = {}
					new_entry['midi'] = take_midi_decode
					new_entry['take'] = take
					new_entry['item'] = item
					table.insert( array, new_entry )
				end
			end
		end
	end
end

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

-- MIDI Get All Evts to String, based on schwa code snippet
function MIDI_Decode( midi )
	local pos=1
	local midi_string = ""
	while pos <= midi:len() do

	local offs,flag,msg=string.unpack( "IBs4",midi,pos )
	local adv=4+1+4+msg:len() -- int+char+int+msg

	local out="+"..offs.."\t"

	for j=1,msg:len() do
		out=out..string.format( "%02X ",msg:byte( j ))
	end
		if flag ~= 0 then out=out.."\t" end
		if flag&1 == 1 then out=out.."sel " end
		if flag&2 == 2 then out=out.."mute " end
		midi_string = midi_string .. out.."\n"

		pos=pos+adv

	end

	return midi_string
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- SaveView()

init_sel_items = {}
SaveSelectedItems(init_sel_items)

-- midi_takes = {}
-- SaveSelectedMIDITakes( midi_takes )

is_drum_mode, drum_mode = reaper.GetUserInputs( 'Set MIDI Note Shape', 1, '0=Triangle 1=Normal 2=Diamond', '0' )
if not is_drum_mode then return end

for i = 0, reaper.CountSelectedTracks(0)-1 do

    local track = reaper.GetSelectedTrack(0, i)
    local item_num = reaper.CountTrackMediaItems(track)

    for i = 0, item_num-1 do
        
        local item = reaper.GetTrackMediaItem(track, i)
        local take = reaper.GetTake(item, 0)
        if not take or not reaper.TakeIsMIDI(take) then return end

        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(item, true)

        reaper.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor (set default behavior in preferences) 打開MIDI編輯器

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

        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40477) -- Misc: Close window if not docked, otherwise pass to main window
        
        reaper.SetMediaItemSelected(item, false)
    end

end

RestoreSelectedItems(init_sel_items)
-- RestoreView()

count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items > 0 then
    for i = 0, count_sel_items-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetTake(item, 0)
        if not take or not reaper.TakeIsMIDI(take) then return end
        if i == 0 then
            reaper.Main_OnCommand(40153, 0) -- Item: Open in built-in MIDI editor (set default behavior in preferences) 打開MIDI編輯器
        end
    end
end

-- local window, _, _ = reaper.BR_GetMouseCursorContext()
-- local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
-- if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor

reaper.Undo_EndBlock("Set MIDI Note Shape", -1)
reaper.PreventUIRefresh(-1)