--[[
 * ReaScript Name: End Time FNG
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Extensions: SWS
--]]

--[[
 * Changelog:
 * v1.0 (2020-4-24)
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
        -- local muted = reaper.FNG_GetMidiNoteIntProperty(cur_note, "MUTED") -- 是否静音
        -- local ppqpos = reaper.FNG_GetMidiNoteIntProperty(cur_note, "POSITION") -- 起始位置
        -- local chan = reaper.FNG_GetMidiNoteIntProperty(cur_note, "CHANNEL") -- 通道
        -- local pitch = reaper.FNG_GetMidiNoteIntProperty(cur_note, "PITCH") -- 音高
        -- local vel = reaper.FNG_GetMidiNoteIntProperty(cur_note, "VELOCITY") -- 力度

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
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if take == nil then return end
    EndTime()
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("End Time FNG", -1)
end

Main()