--[[
 * ReaScript Name: End Time (Multitrack)
 * Version: 2.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v2.0 (2020-9-27)
  + Code rewrite
 * v1.0 (2020-9-5)
  + Initial release
--]]

function print(param)
    if type(param) == "table" then
        table.print(param)
        return
    end
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function table.print(t)
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
end

function table.sortByKey(tab, key, ascend) -- 對於傳入的table按照指定的key值進行排序,ascend參數決定是否為升序(由低往高),預設為true。
    direct = direct or true
    table.sort(tab, function(a, b)
        if ascend then return a[key] < b[key] end
        return a[key] > b[key]
    end)
end

function getNote(sel) -- 根據傳入的sel索引值，返回指定位置的含有音符信息的表
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

function getAllNotes() -- 獲取所有音符
    local notes = {}
    for i = 1, notecnt do table.insert(notes, getNote(i - 1)) end
    return notes
end

function deleteSelNote() -- 刪除選中音符
    for i = 1, notecnt do reaper.MIDI_DeleteNote(take, 0) end
end

function insertNote(note) -- 插入音符
    reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, false)
end

function min(a, b)
    if a > b then return b end
    return a
end

function endTime()
    local notes = getAllNotes() -- 1.獲取選中音符
    deleteSelNote() -- 2.刪除選中音符
    local pitchNotes = {}
    for _, v in pairs(notes) do -- 3.將音符按照音高分組，相同音高的音符將被分到同一個組
        -- print(v.pitch)
        if pitchNotes[v.pitch] == nil then pitchNotes[v.pitch] = {} end
        table.insert(pitchNotes[v.pitch], v)
    end
    local dur = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 4.獲取光標位置
    for _, v in pairs(pitchNotes) do -- 5.遍歷按音高分組後的音符
        table.sortByKey(v, "startPos", true) -- 6.按選中音符的起始位置由小到大排序
        for i = 1, #v do -- 7.處理音符結束位置
            -- print(v[i].startPos)
            if v[i].startPos >= dur then goto continue end
            if not v[i].selected then goto continue end
            if (i == #v) then -- 最後一個音符的結束位置等於光標位置
                v[i].endPos = dur
            else
                v[i].endPos = min(dur, v[i + 1].startPos)
            end
            ::continue::
            insertNote(v[i]) -- 8.插入新音符
        end
    end
end

function main()
    reaper.Undo_BeginBlock()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then -- 如果有item被選中
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
            reaper.MIDI_DisableSort(take)
            endTime()
            reaper.MIDI_Sort(take)
        end
    else -- 否則，判斷MIDI編輯器是否被激活
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        if take == nil then return end
        _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
        reaper.MIDI_DisableSort(take)
        endTime()
        reaper.MIDI_Sort(take)
    end
    reaper.Undo_EndBlock("End Time (Multitrack)", -1)
    reaper.UpdateArrange()
end

main()
