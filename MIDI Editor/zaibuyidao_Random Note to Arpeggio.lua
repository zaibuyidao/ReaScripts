-- @description Random Note to Arpeggio
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Random Notes Script Series, filter "zaibuyidao random note" in ReaPack or Actions to access all scripts.

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

    local res = string.split(resCsv, ",")
    for i=1, #res do
        res[i] = converters[i](res[i])
    end

    if remember.enable and (not remember.preValidation or remember.preValidation(res)) then
        reaper.SetExtState(remember.section, remember.key, resCsv, remember.persist)
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

--math.randomseed(os.clock())

function argsCheck(args)
    return args[1] > 0 and args[2] >= 1 and args[2] <= 5
end

if language == "简体中文" then
    title_param = "将音符随机为琶音"
    inputs_param = {
        {
            label = "输入滴答数:",
            default = "240",
            converter = tonumber
        },
        {
            label = "1=DU 2=UD 3=M 4=W 5=RD", -- 1:下到上 2:上到下 3:下到上波浪 4:上到下波浪 5:随机
            default = "5",
            converter = tonumber
        }
    }
elseif language == "繁體中文" then
    title_param = "將音符隨機為琶音"
    inputs_param = {
        {
            label = "輸入滴答數:",
            default = "240",
            converter = tonumber
        },
        {
            label = "1=DU 2=UD 3=M 4=W 5=RD", -- 1:下到上 2:上到下 3:下到上波浪 4:上到下波浪 5:随机
            default = "5",
            converter = tonumber
        }
    }
else
    title_param = "Random Note to Arpeggio"
    inputs_param = {
        {
            label = "Enter A Tick:",
            default = "240",
            converter = tonumber
        },
        {
            label = "1=DU 2=UD 3=M 4=W 5=RD", -- 1:下到上 2:上到下 3:下到上波浪 4:上到下波浪 5:随机
            default = "5",
            converter = tonumber
        }
    }
end

local args = prompt({
    title = title_param,
    inputs = inputs_param,
    remember = {
        enable = true,
        section = "RandomNotetoArpeggio",
        key = "Parameters",
        persist = true,
        preValidation = argsCheck
    }
})

if not args or not argsCheck(args) then return end

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
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
reaper.Undo_EndBlock(title_param, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()