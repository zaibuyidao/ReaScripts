-- @description Glissando
-- @version 1.2.2
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) -- 全局take值
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

function getNote(sel) -- 根據傳入的sel索引值, 返回指定位置的含有音符信息的表
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

function selNoteIterator() -- 迭代器 用於返回選中的每一個音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end

local function getSelNotes() -- 獲得選中的音符 返回notes表
    local notes={}
    for note in selNoteIterator() do
        table.insert(notes,note)
    end
    return notes
end

function insertNote(note) -- 插入音符
  reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos,note.channel,note.pitch, note.vel, true)
end

function getOverlayPitchsMajor(baseScale,ordinal,origPitch) -- 核心計算函數, 三個參數分別代表調號(CDEFGAB), 偏移值, 原音符音高, 返回疊加後的音符音高
    if ordinal>8 then ordinal=8 end
    if ordinal<-8 then ordinal=-8 end
    local scales={ -- 大調音階表 1234567
        0,2,4,5,7,9,11
    }
    local scalesMap={ -- 音階查詢表，可以得到調號在音階表中的位置
        [0]=1,[2]=2,[4]=3,[5]=4,[7]=5,[9]=6,[11]=7
    }
    local pos ={ -- 上疊要用到的表，可以通過0-11的數字得到一個在音階表中的數字
        [0]=0,[1]=0,[2]=2,[3]=2,[4]=4,[5]=5,[6]=5,[7]=7,[8]=7,[9]=9,[10]=9,[11]=11
    }
    local pos2 ={ -- 下疊要用到的表，可以通過0-11的數字得到一個在音階表中的數字
        [0]=0,[1]=2,[2]=2,[3]=4,[4]=4,[5]=5,[6]=7,[7]=7,[8]=9,[9]=9,[10]=11,[11]=11
    }
    local tonesMap={ -- 調號對應的數字
        ["C"]=0, ["C#"]=1, ["D"]=2, ["D#"]=3, ["E"]=4, ["F"]=5, ["F#"]=6, ["G"]=7, ["G#"]=8, ["A"]=9, ["A#"]=10, ["B"]=11
    }

    if not tonesMap[baseScale] then return -1 end

    local tempPitch=origPitch-tonesMap[baseScale]
    local p = tempPitch%12
    local b = tempPitch-p
    local result -- 最終結果
    if ordinal>0 then -- 判斷為上疊
        local tp = scalesMap[pos[p]]+ordinal-1 
        b=b+math.floor((tp-1)/7)*12
        local rp= ((tp-1)%7)+1
        result = b+scales[rp]+tonesMap[baseScale]
    elseif ordinal<0 then -- 判斷為下疊
        local tp = scalesMap[pos2[p]]+ordinal+1
        local rp=tp
        if tp<=0 then 
            b=b-math.floor(1+(-tp)/7)*12
            rp=(6-((-tp)%7))+1
        end
        result = b+scales[rp]+tonesMap[baseScale]
    else
    end

    if result>=0 and result<=127 then return result end -- 判斷是否越界
    return -1
end

function getOverlayPitchsMinor(baseScale,ordinal,origPitch) -- 核心計算函數, 三個參數分別代表調號(cdefgab), 偏移值, 原音符音高, 返回疊加後的音符音高
    if ordinal>8 then ordinal=8 end
    if ordinal<-8 then ordinal=-8 end
    local scales={ -- 小調音階表 6712345
        0,2,3,5,7,8,10
    }
    local scalesMap={ -- 音階查詢表，可以得到調號在音階表中的位置
        [0]=1,[2]=2,[3]=3,[5]=4,[7]=5,[8]=6,[10]=7
    }
    local pos ={ -- 上疊要用到的表，可以通過0-11的數字得到一個在音階表中的數字
        [0]=0,[1]=0,[2]=2,[3]=3,[4]=3,[5]=5,[6]=5,[7]=7,[8]=8,[9]=8,[10]=10,[11]=10
    }
    local pos2 ={ -- 下疊要用到的表，可以通過0-11的數字得到一個在音階表中的數字
        [0]=0,[1]=2,[2]=2,[3]=3,[4]=5,[5]=5,[6]=7,[7]=7,[8]=8,[9]=8,[10]=10,[11]=10
    }
    local tonesMap={ -- 調號對應的數字
        ["c"]=0, ["c#"]=1, ["d"]=2, ["d#"]=3, ["e"]=4, ["f"]=5, ["f#"]=6, ["g"]=7, ["g#"]=8, ["a"]=9, ["a#"]=10, ["b"]=11
    }

    if not tonesMap[baseScale] then return -1 end

    local tempPitch=origPitch-tonesMap[baseScale]
    local p = tempPitch%12
    local b = tempPitch-p
    local result -- 最終結果
    if ordinal>0 then -- 判斷為上疊
        local tp = scalesMap[pos[p]]+ordinal-1
        b=b+math.floor((tp-1)/7)*12
        local rp= ((tp-1)%7)+1
        result = b+scales[rp]+tonesMap[baseScale]
    elseif ordinal<0 then -- 判斷為下疊
        local tp = scalesMap[pos2[p]]+ordinal+1
        local rp=tp
        if tp<=0 then 
            b=b-math.floor(1+(-tp)/7)*12
            rp=(6-((-tp)%7))+1
        end
        result = b+scales[rp]+tonesMap[baseScale]
    else
    end

    if result>=0 and result<=127 then return result end -- 判斷是否越界
    return -1
end

function main()
    local cnt, index = 0, {}
    local val = reaper.MIDI_EnumSelNotes(take, -1)
    while val ~= - 1 do
      cnt = cnt + 1
      index[cnt] = val
      val = reaper.MIDI_EnumSelNotes(take, val)
    end
    if #index < 1 then return reaper.SN_FocusMIDIEditor() end

    local title, captions_csv = "", ""

    if language == "简体中文" then
        title = "刮奏"
        captions_csv = "调号,数量,间隔(滴答),0=左下 1=左上 2=右下 3=右上"
    elseif language == "繁体中文" then
        title = "刮奏"
        captions_csv = "調號,數量,間隔(嘀答),0=左下 1=左上 2=右下 3=右上"
    else
        title = "Glissando"
        captions_csv = "key Signature,Amount,Interval (tick),0=LD 1=LU 2=RD 3=RU"
    end

    key_signature = reaper.GetExtState("Glissando", "Key")
    if (key_signature == "") then key_signature = "C" end
    times = reaper.GetExtState("Glissando", "Times")
    if (times == "") then times = "8" end
    ticks = reaper.GetExtState("Glissando", "Ticks")
    if (ticks == "") then ticks = "60" end
    state_toggle = reaper.GetExtState("Glissando", "Toggle")
    if (state_toggle == "") then state_toggle = "0" end
    
    local userOK, userInputsCSV = reaper.GetUserInputs(title, 4, captions_csv, key_signature..','.. times..','.. ticks..','.. state_toggle)
    if not userOK then return reaper.SN_FocusMIDIEditor() end
    key_signature, times, ticks, state_toggle = userInputsCSV:match("(.*),(.*),(.*),(.*)")
    if not tostring(key_signature) or not tonumber(times) or not tonumber(ticks) or not tonumber(state_toggle) then return reaper.SN_FocusMIDIEditor() end
    
    reaper.SetExtState("Glissando", "Key", key_signature, false)
    reaper.SetExtState("Glissando", "Times", times, false)
    reaper.SetExtState("Glissando", "Ticks", ticks, false)
    reaper.SetExtState("Glissando", "Toggle", state_toggle, false)

    selNotes = getSelNotes()
    local opNote,overlayPitchMajor,overlayPitchMinor -- opNote(用來計算疊加音符的音符) overlayPitch...(將被疊加音符的音高)

    for j = 1, #index do
        opNote = selNotes[j] -- 一個組一個音符
        for i = 1, times do
            if state_toggle == "0" then
                interval = -2
                overlayPitchMajor=getOverlayPitchsMajor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMajor>0 then -- 插入大調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMajor
                    opNote.startPos=opNote.startPos-ticks
                    opNote.endPos=opNote.startPos+ticks
                    opNote.vel=opNote.vel
                    insertNote(opNote)
                end
                overlayPitchMinor=getOverlayPitchsMinor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMinor>0 then  -- 插入小調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMinor
                    opNote.startPos=opNote.startPos-ticks
                    opNote.endPos=opNote.startPos+ticks
                    insertNote(opNote)
                end
            elseif state_toggle == "1" then
                interval = 2
                overlayPitchMajor=getOverlayPitchsMajor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMajor>0 then  -- 插入大調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMajor
                    opNote.startPos=opNote.startPos-ticks
                    opNote.endPos=opNote.startPos+ticks
                    insertNote(opNote)
                end
                overlayPitchMinor=getOverlayPitchsMinor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMinor>0 then  -- 插入小調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMinor
                    opNote.startPos=opNote.startPos-ticks
                    opNote.endPos=opNote.startPos+ticks
                    insertNote(opNote)
                end
            elseif state_toggle == "2" then
                interval = -2
                overlayPitchMajor=getOverlayPitchsMajor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMajor>0 then  -- 插入大調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMajor
                    opNote.startPos=opNote.endPos
                    opNote.endPos=opNote.endPos+ticks
                    insertNote(opNote)
                end
                overlayPitchMinor=getOverlayPitchsMinor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMinor>0 then  -- 插入小調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMinor
                    opNote.startPos=opNote.endPos
                    opNote.endPos=opNote.endPos+ticks
                    insertNote(opNote)
                end
            elseif state_toggle == "3" then
                interval = 2
                overlayPitchMajor=getOverlayPitchsMajor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMajor>0 then  -- 插入大調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMajor
                    opNote.startPos=opNote.endPos
                    opNote.endPos=opNote.endPos+ticks
                    insertNote(opNote)
                end
                overlayPitchMinor=getOverlayPitchsMinor(key_signature,interval,opNote.pitch) -- 調用函數計算將要疊加音符的音高
                if overlayPitchMinor>0 then  -- 插入小調音程, 如果計算失敗會得到-1, 這裡判斷一下再插入音符
                    opNote.pitch=overlayPitchMinor
                    opNote.startPos=opNote.endPos
                    opNote.endPos=opNote.endPos+ticks
                    insertNote(opNote)
                end
            end
        end
    end
end
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()