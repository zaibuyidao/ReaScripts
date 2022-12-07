-- @description Random Note Arpeggio
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
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
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
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

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function getAllTakes() -- 获取所有take
    tTake = {}
    if reaper.MIDIEditor_EnumTakes then
        local editor = reaper.MIDIEditor_GetActive()
        for i = 0, math.huge do
            take = reaper.MIDIEditor_EnumTakes(editor, i, false)
            if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
                tTake[take] = true
                tTake[take] = {item = reaper.GetMediaItemTake_Item(take)}
            else
                break
            end
        end
    else
        for i = 0, reaper.CountMediaItems(0)-1 do
            local item = reaper.GetMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
                tTake[take] = true
            end
        end
        
        for take in next, tTake do
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tTake[take] = nil end
        end
    end
    if not next(tTake) then return end
    return tTake
end

function getNote(take, id) -- 根据传入的id索引值，返回指定位置的含有音符信息的表
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, id)
    local getters = {
        remove = function (event) 
            return function(note) 
                reaper.MIDI_DeleteNote(note.take, note.id)
            end 
        end,
        update = function (event)
            return function(note, noSort) 
                reaper.MIDI_SetNote(note.take, note.id, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, noSort)
            end 
        end
    }
    return setmetatable({
        take = take,
        id = id,
        selected = selected,
        muted = muted,
        startPos = startPos,
        endPos = endPos,
        channel = channel,
        pitch = pitch,
        vel = vel
    }, {
        __index = function (note, key) return getters[key](note) end,
    })
end

function selNoteIterator(take) -- 迭代器 用于返回选中的每一个音符信息表
    local sel = -1
    return function()
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        if sel == -1 then return end
        return getNote(take, sel)
    end
end

function deleteSelNote() -- 删除选中音符
    reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40002)
end

function deleteSelNote2(take) -- 删除选中音符
    i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
        reaper.MIDI_DeleteNote(take, i)
        i = reaper.MIDI_EnumSelNotes(take, -1)
    end
end

function insertNote(take, note) -- 插入音符
    reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startPos, note.endPos, note.channel, note.pitch, note.vel, true)
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

function prompt(attr)
    local labels = {}
    local defaults = {}
    local converters = {}
    local defaultConverter = function (...) return ... end
    local remember = attr.remember or {}

    for _, input in ipairs(attr.inputs or {}) do
        if not input.default then 
            table.insert(defaults, "")
        else
            table.insert(defaults, tostring(input.default))
        end
        table.insert(labels, input.label or "")
        table.insert(converters, input.converter or defaultConverter)
    end

    local defaultCsv = table.concat(defaults, ",")
    if remember.enable then
        if  reaper.HasExtState(remember.section, remember.key) then
            defaultCsv = reaper.GetExtState(remember.section, remember.key)
        end
    end

    local ok, resCsv = reaper.GetUserInputs(attr.title or "", #labels, table.concat(labels, ","), defaultCsv)
    if not ok then return nil end

    if remember.enable then
        reaper.SetExtState(remember.section, remember.key, resCsv, remember.persist)
    end

    local res = string.split(resCsv, ",")
    for i=1, #res do
        res[i] = converters[i](res[i])
    end

    return res
end

function getPitchIterator(pitchs, mode)
    local curPitchIdx = -1
    -- 下到上
    if mode == 1 then
        return function ()
            if curPitchIdx <= 0 or curPitchIdx >= #pitchs then 
                curPitchIdx = 1
            else
                curPitchIdx = curPitchIdx + 1
            end
            return pitchs[curPitchIdx]
        end
    -- 上到下
    elseif mode == 2 then
        return function ()
            if curPitchIdx <= 1 then 
                curPitchIdx = #pitchs
            else
                curPitchIdx = curPitchIdx - 1
            end
            return pitchs[curPitchIdx]
        end
    -- 下到上波浪
    elseif mode == 3 then
        local inc = true
        return function ()
            if curPitchIdx <= 0 then 
                curPitchIdx = 1
            elseif curPitchIdx == #pitchs then
                curPitchIdx = curPitchIdx - 1
                inc = false
            elseif curPitchIdx == 1 then
                curPitchIdx = curPitchIdx + 1
                inc = true
            elseif inc then
                curPitchIdx = curPitchIdx + 1
            else
                curPitchIdx = curPitchIdx - 1
            end
            return pitchs[curPitchIdx]
        end
    -- 上到下波浪
    elseif mode == 4 then
        local inc = false
        return function ()
            if curPitchIdx <= 0 then 
                curPitchIdx = #pitchs
            elseif curPitchIdx == #pitchs then
                curPitchIdx = curPitchIdx - 1
                inc = false
            elseif curPitchIdx == 1 then
                curPitchIdx = curPitchIdx + 1
                inc = true
            elseif inc then
                curPitchIdx = curPitchIdx + 1
            else
                curPitchIdx = curPitchIdx - 1
            end
            return pitchs[curPitchIdx]
        end
    -- 随机
    elseif mode == 5 then
        return function ()
            return pitchs[math.random(1, #pitchs)]
        end
    end

end

local tasks = {}

function prepareGroup(group, length, mode)
    if #group == 0 then return end

    local take = group[1].take
    local startPos = group[1].startPos
    local endPos = group[1].endPos
    local pitchSampleNote = {}
    local pitchs = {}
    
    for _, note in ipairs(group) do
        endPos = math.max(endPos, note.endPos)
        pitchSampleNote[note.pitch] = note
    end

    for pitch, _ in pairs(pitchSampleNote) do
        table.insert(pitchs, pitch)
    end

    table.sort(pitchs)

    local curPos = startPos
    local nextPitch = getPitchIterator(pitchs, mode)

    -- 延迟执行，以便将选中音符全部删除后再执行插入
    table.insert(tasks, function ()
        while curPos < endPos do
            local newPitch = nextPitch()
            insertNote(take, {
                selected = true,
                muted = pitchSampleNote[newPitch].muted,
                startPos = curPos,
                endPos = math.min(curPos + length, endPos),
                channel = pitchSampleNote[newPitch].channel,
                pitch = newPitch,
                vel = pitchSampleNote[newPitch].vel
            })
            curPos = curPos + length
        end
    end)
end

function processAll()
    for _, task in ipairs(tasks) do
        task()
    end
end

math.randomseed(os.clock())

local args = prompt({
    title = "Random Note Arpeggio",
    inputs = {
        {
            label = "Enter A Tick",
            default = "240",
            converter = tonumber
        },
        {
            label = "Mode:1DU 2UD 3M 4W 5RD", -- 1:下到上 2:上到下 3:下到上波浪 4:上到下波浪 5:随机
            default = "1",
            converter = tonumber
        }
    },
    remember = {
        enable = true,
        section = "Random Note Arpeggio",
        key = "Parameters",
        persist = true
    }
})

if not args then return end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    reaper.MIDI_DisableSort(take)

    tasks = {}
    local noteGroups = {}

    for note in selNoteIterator(take) do
        noteGroups[note.startPos] = noteGroups[note.startPos] or {}
        table.insert(noteGroups[note.startPos], note)
    end

    for _, group in pairs(noteGroups) do
        prepareGroup(group, args[1], args[2])
    end

    deleteSelNote2(take)
    processAll()
    reaper.MIDI_Sort(take)
end
reaper.Undo_EndBlock("Random Note Arpeggio", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()