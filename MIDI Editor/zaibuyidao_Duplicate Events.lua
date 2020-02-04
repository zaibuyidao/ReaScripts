--[[
 * ReaScript Name: Duplicate Events
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
 * v1.0 (2020-2-4)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
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

function DuplicateNotes()

    local len = table_max(end_ppq) - table_min(start_ppq)

    for i = 0, notes - 1 do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        local start_meas = table_min(start_ppq)
        local start_tick = startppqpos - start_meas
        local tick_01 = start_tick % table_max(end_ppq)
        if selected == true then
            if len > 10 and len <= 60 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 60, endppqpos + 60, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 60 and len <= 120 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 120, endppqpos + 120, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 120 and len <= 240 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 240, endppqpos + 240, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 240 and len <= 480 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 480, endppqpos + 480, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 480 and len <= 960 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 960, endppqpos + 960, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 960 and len <= 1920 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 1920, endppqpos + 1920, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 1920 and len <= 3840 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 3840, endppqpos + 3840, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 3840 and len <= 7680 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 7680, endppqpos + 7680, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if len > 7680 and len <= 15360 then
                reaper.MIDI_InsertNote(take, true, muted, startppqpos + 15360, endppqpos + 15360, chan, pitch, vel, false)
                if not (tick_01 > table_max(end_ppq)) then
                    reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
        end
        i = i + 1
    end

end

function DuplicateCCs()

    local cc_len = table_max(ppqpos) - table_min(ppqpos)

    for i = 0, ccs - 1 do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
        local cc_meas = table_min(ppqpos)
        local cc_tick = cc_pos - cc_meas
        local tick_02 = cc_tick % table_max(ppqpos)

        if selected == true then
            if cc_len >= 10 and cc_len < 60 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 60, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 60 and cc_len < 120 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 120, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 120 and cc_len < 240 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 240, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 240 and cc_len < 480 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 480, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 480 and cc_len < 960 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 960, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 960 and cc_len < 1920 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 1920, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 1920 and cc_len < 3840 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 3840, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 3840 and cc_len < 7680 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 7680, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
            if cc_len >= 7680 and cc_len <= 15360 then
                reaper.MIDI_InsertCC(take, true, muted, cc_pos + 15360, chanmsg, chan, msg2, msg3)
                if not (tick_02 > table_max(ppqpos)) then
                    reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                end
            end
        end
        i = i + 1
    end

end

function DuplicateMix()

    local len = table_max(end_ppq) - table_min(start_ppq)
    local cc_len = table_max(ppqpos) - table_min(ppqpos)

    if len > cc_len then

        for i = 0, notes - 1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            local start_meas = table_min(start_ppq)
            local start_tick = startppqpos - start_meas
            local tick_01 = start_tick % table_max(end_ppq)
            if selected == true then
                if len > 10 and len <= 60 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 60, endppqpos + 60, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 60 and len <= 120 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 120, endppqpos + 120, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 120 and len <= 240 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 240, endppqpos + 240, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 240 and len <= 480 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 480, endppqpos + 480, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 480 and len <= 960 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 960, endppqpos + 960, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 960 and len <= 1920 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 1920, endppqpos + 1920, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 1920 and len <= 3840 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 3840, endppqpos + 3840, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 3840 and len <= 7680 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 7680, endppqpos + 7680, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 7680 and len <= 15360 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 15360, endppqpos + 15360, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
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
                if len > 10 and len <= 60 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 60, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 60 and len <= 120 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 120, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 120 and len <= 240 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 240, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 240 and len <= 480 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 480, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 480 and len <= 960 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 960, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 960 and len <= 1920 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 1920, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 1920 and len <= 3840 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 3840, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 3840 and len <= 7680 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 7680, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if len > 7680 and len <= 15360 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 15360, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
            end
            i = i + 1
        end

    elseif len < cc_len then

        for i = 0, ccs - 1 do
            local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            local cc_meas = table_min(ppqpos)
            local cc_tick = cc_pos - cc_meas
            local tick_02 = cc_tick % table_max(ppqpos)

            if selected == true then
                if cc_len > 10 and cc_len < 60 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 60, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 60 and cc_len < 120 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 120, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 120 and cc_len < 240 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 240, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 240 and cc_len < 480 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 480, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 480 and cc_len < 960 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 960, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 960 and cc_len < 1920 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 1920, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 1920 and cc_len < 3840 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 3840, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 3840 and cc_len < 7680 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 7680, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 7680 and cc_len < 15360 then
                    reaper.MIDI_InsertCC(take, true, muted, cc_pos + 15360, chanmsg, chan, msg2, msg3)
                    if not (tick_02 > table_max(ppqpos)) then
                        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
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
                if cc_len > 10 and cc_len < 60 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 60, endppqpos + 60, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 60 and cc_len < 120 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 120, endppqpos + 120, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 120 and cc_len < 240 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 240, endppqpos + 240, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 240 and cc_len < 480 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 480, endppqpos + 480, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 480 and cc_len < 960 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 960, endppqpos + 960, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 960 and cc_len < 1920 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 1920, endppqpos + 1920, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 1920 and cc_len < 3840 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 3840, endppqpos + 3840, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 3840 and cc_len < 7680 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 7680, endppqpos + 7680, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
                    end
                end
                if cc_len >= 7680 and cc_len <= 15360 then
                    reaper.MIDI_InsertNote(take, true, muted, startppqpos + 15360, endppqpos + 15360, chan, pitch, vel, false)
                    if not (tick_01 > table_max(end_ppq)) then
                        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
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
