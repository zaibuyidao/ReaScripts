-- @description Random Note Position Swap
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Random Note Script Series, filter "zaibuyidao random note" in ReaPack or Actions to access all scripts.

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()
local getTakes = getAllTakes()
  
if language == "简体中文" then
    title = "随机交换音符位置"
elseif language == "繁体中文" then
    title = "隨機交換音符位置"
else
    title = "Random Note Position Swap"
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
    for take, _ in pairs(getTakes) do
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
