-- @description Random Note Position Swap
-- @version 1.0
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

-- 区间随机放置算法
-- 1.将所有 sn 收缩为零长度
-- 2.为 lenG-lenS 中的每个 sn 选择随机位置
-- 3.将 sn 扩展回原来的长度
function randomReplacement(interval, subIntervals)
    local intervalLength = interval.r - interval.l
    local emptyPlaceAvailable = intervalLength
    for _, subInterval in ipairs(subIntervals) do
        emptyPlaceAvailable = emptyPlaceAvailable - (subInterval.r - subInterval.l)
    end
    local positions = {}
    for _=1, #subIntervals do
        table.insert(positions, math.random(0, emptyPlaceAvailable))
    end
    -- 打乱
    for i = #subIntervals, 2, -1 do
		local j = math.random(i)
		subIntervals[i], subIntervals[j] = subIntervals[j], subIntervals[i]
	end
    local start = interval.l
    for i=1, #positions do
        local len = subIntervals[i].r - subIntervals[i].l
        subIntervals[i].l = positions[i] + start
        subIntervals[i].r = subIntervals[i].l + len
        start = start + len
    end
end

-- 随机放置法
function main_randomReplacement()
    for take, _ in pairs(getAllTakes()) do
        local newNotes = {}
        local interval = { l = math.huge, r = -math.huge }
        local noteGroups = {}
        for note in selNoteIterator(take) do
            interval.l = math.min(interval.l, note.startPos)
            interval.r = math.max(interval.r, note.endPos)
    
            noteGroups[note.pitch] = noteGroups[note.pitch] or {}
            table.insert(noteGroups[note.pitch], note)
        end
    
        for _, group in pairs(noteGroups) do
            local subIntervals = {}
            for _, note in ipairs(group) do
                table.insert(subIntervals, {
                    l = note.startPos,
                    r = note.endPos,
                    note = note
                })
            end
            randomReplacement(interval, subIntervals)
            for _, subInterval in ipairs(subIntervals) do
                subInterval.note.startPos = subInterval.l
                subInterval.note.endPos = subInterval.r
                table.insert(newNotes, subInterval.note)
            end
        end
    
        deleteSelNote()
    
        for _, note in ipairs(newNotes) do
            insertNote(take, note)
        end
    end
end

-- 交换法，仅适用于选中音符长度均相同情况
function main_exchange()
    for take, _ in pairs(getAllTakes()) do
        local newNotes = {}
        local positions = {}
        local noteGroups = {}
        for note in selNoteIterator(take) do
            table.insert(positions, note.startPos)
            noteGroups[note.pitch] = noteGroups[note.pitch] or {}
            table.insert(noteGroups[note.pitch], note)
        end
        
        for i = #positions, 2, -1 do
            local j = math.random(i)
            positions[i], positions[j] = positions[j], positions[i]
        end

        local curPosIdx = 1

        for _, group in pairs(noteGroups) do
            for _, note in ipairs(group) do
                local len = note.endPos - note.startPos
                note.startPos = positions[curPosIdx]
                note.endPos = note.startPos + len
                table.insert(newNotes, note)
                curPosIdx = curPosIdx + 1
            end
        end
    
        deleteSelNote2(take)
    
        for _, note in ipairs(newNotes) do
            insertNote(take, note)
        end
    end
end

math.randomseed(os.clock())
reaper.Undo_BeginBlock()
main_exchange()
reaper.Undo_EndBlock("Random Note Position Swap", -1)
reaper.UpdateArrange()