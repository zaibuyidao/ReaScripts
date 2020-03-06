--[[
 * ReaScript Name: Paste Selected Rhythm
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-6)
  + Initial release
--]]

midiEditor = reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(midiEditor) -- 全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
function table.unserialize(lua) -- 将字符串反序列化为table
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = load(lua)
    if func == nil then return nil end
    return func()
end
function getNote(sel) -- 根据传入的sel索引值，返回指定位置的含有音符信息的表
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
function selNoteIterator() -- 迭代器 用于返回选中的每一个音符信息表
    local sel = -1
    return function()
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        if sel == -1 then return end
        return getNote(sel)
    end
end
function deleteSelNote() -- 删除选中音符
    reaper.MIDIEditor_OnCommand(midiEditor, 40002)
end
function insertNote(note) -- 插入音符
    reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, true)
end
function getSavedData(key1, key2) -- 获取已储存的table数据
    return table.unserialize(reaper.GetExtState(key1, key2))
end
function main()
    local pasteInfos = getSavedData("CopySelectedRhythm", "data") -- 获取复制数据
    if #pasteInfos < 0 then return end
    local selPitchInfo = {} -- 选中音符的音高及起始时间数据
    for note in selNoteIterator() do -- 遍历选中音符
        table.insert(selPitchInfo, {["pitch"]=note.pitch,["startPos"]=note.startPos})
    end
    deleteSelNote() -- 删除选中音符
    local minStartPos
    for i, info in ipairs(pasteInfos[1]) do --获取数据中最小的起始时间数据
        if minStartPos==nil then minStartPos=info.startPos end
        if minStartPos>info.startPos then minStartPos=info.startPos end
    end
    for i,insertInfo in pairs(selPitchInfo) do
        for j,note in ipairs (pasteInfos[1]) do
            note.pitch = insertInfo.pitch
            note.startPos = note.startPos + insertInfo.startPos -minStartPos --偏移
            note.endPos = note.endPos + insertInfo.startPos -minStartPos
            insertNote(note) --加入音符
            note.startPos = note.startPos - insertInfo.startPos + minStartPos --恢复
            note.endPos = note.endPos - insertInfo.startPos +minStartPos
        end
    end
end
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Paste Selected Rhythm", 0)
reaper.UpdateArrange()