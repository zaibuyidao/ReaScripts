--[[
 * ReaScript Name: Select Odd Events
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-23)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function table.sortByKey(tab, key, ascend) -- 對於傳入的table按照指定的key值進行排序,ascend參數決定是否為升序,默認為true
    direct = direct or true
    table.sort(tab, function(a, b)
        if ascend then return a[key] > b[key] end
        return a[key] < b[key]
    end)
end

local midiEditor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(midiEditor) -- 全局take值
if take == nil then return end
local function getNote(sel) -- 根據傳入的sel索引值，返回指定位置的含有音符信息的表
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
    return {
        ["retval"] = retval,
        ["selected"] = selected,
        ["muted"] = muted,
        ["startPos"] = startPos,
        ["endPos"] = endPos,
        ["channel"] = channel,
        ["pitch"] = pitch,
        ["vel"] = vel,
        ["sel"] = sel
    }
end
local function selNoteIterator() -- 迭代器 用於返回選中的每一個音符信息表
    local sel = -1
    return function()
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        if sel == -1 then return end
        return getNote(sel)
    end
end
local function deleteSelNote() -- 刪除選中音符
    i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
        reaper.MIDI_DeleteNote(take, i)
        i = reaper.MIDI_EnumSelNotes(take, -1)
    end
end
local function insertNote(note) -- 插入音符
    reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, true)
end
function setNote(note,sel,arg) -- 傳入一個音符信息表已經索引值，對指定索引位置的音符信息進行修改
    reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end
local function getSelNotes()
    local notes = {}
    for note in selNoteIterator() do table.insert(notes, note) end
    return notes
end
local function getAllNotes()
    local notes = {}
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    for i = 0, notecnt - 1 do table.insert(notes, getNote(i)) end
    return notes
end
local function min(a, b)
    if a > b then return b end
    return a
end
function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print("")
end
table.print = print_r

-- 主要實現
local notes = getSelNotes()
local startNotes = {} -- 按照起始位置分組的音符
for _, note in pairs(notes) do
    if startNotes[note.startPos] == nil then startNotes[note.startPos] = {} end
    startNotes[note.startPos][note.pitch] = note -- 這裡不用table.insert插入，直接使用音高作為索引插入，目的是為了後面方便判斷這一組音符中某個音高有沒有音符
end
local startPosIndex = {} -- 存放所有音符起始位置的數組，作用是用來對startNotes進行索引
for startPos, _ in pairs(startNotes) do table.insert(startPosIndex, startPos) end
table.sort(startPosIndex) -- 按照起始位置進行排序
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
reaper.Undo_BeginBlock()
local step = 2 -- 設置步長遞增為2
reaper.MIDI_DisableSort(take)
for i = 1, #note_idx do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
    for j = 2, #startPosIndex, step do
        if startppqpos == startPosIndex[j] then
            reaper.MIDI_SetNote(take, note_idx[i], false, nil, nil, nil, nil, nil, nil, false)
        end
    end
    if #startPosIndex == 1 then reaper.MIDI_SetNote(take, note_idx[i], false, nil, nil, nil, nil, nil, nil, false) end
end
for i = 2, #ccs_idx, step do
    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
    reaper.MIDI_SetCC(take, ccs_idx[i], false, nil, nil, nil, nil, nil, nil, false)
end
if #ccs_idx == 1 then reaper.MIDI_SetCC(take, ccs_idx[1], false, nil, nil, nil, nil, nil, nil, false) end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Select Odd Events", 0)
reaper.UpdateArrange()
