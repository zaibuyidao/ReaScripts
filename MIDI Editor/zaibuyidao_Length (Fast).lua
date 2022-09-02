-- @description Length (Fast)
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Optimized code
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repository https://github.com/zaibuyidao/ReaScripts
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
                        print(indent .. "[" .. tostring(pos) .. "] => " ..
                                  tostring(t) .. " {")
                        sub_print_r(val, indent ..
                                        string.rep(" ",
                                                   string.len(tostring(pos)) + 8))
                        print(indent ..
                                  string.rep(" ", string.len(tostring(pos)) + 6) ..
                                  "}")
                    elseif (type(val) == "string") then
                        print(
                            indent .. "[" .. tostring(pos) .. '] => "' .. val ..
                                '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " ..
                                  tostring(val))
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

function open_url(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
        os.execute("open ".. url)
    else
        os.execute("start ".. url)
    end
end

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

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
            event.msg = string.pack("BBB", event.msg:byte(1),
                                    value or event.msg:byte(2),
                                    event.msg:byte(3))
        end,
        velocity = function(event, value)
            event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2),
                                    value or event.msg:byte(3))
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

function getAllTakes()
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
        for i = 0, reaper.CountMediaItems(0) - 1 do
            local item = reaper.GetMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and
                reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) ==
                0 then -- Get potential takes that contain notes. NB == 0 
                tTake[take] = true
            end
        end
        for take in next, tTake do
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then
                tTake[take] = nil
            end
        end
    end
    if not next(tTake) then return end
    return tTake
end

-- 返回最末尾事件qn位置
function scaleEvents(take, all_events, note_events, events, qn_range, percent,
                     scale_start, scale_dur)
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
            all_events[#all_events].pos =
                reaper.MIDI_GetPPQPosFromProjQN(take, max_qn)
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
            note_event.left.pos = calc_pos(note_event.left.pos)
            note_event.right.pos = calc_pos(note_event.right.pos)
            if note_event.articulation then
                note_event.articulation.pos = note_event.left.pos
            end
        elseif scale_start then
            note_event.left.pos = calc_pos(note_event.left.pos)
            note_event.right.pos = note_event.left.pos + note_len
            if note_event.articulation then
                note_event.articulation.pos = note_event.left.pos
            end
        elseif scale_dur then
            note_event.right.pos = note_event.left.pos + (percent * note_len)
        end
        update_max_qn(note_event.right.pos)
    end

    return process_item_extend()
end

local percent = reaper.GetExtState("Length", "Percent")
if (percent == "") then percent = "200" end
local toggle = reaper.GetExtState("Length", "Toggle")
if (toggle == "") then toggle = "0" end

local uok, uinput = reaper.GetUserInputs('Length', 2, 'Percent,0=Start+Dur 1=Start 2=Durations', percent .. ',' .. toggle)
if not uok or not tonumber(percent) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
percent, toggle = uinput:match("(%d*),(%d*)")

reaper.SetExtState("Length", "Percent", percent, false)
reaper.SetExtState("Length", "Toggle", toggle, false)

percent = tonumber(percent) / 100

local note_events = {} -- { take: {left: event, right: event}[] }
local other_events = {} -- { take: event[] }
local all_events = {} -- { take: event[] }
local global_selected_qn_range = {math.huge, -math.huge} -- { number, number }
local has_selected = false

for take, _ in pairs(getAllTakes()) do
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
                    reaper.ShowMessageBox("檢測到重叠音符，解析失敗", "ERROR", 0)
                    return
                end
                last_note_event_at_pitch[event.pitch] = event
            elseif event.type == EVENT_NOTE_END then
                if not last_note_event_at_pitch[event.pitch] then
                    reaper.ShowMessageBox("找不到開始事件，解析失敗", "ERROR", 0)
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

if toggle == "0" then
    for take, events in pairs(other_events) do
        scaleEvents(take, all_events[take], nil, events, global_selected_qn_range, percent)
    end
    for take, _note_events in pairs(note_events) do
        scaleEvents(take, all_events[take], _note_events, nil, global_selected_qn_range, percent, true, true)
    end
elseif toggle == "1" then
    for take, events in pairs(other_events) do
        scaleEvents(take, all_events[take], nil, events, global_selected_qn_range, percent)
    end
    for take, _note_events in pairs(note_events) do
        scaleEvents(take, all_events[take], _note_events, nil, global_selected_qn_range, percent, true, false)
    end
elseif toggle == "2" then
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

reaper.Undo_EndBlock("Length (Fast)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
