--[[
 * ReaScript Name: 插入CC事件AB
 * Version: 1.0
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-28)
  + Initial release
--]]

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
function table.sortByKey(tab,key,ascend) --对于传入的table按照指定的key值进行排序,ascend参数决定是否为升序,默认为true
    direct=direct or true
    table.sort(tab,function(a,b)
        if ascend then return a[key]>b[key] end
        return a[key]<b[key]
    end)
end
function string.split(szFullString, szSeparator)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then  
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)
        nSplitIndex = nSplitIndex + 1  
    end
    return nSplitArray
end
function getNote(sel) --根据传入的sel索引值，返回指定位置的含有音符信息的表
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
    return {
        ["retval"]=retval,
        ["selected"]=selected,
        ["muted"]=muted,
        ["startPos"]=startPos,
        ["endPos"]=endPos,
        ["channel"]=channel,
        ["pitch"]=pitch,
        ["vel"]=vel,
        ["sel"]=sel
    }
end
function setNote(note,sel,arg) --传入一个音符信息表已经索引值，对指定索引位置的音符信息进行修改
    reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function setOneNote()
    local selectedPos=1
    local range=0
    local noteGroups={}
    local groupData={}
    local flag
    for note in selNoteIterator() do
        flag=false
        note.selected=false 
        setNote(note,note.sel)
        for index,notes in pairs(noteGroups) do
            if math.abs(note.startPos-groupData[index]) <= range then
                table.insert(noteGroups[index],note)
                groupData[index]=note.startPos
                flag=true
                break
            end
        end
        if flag then goto continue end
        noteGroups[note.startPos]={}
        groupData[note.startPos]=note.startPos
        table.insert(noteGroups[note.startPos],note)
        ::continue::
    end
    for index,notes in pairs(noteGroups) do --遍历音符组
        if #notes==0 then goto continue end --如果该音符组为零个音符则不处理
        table.sortByKey(notes,"pitch") --根据音高将音符组排序
        if selectedPos>#notes then goto continue end
        notes[selectedPos].selected=true --将selected值设置为true
        setNote(notes[selectedPos],notes[selectedPos].sel) --将改变过的note重新置入
        ::continue::
    end
end
function main()
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    local msg2 = reaper.GetExtState("InsertCCEventsAB", "CCNum")
    if (msg2 == "") then msg2 = "10" end
    local msg3 = reaper.GetExtState("InsertCCEventsAB", "ValueA")
    if (msg3 == "") then msg3 = "1" end
    local msg4 = reaper.GetExtState("InsertCCEventsAB", "ValueB")
    if (msg4 == "") then msg4 = "127" end
    local user_ok, user_input_CSV = reaper.GetUserInputs("插入CC事件AB", 3, "CC編號,A,B", msg2..','..msg3..','.. msg4)
    if not user_ok then return reaper.SN_FocusMIDIEditor() end
    msg2, msg3, msg4 = user_input_CSV:match("(.*),(.*),(.*)")
    if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) then return end
    reaper.SetExtState("InsertCCEventsAB", "CCNum", msg2, false)
    reaper.SetExtState("InsertCCEventsAB", "ValueA", msg3, false)
    reaper.SetExtState("InsertCCEventsAB", "ValueB", msg4, false)
    setOneNote()
    for i = 1, notecnt do
        local retval, selected, muted, startpos, endpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i-1)
        if selected == true then
            if flag == true then
                reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg3)
                flag = false
            else
                reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg4)
                flag = true
            end
        end
    end
end
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("插入CC事件AB", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()