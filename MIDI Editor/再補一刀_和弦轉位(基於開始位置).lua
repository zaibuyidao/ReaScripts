--[[
 * ReaScript Name: 和弦轉位(基於開始位置)
 * Version: 1.1
 * Author: 再補一刀
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
function countEvts() --獲取選中音符數量
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    return notecnt
end
function getNote(sel) --根據傳入的sel索引值，返回指定位置的含有音符信息的表
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
function selNoteIterator() --迭代器 用於返回選中的每一個音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function deleteSelNote() --刪除選中音符
  reaper.MIDIEditor_OnCommand(midiEditor, 40002)
end
function insertNote(note) --插入音符
  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, false)
end
function insertNotes(notes) --插入音符組
    for k,note in pairs(notes) do
        reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, false)
    end
end
function moveUpNotes(notes) 
    if #notes<=1 then return end --如果音符組數量不大於1則不處理

    local pitchFlags={} --用來標記這個音符組存在哪些音高
    for k,note in pairs(notes) do
        pitchFlags[note.pitch]=1
    end
    local containPitchs={} --用來儲存音符組的所有音高
    for pitch in pairs(pitchFlags) do
        table.insert(containPitchs,pitch)
    end
    table.sort(containPitchs) --將音高排序

    local pitchLables={} --用來記錄每個不同的音高屬於哪個標籤（標籤即ABCD，對應數組中的1234，“以下統一用標籤指代音高屬於ABCD中的哪個”）,即 標籤=pitchLables[音高]
    local lableNum={} --用來記錄不同的標籤在該組音符中含有音高的數量，即該組音符中含有A有多少個，B有多少個，C有多少個。 。 。 ,即 標籤數量=lableNum[標籤]
    local cnt=1 --下一個將被加入的標籤
    for i=1,#containPitchs do --這個循環用來遍歷全部的音高，將上面4個變量進行賦值
        if i==1 then
            pitchLables[containPitchs[i]]=cnt
            lableNum[cnt]=1
            cnt=cnt+1
            goto continue
        end
        for j=i-1,1,-1 do  --將當前音高於前面已經遍歷過的每一個音高進行比較，判斷是不是和前面的音高屬於同個標籤，如果在前面沒有找到，那麼就以cnt值作為新的標籤，並將cnt+1
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

    local lastPitch --將被疊加的音符的音高

    local topPitch=containPitchs[#containPitchs] --頂部音符的音高
    local comparedPitch
    
    local minDistant=128
    local tempDistant=0

    if lableNum[1]==1 then lastPitch=containPitchs[1] goto Last_Pitch end

    for i=#containPitchs-1,1,-1 do
        comparedPitch=topPitch
        while true do
            tempDistant = containPitchs[i] - comparedPitch
            if tempDistant>0 then
                if tempDistant<minDistant then 
                    minDistant=tempDistant 
                    lastPitch=containPitchs[i]
                end
                break
            end
            comparedPitch=comparedPitch-12
        end
    end
    
    ::Last_Pitch::

    repeat  --重複將被疊加的音符的音高+12，直到這個音高比原來頂部的音高要大
        lastPitch=lastPitch+12
    until lastPitch>topPitch

    if lastPitch>127 then return end --如果將被疊加的音高大於127，則直接返回，不再繼續進行處理

    local appiledInfos={} --儲存原音符音高和被改變後的音高的映射關係，即 改變後的音高 = appliedInfos[原音符音高]
    for i=2,#containPitchs do
        appiledInfos[ containPitchs[i-1] ]=containPitchs[i]
    end
    appiledInfos[ containPitchs[#containPitchs] ]=lastPitch
    
    for i=1,#notes do  --利用appiledInfos表將全部音符音高逐個改變
        notes[i].pitch=appiledInfos[ notes[i].pitch ]
    end
end
function moveDownNotes(notes) 
    if #notes<=1 then return end --如果音符組數量不大於1則不處理

    local pitchFlags={} --用來標記這個音符組存在哪些音高
    for k,note in pairs(notes) do
        pitchFlags[note.pitch]=1
    end
    local containPitchs={} --用來儲存音符組的所有音高
    for pitch in pairs(pitchFlags) do
        table.insert(containPitchs,pitch)
    end
    table.sort(containPitchs,function(a,b) return a>b end) --將音高排序

    local pitchLables={} --用來記錄每個不同的音高屬於哪個標籤（標籤即ABCD，對應數組中的1234，“以下統一用標籤指代音高屬於ABCD中的哪個”）,即 標籤=pitchLables[音高]
    local lableNum={} --用來記錄不同的標籤在該組音符中含有音高的數量，即該組音符中含有A有多少個，B有多少個，C有多少個。 。 。 ,即 標籤數量=lableNum[標籤]
    local cnt=1 --下一個將被加入的標籤
    for i=1,#containPitchs do --這個循環用來遍歷全部的音高，將上面4個變量進行賦值
        if i==1 then
            pitchLables[containPitchs[i]]=cnt
            lableNum[cnt]=1
            cnt=cnt+1
            goto continue
        end
        for j=i-1,1,-1 do  --將當前音高於前面已經遍歷過的每一個音高進行比較，判斷是不是和前面的音高屬於同個標籤，如果在前面沒有找到，那麼就以cnt值作為新的標籤，並將cnt+1
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
    local lastPitch --將被疊加的音符的音高
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

    repeat  --重複將被疊加的音符的音高-12，直到這個音高比原來頂部的音高要小
        lastPitch=lastPitch-12
    until lastPitch<bottomPitch

    if lastPitch<0 then return end --如果將被疊加的音高小於，則直接返回，不再繼續進行處理

    local appiledInfos={} --儲存原音符音高和被改變後的音高的映射關係，即 改變後的音高 = appliedInfos[原音符音高]
    for i=2,#containPitchs do
        appiledInfos[ containPitchs[i-1] ]=containPitchs[i]
    end
    appiledInfos[ containPitchs[#containPitchs] ]=lastPitch
    
    for i=1,#notes do  --利用appiledInfos表將全部音符音高逐個改變
        notes[i].pitch=appiledInfos[ notes[i].pitch ]
    end
end
function getInput(title,lable,default)
    title=title or "Title"
    lable=lable or "Lable:"
    userOK, get_value = reaper.GetUserInputs(title, 1, lable, default)
    if userOK then return get_value end
end
function main()
    local times = reaper.GetExtState("ChordInversionStartBase", "Times")
    if (times == "") then times = "1" end
    times = getInput("和弦轉位(基於開始位置)", "次數", times)
    if times == nil then return end
    reaper.SetExtState("ChordInversionStartBase", "Times", times, false)
    local noteGroups={}
    for note in selNoteIterator() do
        if noteGroups[note.startPos]==nil then noteGroups[note.startPos]={} end
        table.insert(noteGroups[note.startPos],note)
    end
    if tonumber(times)==nil then return reaper.SN_FocusMIDIEditor() end
    reaper.Undo_BeginBlock()
    deleteSelNote()
    for k,notes in pairs(noteGroups) do
        times=tonumber(times)
        if times==nil then return end
        local up=true
        if times<0 then
            up=false
            times=-times
        end
        for i=1,tonumber(times) do
            if up then
                moveUpNotes(notes)
            else
                moveDownNotes(notes)
            end
        end
        if up==false then times=-times end
        insertNotes(notes)
        reaper.Undo_EndBlock("和弦轉位(基於開始位置)", -1)
    end
end
function checkForNewVersion(newVersion)
    local appVersion = reaper.GetAppVersion()
    appVersion = tonumber(appVersion:match('[%d%.]+'))
    if newVersion > appVersion then
        reaper.MB('將REAPER更新到 '..'('..newVersion..' 或更高版本)', '', 0)
        return
    else
        return true
    end
end
reaper.MIDI_DisableSort(take)
local CFNV = checkForNewVersion(6.03)
if CFNV then main() end
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()