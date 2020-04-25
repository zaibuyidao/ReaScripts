--[[
 * ReaScript Name: Set Velocity
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-15)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    velocity = reaper.GetExtState("SetVelocity", "velocity")
    if (velocity == "") then velocity = "100" end
    user_ok, velocity = reaper.GetUserInputs("Set Velocity", 1, "Value", velocity)
    reaper.SetExtState("SetVelocity", "velocity", velocity, false)
    if not user_ok or not tonumber(velocity) then return end
    velocity = tonumber(velocity)
    if velocity > 127 or velocity < 1 then
        return reaper.MB("Please enter a value from 1 through 127", "Error", 0),
        reaper.SN_FocusMIDIEditor()
    end
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
                for i = 1, notecnt do
                    _, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                    if sel == true then
                        reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, nil, nil, velocity, false)
                    end
                end
            end
        end
        reaper.MIDI_Sort(take)
    else
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        if take == nil then return end
        reaper.MIDI_DisableSort(take)
        _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        for i = 1, notecnt do
            _, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
            if sel == true then
                reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, nil, nil, velocity, false)
            end
        end
        reaper.MIDI_Sort(take)
    end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Set Velocity", 0)
reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()