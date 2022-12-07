-- @description Random Note Pitch (Customize)
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

-- USER AREA
-- Settings that the user can customize.

min_val = 60
max_val = 72

-- End of USER AREA

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    if min_val > 127 then
        min_val = 127
    elseif min_val < 0 then
        min_val = 0
    elseif max_val > 127 then
        max_val = 127
    elseif max_val < 0 then
        max_val = 0
    elseif min_val > max_val then
        local t = max_val
        max_val = min_val
        min_val = t
    end
    if min_val == max_val then
        return
            reaper.MB("Random interval is empty, please re-enter", "Error", 0),
            reaper.SN_FocusMIDIEditor()
    end
    local diff = (max_val+1) - min_val

    reaper.MIDI_DisableSort(take)
    sel = reaper.MIDI_EnumSelNotes(take, -1)
    if sel ~= -1 then sel_note = true end

    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) --Options: Correct overlapping notes while editing
        flag = true
    end
    
    for i = 1, notecnt do
        _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
        if selected or not sel_note then
            pitch = tonumber(min_val + math.random(diff)) - 1
            reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, nil, pitch, nil, false)
        end
    end
    
    reaper.MIDI_Sort(take)
    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
    end
    --reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40767) -- Force selected notes into key signature
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Pitch", -1)
reaper.UpdateArrange()