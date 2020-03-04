--[[
 * ReaScript Name: Rhythm Layer Selection
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
function getMutiInput(title,num,lables,defaults)
    title=title or "Title"
    lables=lables or "Lable:"
    local userOK, get_value = reaper.GetUserInputs(title, num, lables, defaults)
    if userOK then return string.split(get_value,",") end
end
function main()
    local inputs= getMutiInput("Rhythm Layer Selection",2,"Ordinal,Interval","1,15") --获取用户输入
    if not inputs then return end
    local selectedPos=tonumber(inputs[1]) --序数值
    local range=tonumber(inputs[2]) --间隔值
    if (not selectedPos) or (not range) or (range<0) then return end --判断用户输入是否合法
    local noteGroups={} --该部分见changeNotesVel注释
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
        if #notes==1 then goto continue end --如果该音符组只有一个音符则不处理
         table.sortByKey(notes,"pitch") --根据音高将音符组排序
         if selectedPos>0 then  --如果输入的序数大于0
            if selectedPos>#notes then goto continue end
            notes[selectedPos].selected=true --将selected值设置为true
            setNote(notes[selectedPos],notes[selectedPos].sel) --将改变过的note重新置入
         elseif selectedPos<0 then --如果输入的序数小于0
            if (#notes + selectedPos +1)<1 then goto continue end
            notes[#notes + selectedPos +1 ].selected=true
            setNote(notes[#notes + selectedPos +1 ],notes[#notes + selectedPos +1 ].sel)
         else
         end
         ::continue::
    end
end
reaper.MIDI_DisableSort(take)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Rhythm Layer Selection", 0)
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()