--[[
 * ReaScript Name: Duplicate Events To Edit Cursor (Multitrack)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
 * Version: 1.2
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

function CountAllSelEvents() -- 对所有选中的音符和CC进行遍历
    note_cnt, note_idx = 0, {}
    note_val = reaper.MIDI_EnumSelNotes(take, -1)
    while note_val ~= -1 do
        note_cnt = note_cnt + 1
        note_idx[note_cnt] = note_val
        note_val = reaper.MIDI_EnumSelNotes(take, note_val)
    end
    if #note_idx > 0 then isDuplicateNotes = true end -- 未选中轨道并且只有MIDI编辑器被激活。只要音符选择数大于0，就需要复制音符
    start_ppq = {}
    end_ppq = {}
    for i = 1, #note_idx do
        _, sel, _, start_ppq[i], end_ppq[i], _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
    end

    ccs_cnt, ccs_idx = 0, {}
    ccs_val = reaper.MIDI_EnumSelCC(take, -1)
    while ccs_val ~= -1 do
        ccs_cnt = ccs_cnt + 1
        ccs_idx[ccs_cnt] = ccs_val
        ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
    end
    if #ccs_idx > 0 then isDuplicateCCs = true end -- 未选中轨道并且只有MIDI编辑器被激活。只要cc选择数大于0，就需要复制CC
    ppqpos = {}
    for i = 1, #ccs_idx do
        _, sel, _, ppqpos[i], _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
    end
end

function DuplicateNotes(m) -- 最小位置通过参数m传入
    local note_dur = math.floor(0.5 + cur_pos - m) -- 长度补偿，将光标位置减去所有选中音符起始位置的最小值
    for i = 1, #note_idx do
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
        local start_meas = m
        local start_tick = startppqpos - start_meas
        local tick_01 = start_tick % table_max(end_ppq)

        reaper.MIDI_InsertNote(take, true, muted, startppqpos + note_dur, endppqpos + note_dur, chan, pitch, vel, false)
        if not (tick_01 > table_max(end_ppq)) then
            reaper.MIDI_SetNote(take, note_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
end

function DuplicateCCs(m) -- 最小位置通过参数m传入
    local cc_dur = math.floor(0.5 + cur_pos - m) -- 长度补偿，将光标位置减去所有选中CC起始位置的最小值
    for i = 1, #ccs_idx do
        local retval, selected, muted, cc_pos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
        local _, shape, beztension = reaper.MIDI_GetCCShape(take, ccs_idx[i])
        local cc_meas = m
        local cc_tick = cc_pos - cc_meas
        local tick_02 = cc_tick % table_max(ppqpos)

        reaper.MIDI_InsertCC(take, true, muted, cc_pos + cc_dur, chanmsg, chan, msg2, msg3)
        if not (tick_02 > table_max(ppqpos)) then
            reaper.MIDI_SetCC(take, ccs_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
        ccevtcnt = ccevtcnt + 1
        reaper.MIDI_SetCCShape(take, ccevtcnt, shape, beztension, false)
    end
end

isDuplicateNotesMulti = false -- 是否需要复制音符(仅针对选中的轨道)
isDuplicateCCsMulti = false -- 是否需要复制CC(仅针对选中的轨道)
isDuplicateNotes = false -- 是否需要复制音符(仅针对激活的MIDI编辑器)
isDuplicateCCs = false -- 是否需要复制CC(仅针对激活的MIDI编辑器)

script_title = "Duplicate Events To Edit Cursor (Multitrack)"
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.Undo_BeginBlock()

min_start_ppq = math.huge -- 包含多轨 start_ppq 最小值
min_ppqpos = math.huge -- 包含多轨 ppqpos 最小值

for i = 1, count_sel_items do -- 对全部选中轨道的音符和CC进行遍历
    item = reaper.GetSelectedMediaItem(0, i - 1)
    take = reaper.GetTake(item, 0)
    note_cnt, note_idx = 0, {}
    note_val = reaper.MIDI_EnumSelNotes(take, -1)
    while note_val ~= -1 do
        note_cnt = note_cnt + 1
        note_idx[note_cnt] = note_val
        note_val = reaper.MIDI_EnumSelNotes(take, note_val)
    end
    if #note_idx > 0 then isDuplicateNotesMulti = true end -- 只要有一轨音符选择数大于0，就需要复制音符
    start_ppq = {} -- 获得音符开头位置
    end_ppq = {} -- 获得音符结尾位置
    for i = 1, #note_idx do
        _, sel, _, start_ppq[i], end_ppq[i], _, _, _ = reaper.MIDI_GetNote(take, note_idx[i])
    end
    min_start_ppq = table_min({min_start_ppq, table_min(start_ppq)})

    ccs_cnt, ccs_idx = 0, {}
    ccs_val = reaper.MIDI_EnumSelCC(take, -1)
    while ccs_val ~= -1 do
        ccs_cnt = ccs_cnt + 1
        ccs_idx[ccs_cnt] = ccs_val
        ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
    end
    if #ccs_idx > 0 then isDuplicateCCsMulti = true end -- 只要有一轨CC选择数大于0，就需要复制cc
    ppqpos = {} -- 获得CC位置
    for i = 1, #ccs_idx do
        _, sel, _, ppqpos[i], _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
    end
    min_ppqpos = table_min({min_ppqpos, table_min(ppqpos)})
end

if count_sel_items > 0 then
    -- Msg("count_sel_items > 0")
    for i = 1, count_sel_items do
        item = reaper.GetSelectedMediaItem(0, i - 1)
        take = reaper.GetTake(item, 0)
        if not take or not reaper.TakeIsMIDI(take) then return end
        CountAllSelEvents()
        cur_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
        _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
        ccevtcnt = ccevtcnt - 1
        reaper.MIDI_DisableSort(take)
        if isDuplicateNotesMulti and not isDuplicateCCsMulti then -- 只复制音符
            DuplicateNotes(min_start_ppq)
        elseif isDuplicateCCsMulti and not isDuplicateNotesMulti then -- 只复制CC
            DuplicateCCs(min_ppqpos)
        elseif isDuplicateCCsMulti and isDuplicateNotesMulti then -- 同时复制
            local m = table_min{min_ppqpos, min_start_ppq}
            DuplicateNotes(m)
            DuplicateCCs(m)
        end
        reaper.MIDI_Sort(take)
    end
else
    -- Msg("count_sel_items == 0")
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    CountAllSelEvents()
    cur_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
    _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
    ccevtcnt = ccevtcnt - 1
    reaper.MIDI_DisableSort(take)
    if isDuplicateNotes and not isDuplicateCCs then -- 只复制音符
        DuplicateNotes(table_min(start_ppq))
    elseif isDuplicateCCs and not isDuplicateNotes then -- 只复制CC
        DuplicateCCs(table_min(ppqpos))
    elseif isDuplicateCCs and isDuplicateNotes then -- 同时复制
        local m = table_min{table_min(ppqpos), table_min(start_ppq)}
        DuplicateNotes(m)
        DuplicateCCs(m)
    end
    reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(script_title, 0)
reaper.UpdateArrange()