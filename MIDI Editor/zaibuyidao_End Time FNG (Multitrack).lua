--[[
 * ReaScript Name: End Time FNG (Multitrack)
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Extensions: SWS
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-5)
  + Initial release
--]]

function Msg(message)
    reaper.ShowConsoleMsg(tostring(message) .. "\n")
end

function EndTime()
    local curpos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    local fng_take = reaper.FNG_AllocMidiTake(take)
    for i = 1, notecnt do
        local cur_note = reaper.FNG_GetMidiNote(fng_take, i - 1)
        local selected = reaper.FNG_GetMidiNoteIntProperty(cur_note, "SELECTED") -- 是否有音符被选中

        if selected == 1 then
            local noteppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION") -- 音符起始位置
            local lenppq = reaper.FNG_GetMidiNoteIntProperty(cur_note, "LENGTH") -- 音符长度
            local endpos = curpos - noteppq
            if noteppq < curpos then
                reaper.FNG_SetMidiNoteIntProperty(cur_note, "LENGTH", endpos) -- 将音符结束位置应用到光标位置
            end
        end
    end
    reaper.FNG_FreeMidiTake(fng_take)
end

function Main()
    reaper.Undo_BeginBlock()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then -- 如果有item被选中
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            EndTime()
        end
    else -- 否则，判断MIDI编辑器是否被激活
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        if take == nil then return end
        EndTime()
    end

    reaper.Undo_EndBlock("End Time FNG (Multitrack)", -1)
    reaper.UpdateArrange()
end

Main()