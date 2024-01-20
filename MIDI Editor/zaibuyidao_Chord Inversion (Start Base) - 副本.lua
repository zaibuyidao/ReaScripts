-- @description Chord Inversion (Start Base)
-- @version 1.1.1
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

midiEditor=reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(midiEditor) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ")
    end
    reaper.ShowConsoleMsg("\n")
end

function getSystemLanguage()
    local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
    local os = reaper.GetOS()
    local lang

    if os == "Win32" or os == "Win64" then -- Windows
        if locale == 936 then -- Simplified Chinese
            lang = "简体中文"
        elseif locale == 950 then -- Traditional Chinese
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "OSX32" or os == "OSX64" then -- macOS
        local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
        if lang == "zh-CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh-TW" then -- 繁体中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "Linux" then -- Linux
        local handle = io.popen("echo $LANG")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
        if lang == "zh_CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh_TW" then -- 繁體中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    end

    return lang
end

local language = getSystemLanguage()

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

function countEvts() --获取选中音符数量
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    return notecnt
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

function moveUpNotes(notes) 
    if #notes<=1 then return end --如果音符组数量不大于1则不处理

    local pitchFlags={} --用来标记这个音符组存在哪些音高
    for k,note in pairs(notes) do
        pitchFlags[note.pitch]=1
    end
    local containPitchs={} --用来储存音符组的所有音高
    for pitch in pairs(pitchFlags) do
        table.insert(containPitchs,pitch)
    end
    table.sort(containPitchs) --将音高排序

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

    local lastPitch --将被叠加的音符的音高

    local topPitch=containPitchs[#containPitchs] --顶部音符的音高
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

    repeat  --重复将被叠加的音符的音高+12，直到这个音高比原来顶部的音高要大
        lastPitch=lastPitch+12
    until lastPitch>topPitch

    if lastPitch>127 then return end --如果将被叠加的音高大于127，则直接返回，不再继续进行处理

    local appiledInfos={} --储存原音符音高和被改变后的音高的映射关系，即 改变后的音高 = appliedInfos[原音符音高]
    for i=2,#containPitchs do
        appiledInfos[ containPitchs[i-1] ]=containPitchs[i]
    end
    appiledInfos[ containPitchs[#containPitchs] ]=lastPitch
    
    for i=1,#notes do  --利用appiledInfos表将全部音符音高逐个改变
        notes[i].pitch=appiledInfos[ notes[i].pitch ]
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

function getInput(title,lable,default)
    title=title or "Title"
    lable=lable or "Lable:"
    userOK, get_value = reaper.GetUserInputs(title, 1, lable, default)
    if userOK then return get_value end
end

function main()
    local title, captions_csv = "", ""
    if language == "简体中文" then
        title = "和弦转位(基于开始位置)"
        captions_csv = "次数"
    elseif language == "繁体中文" then
        title = "和弦轉位(基於開始位置)"
        captions_csv = "次數"
    else
        title = "Chord Inversion (Start Base)"
        captions_csv = "Times"
    end

    local times = reaper.GetExtState("CHORD_INVERSION_START_BASE", "Times")
    if (times == "") then times = "1" end
    times = getInput("Chord Inversion (Start Base)", "Times", times)
    if times == nil then return end
    reaper.SetExtState("CHORD_INVERSION_START_BASE", "Times", times, false)

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
        reaper.Undo_EndBlock(title, -1)
    end
end

reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()