--[[
 * ReaScript Name: Duplicate Events (Within Time Selection)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2020-2-16)
  # Bug fix
 * v1.0 (2020-2-13)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
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
for i = 1, #note_idx do
    _, sel, _, start_ppq[i], end_ppq[i], _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
end

local ppqpos = {}
for i = 1, #ccs_idx do
    _, sel, _, ppqpos[i], _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
end

function DuplicateNotes()
    local note_len = math.floor(0.5 + (table_max(end_ppq) - table_min(start_ppq)))
    local qn_note_start =  reaper.MIDI_GetProjQNFromPPQPos(take, table_min(start_ppq))
    local _, qn_note_bar_start, qn_note_bar_end = reaper.TimeMap_QNToMeasures(0, qn_note_start)
    local note_meas_dur = math.floor(0.5 + (qn_note_bar_end - qn_note_bar_start)) * tick
    local proj_note_start = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq))

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)

        if selected == true then
            for x = 0, 4  do
                x = 1 << x
                if note_len > tick / (x * 2) and note_len <= tick / x then
                    local proj_note_end_01 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq) + tick / x)
                    reaper.GetSet_LoopTimeRange(true, false, proj_note_start, proj_note_end_01, false)
                end
            end
            if note_len > tick and note_len <= tick * 2 then
                local proj_note_end_02 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq) + tick * 2)
                reaper.GetSet_LoopTimeRange(true, false, proj_note_start, proj_note_end_02, false)
            end
            if note_len > tick * 2 and note_len <= note_meas_dur then
                local proj_note_end_03 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq) + note_meas_dur)
                reaper.GetSet_LoopTimeRange(true, false, proj_note_start, proj_note_end_03, false)
            end
            for n = 1, 99 do
                if note_len > note_meas_dur * n and note_len <= note_meas_dur * (n + 1) then
                    local proj_note_end_04 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(start_ppq) + note_meas_dur * (n + 1))
                    reaper.GetSet_LoopTimeRange(true, false, proj_note_start, proj_note_end_04, false)
                end
            end

        end
        i = i + 1
    end
end

function DuplicateCCs()
    local cc_len = math.floor(0.5 + (table_max(ppqpos) - table_min(ppqpos)))
    local qn_cc_start =  reaper.MIDI_GetProjQNFromPPQPos(take, table_min(ppqpos))
    local _, qn_cc_bar_start, qn_cc_bar_end = reaper.TimeMap_QNToMeasures(0, qn_cc_start)
    local cc_meas_dur = math.floor(0.5 + (qn_cc_bar_end - qn_cc_bar_start)) * tick
    local proj_cc_start = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos))

    for i = 0, ccs - 1 do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        if selected == true then
            for y = 0, 4  do
                y = 1 << y
                if cc_len > tick / (y * 2) and cc_len <= tick / y then
                    local proj_cc_end_01 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos) + tick / y)
                    reaper.GetSet_LoopTimeRange(true, false, proj_cc_start, proj_cc_end_01, false)
                end
            end
            if cc_len > tick and cc_len <= tick * 2 then
                local proj_cc_end_02 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos) + tick * 2)
                reaper.GetSet_LoopTimeRange(true, false, proj_cc_start, proj_cc_end_02, false)
            end
            if cc_len > tick * 2 and cc_len <= cc_meas_dur then
                local proj_cc_end_03 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos) + cc_meas_dur)
                reaper.GetSet_LoopTimeRange(true, false, proj_cc_start, proj_cc_end_03, false)
            end
            for c = 1, 99 do
                if cc_len > cc_meas_dur * c and cc_len <= cc_meas_dur * (c + 1) then
                    local proj_cc_end_04 = reaper.MIDI_GetProjTimeFromPPQPos(take, table_min(ppqpos) + cc_meas_dur * (c + 1))
                    reaper.GetSet_LoopTimeRange(true, false, proj_cc_start, proj_cc_end_04, false)
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
    local mix_len = math.floor(0.5 + (mix_end - mix_start))
    local qn_mix_start =  reaper.MIDI_GetProjQNFromPPQPos(take, mix_start)
    local _, qn_mix_bar_start, qn_mix_bar_end = reaper.TimeMap_QNToMeasures(0, qn_mix_start)
    local mix_meas_dur = math.floor(0.5 + (qn_mix_bar_end - qn_mix_bar_start)) * tick
    local proj_mix_start = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start)

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected == true then
            for x = 0, 4  do
                x = 1 << x
                if mix_len > tick / (x * 2) and mix_len <= tick / x then
                    local proj_note_end_01 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + tick / x)
                    reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_note_end_01, false)
                end
            end
            if mix_len > tick and mix_len <= tick * 2 then
                local proj_note_end_02 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + tick * 2)
                reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_note_end_02, false)
            end
            if mix_len > tick * 2 and mix_len <= mix_meas_dur then
                local proj_note_end_03 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + mix_meas_dur)
                reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_note_end_03, false)
            end
            for n = 1, 99 do
                if mix_len > mix_meas_dur * n and mix_len <= mix_meas_dur * (n + 1) then
                    local proj_note_end_04 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + mix_meas_dur * (n + 1))
                    reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_note_end_04, false)
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
                if mix_len > tick / (y * 2) and mix_len <= tick / y then
                    local proj_cc_end_01 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + tick / y)
                    reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_cc_end_01, false)
                end
            end
            if mix_len > tick and mix_len <= tick * 2 then
                local proj_cc_end_02 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + tick * 2)
                reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_cc_end_02, false)
            end
            if mix_len > tick * 2 and mix_len <= mix_meas_dur then
                local proj_cc_end_03 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + mix_meas_dur)
                reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_cc_end_03, false)
            end
            for c = 1, 99 do
                if mix_len > mix_meas_dur * c and mix_len <= mix_meas_dur * (c + 1) then
                    local proj_cc_end_04 = reaper.MIDI_GetProjTimeFromPPQPos(take, mix_start + mix_meas_dur * (c + 1))
                    reaper.GetSet_LoopTimeRange(true, false, proj_mix_start, proj_cc_end_04, false)
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
reaper.MIDIEditor_LastFocused_OnCommand(40883, 0) -- Edit: Duplicate events within time selection
RestoreCursorPos()
--reaper.MIDIEditor_LastFocused_OnCommand(40467, 0) -- Time selection: Remove time selection and loop points

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(title, 0)
