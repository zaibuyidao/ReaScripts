-- @description Random Note Start
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function main()
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end

    amount = reaper.GetExtState("Random Note Start", "Parameters")
    if (amount == "") then amount = "3" end
    user_ok, amount = reaper.GetUserInputs("Random Note Start", 1, "Value", amount)
    amount = tonumber(amount)
    reaper.SetExtState("Random Note Start", "Parameters", amount, false)
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
        flag = true
    end

    i = reaper.MIDI_EnumSelNotes(take, -1)
    if i ~= -1 then sel_note = true end
    while i ~= -1 do
        local note = {}
        note[i] = {}
        note[i].ret,
        note[i].sel,
        note[i].muted,
        note[i].startppqpos,
        note[i].endppqpos,
        note[i].chan,
        note[i].pitch,
        note[i].vel = reaper.MIDI_GetNote(take, i)
        note_len = note[i].endppqpos - note[i].startppqpos
        if note_len > amount then
            if note[i].sel then
                reaper.MIDI_SetNote(take, i, nil, nil, (note[i].startppqpos-amount-1)+math.random(amount*2+1), nil, nil, nil, nil, true)
            end
        end
        i = reaper.MIDI_EnumSelNotes(take, i)
    end
    for i = 1, notecnt do
        _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
        note_len = endppqpos - startppqpos
        if note_len > amount then
            if not sel_note then
                reaper.MIDI_SetNote(take, i - 1, nil, nil, (startppqpos-amount-1)+math.random(amount*2+1), nil, nil, nil, nil, true)
            end
        end
    end
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)
    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0)
    end
end

reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Random Note Start", -1)
reaper.SN_FocusMIDIEditor()