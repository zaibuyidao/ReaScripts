--[[
 * ReaScript Name: Legato
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-29)
  + Initial release
--]]

function print(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

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
    local retval, selected, muted, startPos, endPos, channel, pitch, vel =
        reaper.MIDI_GetNote(take, sel)
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

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)

-- 主要實現
local notes = getAllNotes()
deleteSelNote() -- 刪除全部選中音符
local startNotes = {} -- 按照起始位置分組的音符
for _, note in pairs(notes) do
    if startNotes[note.startPos] == nil then startNotes[note.startPos] = {} end
    startNotes[note.startPos][note.pitch] = note -- 這裡不用table.insert插入，直接使用音高作為索引插入，目的是為了後面方便判斷這一組音符中某個音高有沒有音符
    if note.selected then startNotes[note.startPos].hasSelected = true end -- 如果有一個音符是選中的，那麼將這組相同起始位置的音符標記為選中
end

local startPosIndex = {} -- 存放所有音符起始位置的數組，作用是用來對startNotes進行索引
for startPos, _ in pairs(startNotes) do table.insert(startPosIndex, startPos) end

table.sort(startPosIndex) -- 按照起始位置進行排序

-- 遍歷除了最後一組的所有音符組，最後一組無需處理
for i = 1, #startPosIndex - 1 do
    -- 判斷下一組音符是否是選中狀態
    if startNotes[startPosIndex[i + 1]].hasSelected then -- 下一組音符中有選中的
        -- 遍歷這組起始位置相同的音符中的​​所有音符
        for _, note in pairs(startNotes[startPosIndex[i]]) do
            if type(note) == "table" and note.selected then -- 因為我們在前面對音符組做了一個hasSelected的標記，所以要判斷一下這個元素是不是table類型的，如果不是table類型的就直接跳過
                note.endPos = startPosIndex[i + 1] -- 調整結束位置為下一組音符的起始位置
                insertNote(note)
            end
        end
    else -- 下一組音符中沒有選中的
        -- 在後面繼續查找還有沒有選中的音符組，如果有，就把後面這個“離當前組最近的”選中的音符組的起始位置賦值給nextStartPos
        local nextStartPos = nil
        if i + 2 <= #startPosIndex then
            for j = i + 2, #startPosIndex do
                if startNotes[startPosIndex[j]].hasSelected then
                    nextStartPos = startPosIndex[j]
                    break
                end
            end
        end

        -- 遍歷這組起始位置相同的音符中的​​所有音符
        for _, note in pairs(startNotes[startPosIndex[i]]) do
            if type(note) == "table" and note.selected then
                if nextStartPos ~= nil then
                    note.endPos = nextStartPos
                end -- 如果前面找到了“離當前組最近的”選中音符組，就把當前音符結束位置設置為那個音符組的起始位置
                -- if startNotes[startPosIndex[i + 1]][note.pitch] ~= nil then
                --     note.endPos = startPosIndex[i + 1]
                -- end -- 判斷下一組音符在相同的音高處有沒有音符，如果有音符就直接把當前音符的結束位置設置為那個音符的起始位置
                insertNote(note)
            end
        end
    end
end

-- 最後一組音符不做處理，直接插入
for _, note in pairs(startNotes[startPosIndex[#startPosIndex]]) do
    if type(note) == "table" and note.selected then insertNote(note) end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Legato", -1)
reaper.UpdateArrange()
