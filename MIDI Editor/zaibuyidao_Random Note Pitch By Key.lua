-- @description Random Note Pitch By Key
-- @version 1.0.2
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

local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))

function check_locale(locale)
  if locale == 936 then
    return true
  elseif locale == 950 then
    return true
  end
  return false
end

os = reaper.GetOS()
if os ~= "Win32" and os ~= "Win64" then
    title_param = "Random Note Pitch By Key"
    inputs_param  = {
        {
            label = "Min Pitch",
            default = "60",
            converter = tonumber
        },
        {
            label = "Max Pitch",
            default = "72",
            converter = tonumber
        },
        {
            label = "Key",
            default = "C"
        }
    }
else
    if check_locale(locale) == false then
        title_param = "Random Note Pitch By Key"
        inputs_param  = {
            {
                label = "Min Pitch",
                default = "60",
                converter = tonumber
            },
            {
                label = "Max Pitch",
                default = "72",
                converter = tonumber
            },
            {
                label = "Key",
                default = "C"
            }
        }
    else
        title_param = "按調隨機音符音高"
        inputs_param  = {
            {
                label = "最小值",
                default = "60",
                converter = tonumber
            },
            {
                label = "最大值",
                default = "72",
                converter = tonumber
            },
            {
                label = "調",
                default = "C"
            }
        }
    end
end

local args = prompt({
    title = title_param,
    inputs = inputs_param,
    remember = {
        enable = true,
        section = "Random Note Pitch By Key",
        key = "Parameters",
        persist = true,
        preValidation = argsCheck
    }
})

-- local args = prompt({
--     title = "Random Note Pitch By Key",
--     inputs = {
--         {
--             label = "Min Pitch",
--             default = "60",
--             converter = tonumber
--         },
--         {
--             label = "Max Pitch",
--             default = "72",
--             converter = tonumber
--         },
--         {
--             label = "Key",
--             default = "C"
--         }
--     },
--     remember = {
--         enable = true,
--         section = "Random Note Pitch By Key",
--         key = "Parameters",
--         persist = true,
--         preValidation = argsCheck
--     }
-- })

if not args or not argsCheck(args) then return end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
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
reaper.Undo_EndBlock("Random Note Pitch By Key", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()