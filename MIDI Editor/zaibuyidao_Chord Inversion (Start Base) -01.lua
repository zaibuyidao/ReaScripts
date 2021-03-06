--[[
 * ReaScript Name: Chord Inversion (Start Base) -01
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-3)
  + Initial release
--]]

midiEditor=reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(midiEditor) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end
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
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function deleteSelNote() --删除选中音符
  reaper.MIDIEditor_OnCommand(midiEditor, 40002)
end
function insertNote(note) --插入音符
  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, false)
end
function insertNotes(notes) --插入音符组
    for k,note in pairs(notes) do
        reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, false)
    end
end
function moveDownNotes(notes) 
    if #notes<=1 then return end --如果音符组数量不大于1则不处理

    local pitchFlags={} --用来标记这个音符组存在哪些音高
    for k,note in pairs(notes) do
        pitchFlags[note.pitch]=1
    end
    local containPitchs={} --用来储存音符组的所有音高
    for pitch in pairs(pitchFlags) do
        table.insert(containPitchs,pitch)
    end
    table.sort(containPitchs,function(a,b) return a>b end) --将音高排序

    local pitchLables={} --用来记录每个不同的音高属于哪个标签（标签即ABCD，对应数组中的1234，“以下统一用标签指代音高属于ABCD中的哪个”）,即 标签=pitchLables[音高]
    local lableNum={} --用来记录不同的标签在该组音符中含有音高的数量，即该组音符中含有A有多少个，B有多少个，C有多少个。。。 ,即 标签数量=lableNum[标签]
    local cnt=1 --下一个将被加入的标签
    for i=1,#containPitchs do --这个循环用来遍历全部的音高，将上面4个变量进行赋值
        if i==1 then
            pitchLables[containPitchs[i]]=cnt
            lableNum[cnt]=1
            cnt=cnt+1
            goto continue
        end
        for j=i-1,1,-1 do  --将当前音高于前面已经遍历过的每一个音高进行比较，判断是不是和前面的音高属于同个标签，如果在前面没有找到，那么就以cnt值作为新的标签，并将cnt+1
            if ( containPitchs[i] -containPitchs[j] ) % 12 ==0 then 
                pitchLables[containPitchs[i]]=pitchLables[containPitchs[j]]
                lableNum[ pitchLables[containPitchs[j]] ]=lableNum[ pitchLables[containPitchs[j]] ] + 1
                break
            end
        end
        if pitchLables[containPitchs[i]]==nil then 
            pitchLables[containPitchs[i]]=cnt
            lableNum[cnt]=1
            cnt=cnt+1
        end
        ::continue::
    end 

    local bottomPitch=containPitchs[#containPitchs] --底部音符的音高
    local comparedPitch
    local lastPitch --将被叠加的音符的音高
    local minDistant=128
    local tempDistant=0

    if lableNum[1]==1 then lastPitch=containPitchs[1] goto Last_Pitch end

    for i=#containPitchs-1,1,-1 do
        comparedPitch=bottomPitch
        while true do
            tempDistant = comparedPitch - containPitchs[i]
            if tempDistant>0 then
                if tempDistant<minDistant then 
                    minDistant=tempDistant 
                    lastPitch=containPitchs[i]
                end
                break
            end
            comparedPitch=comparedPitch+12
        end
    end

    ::Last_Pitch::

    repeat  --重复将被叠加的音符的音高-12，直到这个音高比原来顶部的音高要小
        lastPitch=lastPitch-12
    until lastPitch<bottomPitch

    if lastPitch<0 then return end --如果将被叠加的音高小于，则直接返回，不再继续进行处理

    local appiledInfos={} --储存原音符音高和被改变后的音高的映射关系，即 改变后的音高 = appliedInfos[原音符音高]
    for i=2,#containPitchs do
        appiledInfos[ containPitchs[i-1] ]=containPitchs[i]
    end
    appiledInfos[ containPitchs[#containPitchs] ]=lastPitch
    
    for i=1,#notes do  --利用appiledInfos表将全部音符音高逐个改变
        notes[i].pitch=appiledInfos[ notes[i].pitch ]
    end
end
function main()
    reaper.Undo_BeginBlock()
    reaper.MIDI_DisableSort(take)
    local times=1
    local noteGroups={}
    for note in selNoteIterator() do
        if noteGroups[note.startPos]==nil then noteGroups[note.startPos]={} end
        table.insert(noteGroups[note.startPos],note)
    end
    deleteSelNote()
    for k,notes in pairs(noteGroups) do
        for i=1,tonumber(times) do
            moveDownNotes(notes)
        end
        insertNotes(notes)
    end
    reaper.MIDI_Sort(take)
    reaper.Undo_EndBlock("Chord Inversion (Start Base) -01", 0)
end

main()
reaper.UpdateArrange()