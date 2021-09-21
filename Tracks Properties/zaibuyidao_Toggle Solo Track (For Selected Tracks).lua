--[[
 * ReaScript Name: Toggle Solo Track (For Selected Tracks)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-8-19)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)
-- reaper.Undo_BeginBlock()

local count_sel_track = reaper.CountSelectedTracks(0)

for i = 0, count_sel_track-1 do
    local track = reaper.GetSelectedTrack(0, i)
    if reaper.GetMediaTrackInfo_Value(track, 'I_SOLO') == 2 then return reaper.Main_OnCommand(40340,0) end
end

reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks

for i = 0, count_sel_track-1 do
    local track = reaper.GetSelectedTrack(0, i)
    reaper.SetTrackSelected(track, true)
    reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
end

local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
if window == "midi_editor" and not inline_editor then reaper.SN_FocusMIDIEditor() end -- 聚焦 MIDI Editor

-- reaper.Undo_EndBlock("Toggle Solo Track (For Selected Tracks)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)