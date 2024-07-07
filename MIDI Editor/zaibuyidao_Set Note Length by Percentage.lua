-- @description Set Note Length by Percentage
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

local floor = math.floor
function math.floor(x) return floor(x + 0.0000005) end

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ALL_NOTES_OFF = 11
EVENT_ARTICULATION = 15

function setAllEvents(take, events)
    local lastPos = 0
    for _, event in pairs(events) do
        event.offset = event.pos - lastPos
        lastPos = event.pos
    end
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab))
end

function getAllEvents(take, onEach)
    local getters = {
        selected = function(event) return event.flags & 1 == 1 end,
        pitch = function(event) return event.msg:byte(2) end,
        velocity = function(event) return event.msg:byte(3) end,
        type = function(event) return event.msg:byte(1) >> 4 end,
        articulation = function(event) return event.msg:byte(1) >> 4 end
    }
    local setters = {
        pitch = function(event, value)
            event.msg = string.pack("BBB", event.msg:byte(1), value or event.msg:byte(2), event.msg:byte(3))
        end,
        velocity = function(event, value)
            event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2), value or event.msg:byte(3))
        end,
        selected = function(event, value)
            if value then
                event.flags = event.flags | 1
            else
                event.flags = event.flags & 0xFFFFFFFE
            end
        end
    }
    local eventMetaTable = {
        __index = function(event, key) return getters[key](event) end,
        __newindex = function(event, key, value)
            return setters[key](event, value)
        end
    }

    local events = {}
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local stringPos = 1
    local lastPos = 0
    while stringPos <= MIDIstring:len() do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        local event = setmetatable({
            offset = offset,
            pos = lastPos + offset,
            flags = flags,
            msg = msg
        }, eventMetaTable)
        table.insert(events, event)
        onEach(event)
        lastPos = lastPos + offset
    end
    return events
end

-- 返回最末尾事件qn位置
function scaleEvents(take, all_events, note_events, events, qn_range, percent, scale_start, scale_dur)
    local max_qn = -math.huge

    local function calc_pos(pos)
        local qn_range_len = qn_range[2] - qn_range[1]
        local event_pos_qn = reaper.MIDI_GetProjQNFromPPQPos(take, pos)
        local p = (event_pos_qn - qn_range[1]) / qn_range_len -- 在qn_range中的位置，范围0-1
        local result_qn = qn_range[1] + p * (percent * qn_range_len)
        return reaper.MIDI_GetPPQPosFromProjQN(take, result_qn)
    end

    local function update_max_qn(ppqpos)
        max_qn = math.max(max_qn, reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos))
    end

    local function process_item_extend()
        local item = reaper.GetMediaItemTake_Item(take)
        local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- + reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
        local qn_item_pos = reaper.TimeMap2_timeToQN(0, item_pos)
        local qn_item_len = reaper.TimeMap2_timeToQN(0, item_len)
        local qn_item_end = qn_item_pos + qn_item_len
        if max_qn > qn_item_end then
            reaper.MIDI_SetItemExtents(item, qn_item_pos, max_qn)
            all_events[#all_events].pos = reaper.MIDI_GetPPQPosFromProjQN(take, max_qn)
        end
    end

    if events then
        for _, event in ipairs(events) do
            event.pos = calc_pos(event.pos)
            update_max_qn(event.pos)
        end
        return process_item_extend()
    end

    for _, note_event in ipairs(note_events) do
        local note_len = note_event.right.pos - note_event.left.pos
        if scale_start and scale_dur then
            note_event.left.pos = math.floor(calc_pos(note_event.left.pos))
            note_event.right.pos = math.floor(calc_pos(note_event.right.pos))
            if note_event.articulation then
                note_event.articulation.pos = note_event.left.pos
            end
        elseif scale_start then
            note_event.left.pos = math.floor(calc_pos(note_event.left.pos))
            note_event.right.pos = math.floor(note_event.left.pos + note_len)
            if note_event.articulation then
                note_event.articulation.pos = note_event.left.pos
            end
        elseif scale_dur then
            note_event.right.pos = math.floor(note_event.left.pos + (percent * note_len))
        end
        update_max_qn(note_event.right.pos)
    end

    return process_item_extend()
end

if language == "简体中文" then
    title = "设置音符长度"
    lable = "输入百分比(%):,1=起始+持续 2=起始 3=持续"
elseif language == "繁體中文" then
    title = "設置音符長度"
    lable = "輸入百分比(%):,1=起始+持續 2=起始 3=持續"
else
    title = "Set Note Length"
    lable = "Enter percentage:,1=Start+Dur 2=Start 3=Durations"
end

local percent = reaper.GetExtState("SET_NOTE_LENGTH_PERCENT", "Percent")
if (percent == "") then percent = "200" end
local toggle = reaper.GetExtState("SET_NOTE_LENGTH_PERCENT", "Toggle")
if (toggle == "") then toggle = "1" end

local retval, retvals_csv = reaper.GetUserInputs(title, 2, lable, percent .. ',' .. toggle)
if not retval or not tonumber(percent) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
percent, toggle = retvals_csv:match("(%d*),(%d*)")
if tonumber(toggle) < 1 and tonumber(toggle) > 3 then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("SET_NOTE_LENGTH_PERCENT", "Percent", percent, false)
reaper.SetExtState("SET_NOTE_LENGTH_PERCENT", "Toggle", toggle, false)

percent = tonumber(percent) / 100

local note_events = {} -- { take: {left: event, right: event}[] }
local other_events = {} -- { take: event[] }
local all_events = {} -- { take: event[] }
local global_selected_qn_range = {math.huge, -math.huge} -- { number, number }
local has_selected = false

for take, _ in pairs(getTakes) do
    local last_note_event_at_pitch = {}
    local last_articulation_event_at_pitch = {}
    all_events[take] = getAllEvents(take, function(event)
        if event.type == EVENT_ARTICULATION then
            if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
                -- table.insert(textEvents, event)
                if not other_events[take] then
                    other_events[take] = {}
                end
                table.insert(other_events[take], event)
            else
                local chan, pitch = event.msg:match("NOTE (%d+) (%d+) ")
                -- print(event.pitch, event.msg)
                if chan and pitch then
                  last_articulation_event_at_pitch[tonumber(pitch)] = event
                end
            end
        end

        if event.selected then
            global_selected_qn_range[1] =
                math.min(global_selected_qn_range[1], reaper.MIDI_GetProjQNFromPPQPos(take, event.pos))
            global_selected_qn_range[2] =
                math.max(global_selected_qn_range[2], reaper.MIDI_GetProjQNFromPPQPos(take, event.pos))
            if event.type == EVENT_NOTE_START then
                if last_note_event_at_pitch[event.pitch] then
                    reaper.ShowMessageBox("Overlapping notes detected, parsing failed", "Error", 0)
                    return
                end
                last_note_event_at_pitch[event.pitch] = event
            elseif event.type == EVENT_NOTE_END then
                if not last_note_event_at_pitch[event.pitch] then
                    reaper.ShowMessageBox("Start event not found, parsing failed", "Error", 0)
                    return
                end
                if not note_events[take] then
                    note_events[take] = {}
                end
                table.insert(note_events[take], {
                    left = last_note_event_at_pitch[event.pitch],
                    right = event,
                    articulation = last_articulation_event_at_pitch[event.pitch]
                })
                last_note_event_at_pitch[event.pitch] = nil
                last_articulation_event_at_pitch[event.pitch] = nil
            else
                if not other_events[take] then
                    other_events[take] = {}
                end
                table.insert(other_events[take], event)
            end
            has_selected = true
        end
    end)
end

if not has_selected then return reaper.SN_FocusMIDIEditor() end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if toggle == "1" then
    for take, events in pairs(other_events) do
        scaleEvents(take, all_events[take], nil, events, global_selected_qn_range, percent)
    end
    for take, _note_events in pairs(note_events) do
        scaleEvents(take, all_events[take], _note_events, nil, global_selected_qn_range, percent, true, true)
    end
elseif toggle == "2" then
    for take, events in pairs(other_events) do
        scaleEvents(take, all_events[take], nil, events, global_selected_qn_range, percent)
    end
    for take, _note_events in pairs(note_events) do
        scaleEvents(take, all_events[take], _note_events, nil, global_selected_qn_range, percent, true, false)
    end
elseif toggle == "3" then
    for take, events in pairs(other_events) do
        scaleEvents(take, all_events[take], nil, events, global_selected_qn_range, percent)
    end
    for take, _note_events in pairs(note_events) do
        scaleEvents(take, all_events[take], _note_events, nil, global_selected_qn_range, percent, false, true)
    end
end

for take, events in pairs(all_events) do
    setAllEvents(take, events)
    reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()