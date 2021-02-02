--[[
 * ReaScript Name: Quantize
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-1)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_grid, swing = reaper.MIDI_GetGrid(take)
-- local _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)

note_cnt, note_idx = 0, {}
note_val = reaper.MIDI_EnumSelNotes(take, -1)
while note_val ~= -1 do
    note_cnt = note_cnt + 1
    note_idx[note_cnt] = note_val
    note_val = reaper.MIDI_EnumSelNotes(take, note_val)
end

ccs_cnt, ccs_idx = 0, {}
ccs_val = reaper.MIDI_EnumSelCC(take, -1)
while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
end

sys_cnt, sys_idx = 0, {}
sys_val = reaper.MIDI_EnumSelTextSysexEvts(take, -1)
while sys_val ~= -1 do
    sys_cnt = sys_cnt + 1
    sys_idx[sys_cnt] = sys_val
    sys_val = reaper.MIDI_EnumSelTextSysexEvts(take, sys_val)
end

local grid = reaper.GetExtState("Quantize", "Grid")
if (grid == "") then grid = "120" end
local toggle = reaper.GetExtState("Quantize", "Toggle")
if (toggle == "") then toggle = "0" end

local user_ok, input_cav = reaper.GetUserInputs('Quantize', 2, 'Enter A Tick,0=Default 1=Start 2=End 3=Pos', grid ..','.. toggle)
grid, toggle = input_cav:match("(.*),(.*)")
if not user_ok or not tonumber(grid) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("Quantize", "Grid", grid, false)
reaper.SetExtState("Quantize", "Toggle", toggle, false)
grid = grid / tick

function StartTimes()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_02 % grid) > (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                elseif (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, out_ppq, nil, nil, nil, nil, false)
        end
    end
end
function Position()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_02 % grid) > (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                elseif (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
                endppqpos = endppqpos - (startppqpos - out_ppq)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, out_ppq, endppqpos, nil, nil, nil, false)
        end
    end
end
function NoteDurations()
    for i = 1, #note_idx do
        local _, selected, _, startppqpos, endppqpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (end_cdenom - start_cdenom) < (grid / 2) and (beats_01 % grid) < (grid / 2) then
                    out_beatpos = end_cdenom - (beats_02 % grid) + grid
                elseif (beats_02 % grid) < (grid / 2) then
                    out_beatpos = end_cdenom - (beats_02 % grid)
                else
                    out_beatpos = end_cdenom - (beats_02 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetNote(take, note_idx[i], true, nil, nil, out_ppq, nil, nil, nil, false)
        end
    end
end
function CCEvents()
    for i = 1, #ccs_idx do
        local _, selected, _, ppqpos, _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetCC(take, ccs_idx[i], true, nil, out_ppq, nil, nil, nil, nil, false)
        end
    end
end
function TextSysEvents()
    for i = 1, #sys_idx do
        local _, selected, _, ppqpos, _, _ = reaper.MIDI_GetTextSysexEvt(take, sys_idx[i])
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            if swing == 0 then
                if (beats_01 % grid) < (grid / 2) then
                    out_beatpos = start_cdenom - (beats_01 % grid)
                else
                    out_beatpos = start_cdenom - (beats_01 % grid) + grid
                end
                out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
                out_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, out_pos)
            end
            reaper.MIDI_SetTextSysexEvt(take, sys_idx[i], true, nil, out_ppq, nil, nil, false) 
        end
    end
end
function Main()
    reaper.Undo_BeginBlock()
    reaper.MIDI_DisableSort(take)
    
    local flag
    if reaper.GetToggleCommandStateEx(32060, 40681) == 1 then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
        flag = true
    end
    if toggle == "3" then
        Position()
    elseif toggle == "2" then
        NoteDurations()
    elseif toggle == "1" then
        StartTimes()
    else
        StartTimes()
        NoteDurations()
        CCEvents()
        TextSysEvents()
    end
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)

    reaper.MIDI_Sort(take)

    if flag then
        reaper.MIDIEditor_LastFocused_OnCommand(40681,0) -- Options: Correct overlapping notes while editing
    end

    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Quantize", 0)
end
Main()
reaper.SN_FocusMIDIEditor()
reaper.defer(Main)