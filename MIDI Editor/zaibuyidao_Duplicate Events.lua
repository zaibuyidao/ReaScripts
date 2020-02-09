--[[
 * ReaScript Name: Duplicate Events
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.4 (2020-2-9)
  + Optimize script
 * v1.3 (2020-2-8)
  + Version update
 * v1.2 (2020-2-8)
  + Extended boundary support
 * v1.1 (2020-2-7)
  # Bug fix
 * v1.0 (2020-2-4)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
title = "Duplicate Events"
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)

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

local item = reaper.GetSelectedMediaItem(0,0)
local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") 
local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
local item_end = (item_len - item_pos) + item_len

function DuplicateNotes()

    local qn_note_len = reaper.MIDI_GetProjQNFromPPQPos(take, table_max(end_ppq))
    local qn_note_meas = reaper.MIDI_GetProjQNFromPPQPos(take, (reaper.MIDI_GetPPQPos_EndOfMeasure(take, table_min(end_ppq)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(start_ppq))))
    local note_len = table_max(end_ppq) - table_min(start_ppq)
    local note_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, table_min(end_ppq)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(start_ppq))

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        local start_meas = table_min(start_ppq)
        local start_tick = startppqpos - start_meas
        local tick_01 = start_tick % table_max(end_ppq)

        if selected == true then
            if note_len >= 0 and note_len <= tick / 8 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 8, endppqpos + tick / 8, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len + 1 / 8) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 8)
                end
            end
            if note_len > tick / 8 and note_len <= tick / 4 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 4, endppqpos + tick / 4, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len + 1 / 4) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 4)
                end
            end
            if note_len > tick / 4 and note_len <= tick / 2 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 2, endppqpos + tick / 2, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len + 1 / 2) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 2)
                end
            end
            if note_len > tick / 2 and note_len <= tick then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick, endppqpos + tick, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len + 1) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1)
                end
            end
            if note_len > tick and note_len <= tick * 2 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick * 2, endppqpos + tick * 2, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len + 1 * 2) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 * 2)
                end
            end
            if note_len > tick * 2 and note_len <= note_meas_dur then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur, endppqpos + note_meas_dur, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_note_len  + qn_note_meas) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + qn_note_meas)
                end
            end
            for n = 1, 99 do
                if note_len > note_meas_dur * n and note_len <= note_meas_dur * (n + 1) then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur * (n + 1), endppqpos + note_meas_dur * (n + 1), chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + qn_note_meas * (n + 1)) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + qn_note_meas * (n + 1))
                    end
                end
            end
        end
        i = i + 1
    end
end

function DuplicateCCs()

    local qn_cc_len = reaper.MIDI_GetProjQNFromPPQPos(take, table_max(ppqpos))
    local qn_cc_meas = reaper.MIDI_GetProjQNFromPPQPos(take, (reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + table_min(ppqpos)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(ppqpos))))
    local cc_len = table_max(ppqpos) - table_min(ppqpos)
    local cc_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + table_min(ppqpos)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(ppqpos))

    for i = 0, ccs - 1 do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        local cc_meas = table_min(ppqpos)
        local cc_tick = cc_pos - cc_meas
        local tick_02 = cc_tick % table_max(ppqpos)

        if selected == true then
            if cc_len >= 0 and cc_len < tick / 8 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 8, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len + 1 / 8) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 8)
                end
            end
            if cc_len >= tick / 8 and cc_len < tick / 4 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 4, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len + 1 / 4) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 4)
                end
            end
            if cc_len >= tick / 4 and cc_len < tick / 2 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 2, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len + 1 / 2) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 2)
                end
            end
            if cc_len >= tick / 2 and cc_len < tick then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len + 1) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1)
                end
            end
            if cc_len >= tick and cc_len < tick * 2 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick * 2, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len + 1 * 2) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 * 2)
                end
            end
            if cc_len >= tick * 2 and cc_len < cc_meas_dur then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
                if item_end < (qn_cc_len  + qn_cc_meas) then
                    reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + qn_cc_meas)
                end
            end
            for c = 1, 99 do
                if cc_len >= cc_meas_dur * c and cc_len < cc_meas_dur * (c + 1) then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur * (c + 1), chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len  + qn_cc_meas * (c + 1)) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + qn_cc_meas * (c + 1))
                    end
                end
            end
        end
        i = i + 1
    end
end

function DuplicateMix()

    local qn_note_len = reaper.MIDI_GetProjQNFromPPQPos(take, table_max(end_ppq))
    local qn_note_meas = reaper.MIDI_GetProjQNFromPPQPos(take, (reaper.MIDI_GetPPQPos_EndOfMeasure(take, table_min(end_ppq)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(start_ppq))))
    local note_len = table_max(end_ppq) - table_min(start_ppq)
    local note_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, table_min(end_ppq)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(start_ppq))
    local qn_cc_len = reaper.MIDI_GetProjQNFromPPQPos(take, table_max(ppqpos))
    local qn_cc_meas = reaper.MIDI_GetProjQNFromPPQPos(take, (reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + table_min(ppqpos)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(ppqpos))))
    local cc_len = table_max(ppqpos) - table_min(ppqpos)
    local cc_meas_dur = reaper.MIDI_GetPPQPos_EndOfMeasure(take, 10 + table_min(ppqpos)) - reaper.MIDI_GetPPQPos_StartOfMeasure(take, table_min(ppqpos))

    if note_len > cc_len then

        for i = 0, notes - 1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            local start_meas = table_min(start_ppq)
            local start_tick = startppqpos - start_meas
            local tick_01 = start_tick % table_max(end_ppq)
    
            if selected == true then
                if note_len >= 0 and note_len <= tick / 8 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 8, endppqpos + tick / 8, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + 1 / 8) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 8)
                    end
                end
                if note_len > tick / 8 and note_len <= tick / 4 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 4, endppqpos + tick / 4, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + 1 / 4) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 4)
                    end
                end
                if note_len > tick / 4 and note_len <= tick / 2 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 2, endppqpos + tick / 2, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + 1 / 2) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 / 2)
                    end
                end
                if note_len > tick / 2 and note_len <= tick then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick, endppqpos + tick, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + 1) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1)
                    end
                end
                if note_len > tick and note_len <= tick * 2 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick * 2, endppqpos + tick * 2, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len + 1 * 2) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + 1 * 2)
                    end
                end
                if note_len > tick * 2 and note_len <= note_meas_dur then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur, endppqpos + note_meas_dur, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_note_len  + qn_note_meas) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + qn_note_meas)
                    end
                end
                for n = 1, 99 do
                    if note_len > note_meas_dur * n and note_len <= note_meas_dur * (n + 1) then
                        reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur * (n + 1), endppqpos + note_meas_dur * (n + 1), chan, pitch, vel, false)
                        if not (tick_01 > table_max(end_ppq)) then
                            reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                        end
                        if item_end < (qn_note_len + qn_note_meas * (n + 1)) then
                            reaper.MIDI_SetItemExtents(item, item_pos, qn_note_len + qn_note_meas * (n + 1))
                        end
                    end
                end
            end
            i = i + 1
        end

        for i = 0, ccs - 1 do
            local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            local cc_meas = table_min(ppqpos)
            local cc_tick = cc_pos - cc_meas
            local tick_02 = cc_tick % table_max(ppqpos)
    
            if selected == true then
                if note_len >= 0 and note_len <= tick / 8 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 8, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if note_len > tick / 8 and note_len <= tick / 4 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 4, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if note_len > tick / 4 and note_len <= tick / 2 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 2, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if note_len > tick / 2 and note_len <= tick then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if note_len > tick and note_len <= tick * 2 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick * 2, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if note_len > tick * 2 and note_len <= cc_meas_dur then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                for c = 1, 99 do
                    if note_len > cc_meas_dur * c and note_len <= cc_meas_dur * (c + 1) then
                        reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur * (c + 1), chanmsg, chan, msg2, msg3)
                        if not (tick_02 > table_max(ppqpos)) then
                            reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                        end
                    end
                end
            end
            i = i + 1
        end

    elseif cc_len > note_len then

        for i = 0, ccs - 1 do
            local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            local cc_meas = table_min(ppqpos)
            local cc_tick = cc_pos - cc_meas
            local tick_02 = cc_tick % table_max(ppqpos)
    
            if selected == true then
                if cc_len >= 0 and cc_len < tick / 8 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 8, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len + 1 / 8) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 8)
                    end
                end
                if cc_len >= tick / 8 and cc_len < tick / 4 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 4, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len + 1 / 4) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 4)
                    end
                end
                if cc_len >= tick / 4 and cc_len < tick / 2 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick / 2, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len + 1 / 2) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 / 2)
                    end
                end
                if cc_len >= tick / 2 and cc_len < tick then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len + 1) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1)
                    end
                end
                if cc_len >= tick and cc_len < tick * 2 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + tick * 2, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len + 1 * 2) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + 1 * 2)
                    end
                end
                if cc_len >= tick * 2 and cc_len < cc_meas_dur then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                    if item_end < (qn_cc_len  + qn_cc_meas) then
                        reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + qn_cc_meas)
                    end
                end
                for c = 1, 99 do
                    if cc_len >= cc_meas_dur * c and cc_len < cc_meas_dur * (c + 1) then
                        reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_meas_dur * (c + 1), chanmsg, chan, msg2, msg3)
                        if not (tick_02 > table_max(ppqpos)) then
                            reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                        end
                        if item_end < (qn_cc_len  + qn_cc_meas * (c + 1)) then
                            reaper.MIDI_SetItemExtents(item, item_pos, qn_cc_len + qn_cc_meas * (c + 1))
                        end
                    end
                end
            end
            i = i + 1
        end

        for i = 0, notes - 1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            local start_meas = table_min(start_ppq)
            local start_tick = startppqpos - start_meas
            local tick_01 = start_tick % table_max(end_ppq)
    
            if selected == true then
                if cc_len >= 0 and cc_len < tick / 8 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 8, endppqpos + tick / 8, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= tick / 8 and cc_len < tick / 4 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 4, endppqpos + tick / 4, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= tick / 4 and cc_len < tick / 2 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick / 2, endppqpos + tick / 2, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= tick / 2 and cc_len < tick then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick, endppqpos + tick, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= tick and cc_len < tick * 2 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + tick * 2, endppqpos + tick * 2, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= tick * 2 and cc_len < note_meas_dur then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur, endppqpos + note_meas_dur, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                for n = 1, 99 do
                    if cc_len >= note_meas_dur * n and cc_len < note_meas_dur * (n + 1) then
                        reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_meas_dur * (n + 1), endppqpos + note_meas_dur * (n + 1), chan, pitch, vel, false)
                        if not (tick_01 > table_max(end_ppq)) then
                            reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                        end
                    end
                end
            end
            i = i + 1
        end
    else
        DuplicateNotes()
        DuplicateCCs()
    end
end

if #note_idx > 0 and #ccs_idx == 0 then
    DuplicateNotes()
elseif #ccs_idx > 0 and #note_idx == 0 then
    DuplicateCCs()
elseif #ccs_idx > 0 and #note_idx > 0 then
    DuplicateMix()
else
    return
end

reaper.UpdateArrange()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, 0)
