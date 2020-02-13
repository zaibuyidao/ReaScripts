--[[
 * ReaScript Name: Duplicate Events (Within Time Selection)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-13)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local midieditor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(midieditor)
if take == nil then return end
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local qn_tick = tick / (tick * 2)
local retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

function SaveCursorPos()
	init_cursor_pos = reaper.GetCursorPosition()
end

function RestoreCursorPos()
	reaper.SetEditCurPos(init_cursor_pos, false, false)
end

function table_max(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

function table_min(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

local note_cnt, note_idx = 0, {}
local note_val = reaper.MIDI_EnumSelNotes(take, -1)
while note_val ~= -1 do
    note_cnt = note_cnt + 1
    note_idx[note_cnt] = note_val
    note_val = reaper.MIDI_EnumSelNotes(take, note_val)
end

local ccs_cnt, ccs_idx = 0, {}
local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
end

local start_ppq = {}
local end_ppq = {}
local ppqpos = {}

for i = 1, #note_idx do
    _, sel, _, start_ppq[i], end_ppq[i], _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
end

for i = 1, #ccs_idx do
    _, sel, _, ppqpos[i], _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
end

function DuplicateNotes()
    local note_len = table_max(end_ppq) - table_min(start_ppq)
    local note_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, table_min(end_ppq)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(start_ppq))
    local qn_note_start = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq))
    local qn_note_meas_dur = (note_meas_dur / tick) / 2

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)

        if selected == true then
            for x = 0, 4  do
                x = 1 << x
                if note_len > tick / (x * 2) and note_len <= tick / x then
                    reaper.GetSet_LoopTimeRange(true, false, qn_note_start, qn_note_start + qn_tick / x, false)
                end
            end
            if note_len > tick and note_len <= tick * 2 then
                reaper.GetSet_LoopTimeRange(true, false, qn_note_start, qn_note_start + qn_tick * 2, false)
            end
            if note_len > tick * 2 and note_len <= note_meas_dur then
                reaper.GetSet_LoopTimeRange(true, false, qn_note_start, qn_note_start + qn_note_meas_dur, false)
            end
            for n = 1, 99 do
                if note_len > note_meas_dur * n and note_len <= note_meas_dur * (n + 1) then
                    reaper.GetSet_LoopTimeRange(true, false, qn_note_start, qn_note_start + qn_note_meas_dur * (n + 1), false)
                end
            end
        end
        i = i + 1
    end
end

function DuplicateCCs()
    local cc_len = table_max(ppqpos) - table_min(ppqpos)
    local cc_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + table_min(ppqpos)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(ppqpos))
    local qn_cc_start = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos))
    local qn_cc_meas_dur = (cc_meas_dur / tick) / 2

    for i = 0, ccs - 1 do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        if selected == true then
            for y = 0, 4  do
                y = 1 << y
                if cc_len >= tick / (y * 2) and cc_len < tick / y then
                    reaper.GetSet_LoopTimeRange(true, false, qn_cc_start, qn_cc_start + qn_tick / y, false)
                end
            end
            if cc_len >= tick and cc_len < tick * 2 then
                reaper.GetSet_LoopTimeRange(true, false, qn_cc_start, qn_cc_start + qn_tick * 2, false)
            end
            if cc_len >= tick * 2 and cc_len < cc_meas_dur then
                reaper.GetSet_LoopTimeRange(true, false, qn_cc_start, qn_cc_start + qn_cc_meas_dur, false)
            end
            for c = 1, 99 do
                if cc_len >= cc_meas_dur * c and cc_len < cc_meas_dur * (c + 1) then
                    reaper.GetSet_LoopTimeRange(true, false, qn_cc_start, qn_cc_start + qn_cc_meas_dur * (c + 1), false)
                end
            end
        end
        i = i + 1
    end
end

function DuplicateMix()

    local mix_start
    local mix_end
    if table_min(start_ppq) > table_min(ppqpos) then mix_start = table_min(ppqpos) elseif table_min(start_ppq) < table_min(ppqpos) then mix_start = table_min(start_ppq) elseif table_min(start_ppq) == table_min(ppqpos) then mix_start = table_min(start_ppq) end
    if table_max(end_ppq) > table_max(ppqpos) then mix_end = table_max(end_ppq) elseif table_max(end_ppq) < table_max(ppqpos) then mix_end = table_max(ppqpos) elseif table_max(end_ppq) == table_max(ppqpos) then mix_end = table_max(end_ppq) end
    local mix_len = mix_end - mix_start
    local mix_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + mix_start) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, mix_start)
    local qn_mix_start = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start)
    local qn_mix_meas_dur = (mix_meas_dur / tick) / 2

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected == true then
            for x = 0, 4  do
                x = 1 << x
                if mix_len > tick / (x * 2) and mix_len <= tick / x then
                    reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_tick / x, false)
                end
            end
            if mix_len > tick and mix_len <= tick * 2 then
                reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_tick * 2, false)
            end
            if mix_len > tick * 2 and mix_len <= mix_meas_dur then
                reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_mix_meas_dur, false)
            end
            for n = 1, 99 do
                if mix_len > mix_meas_dur * n and mix_len <= mix_meas_dur * (n + 1) then
                    reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_mix_meas_dur * (n + 1), false)
                end
            end
        end
        i = i + 1
    end

    for i = 0, ccs - 1 do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        if selected == true then
            for y = 0, 4  do
                y = 1 << y
                if mix_len >= tick / (y * 2) and mix_len < tick / y then
                    reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_tick / y, false)
                end
            end
            if mix_len >= tick and mix_len < tick * 2 then
                reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_tick * 2, false)
            end
            if mix_len >= tick * 2 and mix_len < mix_meas_dur then
                reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_mix_meas_dur, false)
            end
            for c = 1, 99 do
                if mix_len >= mix_meas_dur * c and mix_len < mix_meas_dur * (c + 1) then
                    reaper.GetSet_LoopTimeRange(true, false, qn_mix_start, qn_mix_start + qn_mix_meas_dur * (c + 1), false)
                end
            end
        end
        i = i + 1
    end

end

function Main()
    if #note_idx > 0 and #ccs_idx == 0 then
        DuplicateNotes()
    elseif #ccs_idx > 0 and #note_idx == 0 then
        DuplicateCCs()
    elseif #ccs_idx > 0 and #note_idx > 0 then
        DuplicateMix()
    else
        return
    end
end

title = "Duplicate Events (Within Time Selection)"
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

SaveCursorPos()
Main()
reaper.MIDIEditor_OnCommand(midieditor, 40883) -- Edit: Duplicate events within time selection
RestoreCursorPos()
--reaper.MIDIEditor_OnCommand(midieditor, 40467) -- Time selection: Remove time selection and loop points

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(title, 0)
