--[[
 * ReaScript Name: 設置事件通道
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_inlineeditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-21)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    chan_num = reaper.GetExtState("SetEventsChannel", "Channel")
    if (chan_num == "") then chan_num = "1" end
    user_ok, chan_num = reaper.GetUserInputs("設置事件通道", 1, "通道編號", chan_num)
    reaper.SetExtState("SetEventsChannel", "Channel", chan_num, false)
    if not tonumber(chan_num) then return end
    chan_num = chan_num - 1
    if chan_num < 0 or chan_num > 15 then return reaper.MB("請輸入1到16之間的一個值","錯誤",0) end
    if window == "midi_editor" then
        if not inline_editor then
            if not user_ok or not tonumber(chan_num) then return reaper.SN_FocusMIDIEditor() end
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        else
            take = reaper.BR_GetMouseCursorContext_Take()
        end
        reaper.MIDI_DisableSort(take)
        _, notecnt, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
        for i = 1, notecnt do
            _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
            if selected == true then
                reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, chan_num, nil, nil, false)
            end
        end
        for i = 1, ccevtcnt do
            _, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
            if selected == true then
                reaper.MIDI_SetCC(take, i - 1, nil, nil, nil, nil, chan_num, nil, nil, false)
            end
        end
        if not inline_editor then reaper.SN_FocusMIDIEditor() end
        reaper.MIDI_Sort(take)
    else
        if not user_ok or not tonumber(chan_num) then return end
        count_sel_items = reaper.CountSelectedMediaItems(0)
        if count_sel_items == 0 then return end
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, count_sel_items - i)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
                for i = 1, notecnt do
                    _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
                    reaper.MIDI_SetNote(take, i - 1, nil, nil, nil, nil, chan_num, nil, nil, false)
                end
                for i = 1, ccevtcnt do
                    _, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
                    reaper.MIDI_SetCC(take, i - 1, nil, nil, nil, nil, chan_num, nil, nil, false)
                end
            end
            reaper.MIDI_Sort(take)
        end
    end
end
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("設置事件通道", -1)
reaper.UpdateArrange()
