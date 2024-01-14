-- @description Random Note Position Swap
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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
  
if language == "简体中文" then
    title = "随机音符位置交换"
elseif language == "繁体中文" then
    title = "隨機音符位置交換"
else
    title = "Random Note Position Swap"
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

function main_exchange()
    for take, _ in pairs(getAllTakes()) do
        local newNotes = {}
        local positions = {}
        local noteGroups = {}
        local posTaken = {} -- 用于记录每个音高的音符占据的位置范围

        for note in selNoteIterator(take) do
            table.insert(positions, {startPos = note.startPos, endPos = note.endPos})
            noteGroups[note.pitch] = noteGroups[note.pitch] or {}
            table.insert(noteGroups[note.pitch], note)
        end

        -- 随机交换位置
        for i = #positions, 2, -1 do
            local j = math.random(i)
            positions[i], positions[j] = positions[j], positions[i]
        end

        for pitch, group in pairs(noteGroups) do
            posTaken[pitch] = posTaken[pitch] or {}

            for _, note in ipairs(group) do
                local noteLength = note.endPos - note.startPos
                local isPosAvailable, newPos, idx = false, nil, 1

                while not isPosAvailable and idx <= #positions do
                    newPos = positions[idx].startPos
                    isPosAvailable = true
                    for _, existingPos in pairs(posTaken[pitch]) do
                        if not (newPos + noteLength <= existingPos.startPos or newPos >= existingPos.endPos) then
                            isPosAvailable = false
                            break
                        end
                    end
                    if not isPosAvailable then idx = idx + 1 end
                end

                if isPosAvailable then
                    note.startPos = newPos
                    note.endPos = newPos + noteLength
                    table.insert(newNotes, note)
                    posTaken[pitch][newPos] = {startPos = newPos, endPos = note.endPos}
                    table.remove(positions, idx)
                end
            end
        end

        -- 更新MIDI条目
        if #newNotes > 0 then
            deleteSelNote2(take)
            for _, note in ipairs(newNotes) do
                insertNote(take, note)
            end
        end
    end
end

math.randomseed(os.clock())
reaper.Undo_BeginBlock()
main_exchange()
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
