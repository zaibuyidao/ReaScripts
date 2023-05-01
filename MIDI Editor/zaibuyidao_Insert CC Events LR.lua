-- @description Insert CC Events LR
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
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

if language == "简体中文" then
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
    jserr = "错误"
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    jserr = "錯誤"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    jserr = "Error"
end

if not reaper.SNM_GetIntConfigVar then
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

if not reaper.APIExists("JS_Localize") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
end

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
    reaper.MIDI_DisableSort(take)
    _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

    local msg2 = reaper.GetExtState("InsertCCEventsLR", "CCNum")
    if (msg2 == "") then msg2 = "10" end
    local msg3 = reaper.GetExtState("InsertCCEventsLR", "ValueA")
    if (msg3 == "") then msg3 = "1" end
    local msg4 = reaper.GetExtState("InsertCCEventsLR", "ValueB")
    if (msg4 == "") then msg4 = "127" end

    if language == "简体中文" then
        title = "插入CC事件LR"
        captions_csv = "CC编号,L,R"
    elseif language == "繁体中文" then
        title = "插入CC事件LR"
        captions_csv = "CC編號,L,R"
    else
        title = "Insert CC Events LR"
        captions_csv = "CC Number,L,R"
    end

    local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, msg2..','..msg3..','.. msg4)
    if not uok then return reaper.SN_FocusMIDIEditor() end

    msg2, msg3, msg4 = uinput:match("(.*),(.*),(.*)")
    if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) then return end

    reaper.SetExtState("InsertCCEventsLR", "CCNum", msg2, false)
    reaper.SetExtState("InsertCCEventsLR", "ValueA", msg3, false)
    reaper.SetExtState("InsertCCEventsLR", "ValueB", msg4, false)

    setOneNote()

    local flag = true
    
    for i = 0, notecnt-1 do
        local retval, selected, muted, startpos, endpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected then
            if flag == true then
                reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg3)
                flag = false
            else
                reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg4)
                flag = true
            end
        end
    end
    reaper.MIDI_Sort(take)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()