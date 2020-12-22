--[[
 * ReaScript Name: Move Events To Edit Cursor (Multitrack)
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

function CountAllSelEvents() -- 對所有選中的音符和CC進行遍歷
    note_cnt, note_idx = 0, {}
    note_val = reaper.MIDI_EnumSelNotes(take, -1)
    while note_val ~= -1 do
        note_cnt = note_cnt + 1
        note_idx[note_cnt] = note_val
        note_val = reaper.MIDI_EnumSelNotes(take, note_val)
    end
    if #note_idx > 0 then isDuplicateNotes = true end -- 未選中軌道並且只有MIDI編輯器被激活。只要音符選擇數大於0，就需要移動音符
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
    if #ccs_idx > 0 then isDuplicateCCs = true end -- 未選中軌道並且只有MIDI編輯器被激活。只要cc選擇數大於0，就需要移動CC
    ppqpos = {}
    for i = 1, #ccs_idx do
        _, sel, _, ppqpos[i], _, _, _, _ = reaper.MIDI_GetCC(take, ccs_idx[i])
    end
end

function MoveNotes(m) -- 最小位置通過參數m傳入
    local note_dur = math.floor(0.5 + cur_pos - m) -- 長度補償，將光標位置減去所有選中音符起始位置的最小值
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

function MoveCCs(m) -- 最小位置通過參數m傳入
    local cc_dur = math.floor(0.5 + cur_pos - m) -- 長度補償，將光標位置減去所有選中CC起始位置的最小值
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

isMoveNotesMulti = false -- 是否需要移動音符(僅針對選中的軌道)
isMoveCCsMulti = false -- 是否需要移動CC(僅針對選中的軌道)
isMoveNotes = false -- 是否需要移動音符(僅針對激活的MIDI編輯器)
isMoveCCs = false -- 是否需要移動CC(僅針對激活的MIDI編輯器)

script_title = "Move Events To Edit Cursor (Multitrack)"
count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.Undo_BeginBlock()

min_start_ppq = math.huge -- 包含多軌 start_ppq 最小值
min_ppqpos = math.huge -- 包含多軌 ppqpos 最小值

for i = 1, count_sel_items do -- 對全部選中軌道的音符和CC進行遍歷
    item = reaper.GetSelectedMediaItem(0, i - 1)
    take = reaper.GetTake(item, 0)
    note_cnt, note_idx = 0, {}
    note_val = reaper.MIDI_EnumSelNotes(take, -1)
    while note_val ~= -1 do
        note_cnt = note_cnt + 1
        note_idx[note_cnt] = note_val
        note_val = reaper.MIDI_EnumSelNotes(take, note_val)
    end
    if #note_idx > 0 then isMoveNotesMulti = true end -- 只要有一軌音符選擇數大於0，就需要移動音符
    start_ppq = {} -- 獲得音符開頭位置
    end_ppq = {} -- 獲得音符結尾位置
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
    if #ccs_idx > 0 then isMoveCCsMulti = true end -- 只要有一軌CC選擇數大於0，就需要移動CC
    ppqpos = {} -- 獲得CC位置
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
        _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
        CountAllSelEvents()
        cur_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
        reaper.MIDI_DisableSort(take)
        if isMoveNotesMulti and not isMoveCCsMulti then -- 只移動音符
            MoveNotes(min_start_ppq)
        elseif isMoveCCsMulti and not isMoveNotesMulti then -- 只移動CC
            MoveCCs(min_ppqpos)
        elseif isMoveCCsMulti and isMoveNotesMulti then -- 同時移動
            local m = table_min{min_ppqpos, min_start_ppq}
            MoveNotes(m)
            MoveCCs(m)
        end
        reaper.MIDI_Sort(take)
    end
else
    -- Msg("count_sel_items == 0")
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    CountAllSelEvents()
    cur_pos = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0))
    reaper.MIDI_DisableSort(take)
    if isMoveNotes and not isMoveCCs then -- 只移動音符
        MoveNotes(table_min(start_ppq))
    elseif isMoveCCs and not isMoveNotes then -- 只移動CC
        MoveCCs(table_min(ppqpos))
    elseif isMoveCCs and isMoveNotes then -- 同時移動
        local m = table_min{table_min(ppqpos), table_min(start_ppq)}
        MoveNotes(m)
        MoveCCs(m)
    end
    reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(script_title, 0)
reaper.UpdateArrange()