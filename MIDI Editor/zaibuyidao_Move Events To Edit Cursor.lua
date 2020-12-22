--[[
 * ReaScript Name: Move Events To Edit Cursor
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
 * v1.0 (2020-12-22)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

title = "Move Events To Edit Cursor"
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
_, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
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

function MoveNotes()
    local note_dur = math.floor(0.5 + cur_pos - table_min(start_ppq))
    local note = {}
    for i = 1, #note_idx do
        note[i] = {}
        note[i].ret, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel = reaper.MIDI_GetNote(take, note_idx[i])
    end
    j = reaper.MIDI_EnumSelNotes(take, -1)
    while j > -1 do
      reaper.MIDI_DeleteNote(take, j)
      j = reaper.MIDI_EnumSelNotes(take, -1)
    end
    for i = 1, #note_idx do
        reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos + note_dur, note[i].endppqpos + note_dur, note[i].chan, note[i].pitch, note[i].vel, false)
    end
end

function MoveCCs()
    local cc_dur = math.floor(0.5 + cur_pos - table_min(ppqpos))
    local ccs = {}
    local cc_sharp = {}
    for i = 1, #ccs_idx do
        ccs[i] = {}
        cc_sharp[i] = {}
        ccs[i].ret, ccs[i].sel, ccs[i].muted, ccs[i].cc_pos, ccs[i].chanmsg, ccs[i].chan, ccs[i].msg2, ccs[i].msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
        cc_sharp[i].ret, cc_sharp[i].shape, cc_sharp[i].beztension = reaper.MIDI_GetCCShape(take, ccs_idx[i])
    end
    j = reaper.MIDI_EnumSelCC(take, -1)
    while j > -1 do
        reaper.MIDI_DeleteCC(take, j)
        j = reaper.MIDI_EnumSelCC(take, -1)
    end
    ccevtcnt = ccevtcnt - ccs_cnt
    for i = 1, #ccs_idx do
        reaper.MIDI_InsertCC(take, ccs[i].sel, ccs[i].muted, ccs[i].cc_pos + cc_dur, ccs[i].chanmsg, ccs[i].chan, ccs[i].msg2, ccs[i].msg3)
        ccevtcnt = ccevtcnt + 1
        reaper.MIDI_SetCCShape(take, ccevtcnt - 1, cc_sharp[i].shape, cc_sharp[i].beztension, false)
    end
end

function MoveMix()
    local mix_start
    local mix_end
    if table_min(start_ppq) > table_min(ppqpos) then mix_start = table_min(ppqpos) elseif table_min(start_ppq) < table_min(ppqpos) then mix_start = table_min(start_ppq) elseif table_min(start_ppq) == table_min(ppqpos) then mix_start = table_min(start_ppq) end
    if table_max(end_ppq) > table_max(ppqpos) then mix_end = table_max(end_ppq) elseif table_max(end_ppq) < table_max(ppqpos) then mix_end = table_max(ppqpos) elseif table_max(end_ppq) == table_max(ppqpos) then mix_end = table_max(end_ppq) end
    local mix_dur = math.floor(0.5 + (cur_pos - mix_start))

    local note = {}
    for i = 1, #note_idx do
        note[i] = {}
        note[i].ret, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel = reaper.MIDI_GetNote(take, note_idx[i])
    end
    j = reaper.MIDI_EnumSelNotes(take, -1)
    while j > -1 do
      reaper.MIDI_DeleteNote(take, j)
      j = reaper.MIDI_EnumSelNotes(take, -1)
    end
    for i = 1, #note_idx do
        reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos + mix_dur, note[i].endppqpos + mix_dur, note[i].chan, note[i].pitch, note[i].vel, false)
    end

    local ccs = {}
    local cc_sharp = {}
    for i = 1, #ccs_idx do
        ccs[i] = {}
        cc_sharp[i] = {}
        ccs[i].ret, ccs[i].sel, ccs[i].muted, ccs[i].cc_pos, ccs[i].chanmsg, ccs[i].chan, ccs[i].msg2, ccs[i].msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
        cc_sharp[i].ret, cc_sharp[i].shape, cc_sharp[i].beztension = reaper.MIDI_GetCCShape(take, ccs_idx[i])
    end
    j = reaper.MIDI_EnumSelCC(take, -1)
    while j > -1 do
        reaper.MIDI_DeleteCC(take, j)
        j = reaper.MIDI_EnumSelCC(take, -1)
    end
    ccevtcnt = ccevtcnt - ccs_cnt
    for i = 1, #ccs_idx do
        reaper.MIDI_InsertCC(take, ccs[i].sel, ccs[i].muted, ccs[i].cc_pos + mix_dur, ccs[i].chanmsg, ccs[i].chan, ccs[i].msg2, ccs[i].msg3)
        ccevtcnt = ccevtcnt + 1
        reaper.MIDI_SetCCShape(take, ccevtcnt - 1, cc_sharp[i].shape, cc_sharp[i].beztension, false)
    end
end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
if #note_idx > 0 and #ccs_idx == 0 then
    MoveNotes()
elseif #ccs_idx > 0 and #note_idx == 0 then
    MoveCCs()
elseif #ccs_idx > 0 and #note_idx > 0 then
    MoveMix()
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, 0)
reaper.UpdateArrange()