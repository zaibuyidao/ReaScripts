--[[
 * ReaScript Name: Strum Velocity Decrement
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-3-4)
  + Initial release
--]]

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
function table.sortByKey(tab,key,ascend)
    if ascend==nil then ascend=true end
    table.sort(tab,function(a,b)
        if ascend then return a[key]<b[key] end
        return a[key]>b[key]
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
function getMutiInput(title,num,lables,defaults)
    title=title or "Title"
    lables=lables or "Lable:"
    local userOK, getValue = reaper.GetUserInputs(title, num, lables, defaults)
    if userOK then return string.split(getValue,",") end
end
function main()
    local inputs= getMutiInput("Strum Velocity Decrement",3,"Defaule Decrement,Start Range,End Range","2,0,15") --获取用户输入
    if not inputs then return end
    local decreaseValue=tonumber(inputs[1])
    local rangeL=tonumber(inputs[2]) --起始范围
    local rangeR=tonumber(inputs[3]) --结束范围
    if (not decreaseValue) or (not rangeL) or (not rangeR) or (decreaseValue==0) or (rangeL<0) or (rangeR<0) or (rangeR<rangeL) then return end --判断用户输入是否合法
    local noteGroups={} --音符组,以第一个插入的音符起始位置作为索引
    local groupData={} --音符组的索引对应的最近一次插入的音符的起始位置，即 最近一次插入的音符起始位置=groupData[音符组索引]
    local flag --用以标记当前音符是否已经插入到音符组中
    local diff --差值
    local lastIndex --上一个插入音符的索引
    for note in selNoteIterator() do
        flag=false
        for index,notes in pairs(noteGroups) do
            diff=math.abs(note.startPos-groupData[index]) --计算差值
            if diff <= rangeR and diff >= rangeL and index==lastIndex then --判断差值是否符合
                table.insert(noteGroups[index],note)
                groupData[index]=note.startPos
                flag=true --如果符合则插入音符组，并标记flag
                break
            end
        end
        if flag then goto continue end --如果flag被标记，那么音符已经插入过，直接处理下一个音符
        noteGroups[note.startPos]={} --以当前音符起始位置作为索引，创建以此为索引的新表，并插入音符到该表中
        groupData[note.startPos]=note.startPos
        lastIndex=note.startPos
        table.insert(noteGroups[note.startPos],note)
        ::continue::
    end
    for index,notes in pairs(noteGroups) do
        if #notes==1 then goto continue end
        if notes[1].startPos==notes[2].startPos then --如果存在起始位置相同的音符，那么则按照音高排序
            table.sortByKey(notes,"pitch")
        else
            table.sortByKey(notes,"startPos",decreaseValue>0) --否则按照起始位置进行排序
        end
        for i=1,#notes do
            notes[i].vel=notes[i].vel-(i-1)*math.abs(decreaseValue) --对音高进行递减操作
            setNote(notes[i],notes[i].sel) --将改变音高后的note重新设置
        end
        ::continue::
    end
end
reaper.MIDI_DisableSort(take)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Strum Velocity Decrement", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()