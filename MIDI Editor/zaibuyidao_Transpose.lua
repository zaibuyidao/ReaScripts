--[[
 * ReaScript Name: Transpose
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or MIDI Takes. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_inlineeditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-9)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
function main()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    amount = reaper.GetExtState("TransposeMIDI", "Transpose")
    if (amount == "") then amount = "0" end
    user_ok, amount = reaper.GetUserInputs("Transpose", 1, "Amount", amount)
    amount = tonumber(amount)
    reaper.SetExtState("TransposeMIDI", "Transpose", amount, false)
    if window == "midi_editor" then
        if not inline_editor then
            if not user_ok or not tonumber(amount) then return reaper.SN_FocusMIDIEditor() end
            take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
            for i = 1, math.abs(amount) do
                if amount > 0 then
                    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40177) -- Edit: Move notes up one semitone
                else
                    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40178) -- Edit: Move notes down one semitone
                end
            end
        else
            if not user_ok or not tonumber(amount) then return end
            take = reaper.BR_GetMouseCursorContext_Take()
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
            got_all_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
            if not got_all_ok then reaper.ShowMessageBox("加载MIDI时出错", "错误", 0) return end
            midi_len = midi_string:len() -- 或 midi_len = #midi_string
            string_pos = 1 -- 解析事件时在 midi_string 中的位置
            table_events = {} -- 初始化表
            while string_pos < midi_len - 12 do -- 解析 midi_string 中的所有事件，最后12个字节除外，这将提供REAPER的All-notes-off end-of-take消息
                offset, flags, msg, string_pos = string.unpack("i4Bs4", midi_string, string_pos)
                new_pitch = msg:byte(2) + amount -- 获取当前音高，添加间隔并向音高写入新值
                if msg:len() == 3 -- 或 #msg == 3, 如果 msg 由3个字节组成 (= channel message)
                and ((msg:byte(1)>>4) == 9 or (msg:byte(1)>>4) == 8) -- note-on/off, MIDI事件类型
                and (flags&1 == 1 or not notes_selected) -- 选中的事件总是移动，未选中的事件仅在未选择音符的情况下移动
                then
                    if new_pitch < 0 or new_pitch > 127 then
                        reaper.ShowMessageBox("移调的音符超出范围","错误",0)
                        return
                    end
                    msg = msg:sub(1,1) .. string.char(new_pitch) .. msg:sub(3,3)
                end
                table.insert(table_events, string.pack("i4Bs4", offset, flags, msg))
            end
            reaper.MIDI_SetAllEvts(take, table.concat(table_events) .. midi_string:sub(-12))
            reaper.MIDI_Sort(take)
        end
        if not inline_editor then reaper.SN_FocusMIDIEditor() end
    else
        if not user_ok or not tonumber(amount) then return end
        count_sel_items = reaper.CountSelectedMediaItems(0)
        if count_sel_items == 0 then return end
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            reaper.MIDI_DisableSort(take)
            if reaper.TakeIsMIDI(take) then
                _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
                local note = {}
                for i = 1, notecnt do
                    note[i] = {}
                    note[i].ret,
                    note[i].sel,
                    note[i].muted,
                    note[i].startppqpos,
                    note[i].endppqpos,
                    note[i].chan,
                    note[i].pitch,
                    note[i].vel = reaper.MIDI_GetNote(take, i - 1)
                end
                for i = 1, notecnt do
                    reaper.MIDI_DeleteNote(take, 0)
                end
                for i = 1, notecnt do
                    reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch + amount, note[i].vel, false)
                end
            end
            reaper.MIDI_Sort(take)
        end
    end
end
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Transpose", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
