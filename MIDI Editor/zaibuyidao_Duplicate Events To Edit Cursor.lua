--[[
 * ReaScript Name: Duplicate Events To Edit Cursor
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
 * v1.0 (2020-8-27)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

title = "Duplicate Events To Edit Cursor"
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
cur_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))

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
    local note_dur = cur_pos - table_min(start_ppq)
    for i = 1, #note_idx do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
        local start_meas = table_min(start_ppq)
        local start_tick = startppqpos - start_meas
        local tick_01 = start_tick % table_max(end_ppq)
        
        reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_dur, endppqpos + note_dur, chan, pitch, vel, false)
        if not (tick_01 > table_max(end_ppq)) then
            reaper.MIDI_SetNote(take, note_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
end

function DuplicateCCs()
    local cc_dur = cur_pos - table_min(ppqpos)
    for i = 1, #ccs_idx do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
        local cc_meas = table_min(ppqpos)
        local cc_tick = cc_pos - cc_meas
        local tick_02 = cc_tick % table_max(ppqpos)
        
        reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_dur, chanmsg, chan, msg2, msg3)
        if not (tick_02 > table_max(ppqpos)) then
            reaper.MIDI_SetCC(take, ccs_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
end

function DuplicateMix()
    local mix_start
    local mix_end
    if table_min(start_ppq) > table_min(ppqpos) then mix_start = table_min(ppqpos) elseif table_min(start_ppq) < table_min(ppqpos) then mix_start = table_min(start_ppq) elseif table_min(start_ppq) == table_min(ppqpos) then mix_start = table_min(start_ppq) end
    if table_max(end_ppq) > table_max(ppqpos) then mix_end = table_max(end_ppq) elseif table_max(end_ppq) < table_max(ppqpos) then mix_end = table_max(ppqpos) elseif table_max(end_ppq) == table_max(ppqpos) then mix_end = table_max(end_ppq) end
    local mix_dur = math.floor(0.5 + (cur_pos - mix_start))
    for i = 1, #note_idx do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
        local start_meas = table_min(start_ppq)
        local start_tick = startppqpos - start_meas
        local tick_01 = start_tick % table_max(end_ppq)

        reaper.MIDI_InsertNote(take, true, muted, startppqpos + mix_dur, endppqpos + mix_dur, chan, pitch, vel, false)
        if not (tick_01 > table_max(end_ppq)) then
            reaper.MIDI_SetNote(take, note_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
    for i = 1, #ccs_idx do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
        local cc_meas = table_min(ppqpos)
        local cc_tick = cc_pos - cc_meas
        local tick_02 = cc_tick % table_max(ppqpos)

        reaper.MIDI_InsertCC(take, true, muted, cc_pos + mix_dur, chanmsg, chan, msg2, msg3)
        if not (tick_02 > table_max(ppqpos)) then
            reaper.MIDI_SetCC(take, ccs_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
if #note_idx > 0 and #ccs_idx == 0 then
    DuplicateNotes()
elseif #ccs_idx > 0 and #note_idx == 0 then
    DuplicateCCs()
elseif #ccs_idx > 0 and #note_idx > 0 then
    DuplicateMix()
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, 0)
reaper.UpdateArrange()