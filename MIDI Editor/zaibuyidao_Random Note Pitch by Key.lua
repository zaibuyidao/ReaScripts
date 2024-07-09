-- @description Random Note Pitch by Key
-- @version 1.0
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

function generatePitchs(range, tonalityTab, offset)
    local round = 0
    local idx = 1
    local pitch = round * 12 + tonalityTab[idx] + offset
    local res = {}
    while pitch <= range.max do
        if pitch >= range.min then
            table.insert(res, pitch)
        end
        
        idx = idx + 1
        if idx > #tonalityTab then
            round = round + 1
            idx = 1
        end
        pitch = round * 12 + tonalityTab[idx] + offset
    end
    return res
end

-- 大调
local major = {
    0, 2, 4, 5, 7, 9, 11
}

-- 小调
local minor = {
    0, 2, 3, 5, 7, 8, 10
}

local tonesMap = { --音调对应的数字
    ["c"]=0, ["c#"]=1, ["d"]=2, ["d#"]=3, ["e"]=4, ["f"]=5, ["f#"]=6, ["g"]=7, ["g#"]=8, ["a"]=9, ["a#"]=10, ["b"]=11
}

math.randomseed(os.clock())

function argsCheck(args)
    local function isLegalPitch(pitch)
        return pitch >= 0 and pitch <= 127
    end
    return isLegalPitch(args[1]) and isLegalPitch(args[2]) and args[1] <= args[2] and tonesMap[args[3]:lower()]
end

if language == "简体中文" then
    title_param = "按调随机音符音高"
    inputs_param  = {
        {
            label = "最小音高:",
            default = "60",
            converter = tonumber
        },
        {
            label = "最大音高:",
            default = "72",
            converter = tonumber
        },
        {
            label = "调号:",
            default = "C"
        }
    }
elseif language == "繁體中文" then
    title_param = "按調隨機音符音高"
    inputs_param  = {
        {
            label = "最小音高:",
            default = "60",
            converter = tonumber
        },
        {
            label = "最大音高:",
            default = "72",
            converter = tonumber
        },
        {
            label = "調號:",
            default = "C"
        }
    }
else
    title_param = "Random Note Pitch by Key"
    inputs_param  = {
        {
            label = "Pitch Min:",
            default = "60",
            converter = tonumber
        },
        {
            label = "Pitch Max:",
            default = "72",
            converter = tonumber
        },
        {
            label = "Key Signature:",
            default = "C"
        }
    }
end

local args = prompt({
    title = title_param,
    inputs = inputs_param,
    remember = {
        enable = true,
        section = "RandomNotePitchbyKey",
        key = "Parameters",
        persist = true,
        preValidation = argsCheck
    }
})

if not args or not argsCheck(args) then return end

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
    local newNotes = {}
    local scale = major
    if args[3]:find("[a-z]") then
        scale = minor
    end
    local pitchs = generatePitchs({ min = args[1], max = args[2] }, scale, tonesMap[args[3]:lower()])
    -- table.print(pitchs)
    for note in selNoteIterator(take) do
        note.pitch = pitchs[math.random(1, #pitchs)]
        table.insert(newNotes, note)
    end

    deleteSelNote2(take)

    for _, note in ipairs(newNotes) do
        insertNote(take, note)
    end
end

reaper.Undo_EndBlock(title_param, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()