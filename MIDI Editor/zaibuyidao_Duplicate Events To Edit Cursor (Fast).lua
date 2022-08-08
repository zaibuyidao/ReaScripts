--[[
 * ReaScript Name: Duplicate Events To Edit Cursor (Fast)
 * Version: 1.0.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
 * About: Requires SWS Extensions
--]]

--[[
 * Changelog:
 * v1.0.3 (2022-8-22)
  + Fix the problem that the Bezier curve cannot be duplicate
 * v1.0 (2022-5-20)
  + Initial release
--]]

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

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
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
function math.floor(x)
    return floor(x + 0.0000005)
end

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
        selected = function (event) return event.flags & 1 == 1 end,
        pitch = function (event) return event.msg:byte(2) end,
        velocity = function (event) return event.msg:byte(3) end,
        type = function (event) return event.msg:byte(1) >> 4 end,
        articulation = function (event) return event.msg:byte(1) >> 4 end
    }
    local setters = {
        pitch = function (event, value)
            event.msg = string.pack("BBB", event.msg:byte(1), value or event.msg:byte(2), event.msg:byte(3))
        end,
        velocity = function (event, value)
            event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2), value or event.msg:byte(3))
        end,
        selected = function (event, value)
            if value then
                event.flags = event.flags | 1
            else
                event.flags = event.flags & 0xFFFFFFFE
            end
        end
    }
    local eventMetaTable = {
        __index = function (event, key) return getters[key](event) end,
        __newindex = function (event, key, value) return setters[key](event, value) end
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

function insertEvents(originEvents, toInsertEvents, startPos)
    if (#toInsertEvents == 0) then return end
    local lastEvent = originEvents[#originEvents]
    table.remove(originEvents, #originEvents) -- 排除 All-Note-Off 事件
    local startOfToCopy = toInsertEvents[1].pos
    for _, toInsertEvent in ipairs(toInsertEvents) do
        toInsertEvent.pos = startPos + (toInsertEvent.pos - startOfToCopy)
        table.insert(originEvents, toInsertEvent)
    end
    table.insert(originEvents, lastEvent) -- 排除 All-Note-Off 事件
end

function dup(take, copy_start_qn_from_head, global_range_qn)
    if not take or not reaper.TakeIsMIDI(take) then return end
    local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

    local toCopyEvents = {}

    local range = {head = math.huge, tail = -math.huge}

    local lastEventSelected = false

    local events = getAllEvents(take, function(event)
        local selected = event.selected
        if event.selected or (lastEventSelected and event.msg:find("CCBZ")) then -- 重复贝塞尔曲线
            local pos = event.pos
            range.head = math.min(range.head, pos)
            range.tail = math.max(range.tail, pos)
            table.insert(toCopyEvents, clone(event))
            event.selected = false
        end
        lastEventSelected = selected
    end)
    local range_qn = {
        head = reaper.MIDI_GetProjQNFromPPQPos(take, range.head),
        tail = reaper.MIDI_GetProjQNFromPPQPos(take, range.tail)
    }
    range_qn.len = range_qn.tail - range_qn.head

    if #toCopyEvents == 0 then return end

    -- item 扩展处理
    local item = reaper.GetMediaItemTake_Item(take)
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- + reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    local qn_item_pos = reaper.TimeMap2_timeToQN(0, item_pos)
    local qn_item_len = reaper.TimeMap2_timeToQN(0, item_len)
    local qn_item_end = qn_item_pos + qn_item_len
    local event_start_pos_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)

    -- 复制后音符的结尾位置
    -- local result_tail_qn = global_range_qn.head + copy_start_qn_from_head + (global_range_qn.tail - global_range_qn.head)
    -- local result_tail_qn = global_range_qn.head + copy_start_qn_from_head + copy_start_qn_from_head

    local result_tail_qn = range_qn.head + copy_start_qn_from_head + (range_qn.tail - range_qn.head)

    if result_tail_qn > qn_item_len + qn_item_pos then
        reaper.MIDI_SetItemExtents(item, qn_item_pos, result_tail_qn)
        events[#events].pos = reaper.MIDI_GetPPQPosFromProjQN(take, result_tail_qn)
    end

    -- print(qn_item_pos)
    local offset_from_global_head = range_qn.head - global_range_qn.head 

    -- 当前item第一个事件的插入位置 = 全部take选中区域的开始qn位置 + 复制长度 + 当前item第一个事件与全部take选中区域开头的距离 - 当前item事件开始qn位置
    insertEvents(events, toCopyEvents, math.floor((global_range_qn.head + copy_start_qn_from_head + offset_from_global_head - event_start_pos_qn) * tick))
    setAllEvents(take, events)
end

local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local global_range = {head = math.huge, tail = -math.huge}
local has_selected = false
for take, _ in pairs(getAllTakes()) do
    getAllEvents(take, function(event)
        if event.selected then
            -- local item = reaper.GetMediaItemTake_Item(take)
            -- local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            -- local item_pos_qn = reaper.TimeMap2_timeToQN(0, item_pos)
            -- local item_pos_ppq = tick * item_pos_qn
            local event_start_pos_ppq = tick * reaper.MIDI_GetProjQNFromPPQPos(take, 0)

            local pos = event.pos
            global_range.head = math.min(global_range.head, pos + event_start_pos_ppq)
            global_range.tail = math.max(global_range.tail, pos + event_start_pos_ppq)
            has_selected = true
        end
    end)
end
if not has_selected then return end

-- print("ppq range")
-- table.print(global_range)

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local active_item = reaper.GetMediaItemTake_Item(take)
local active_item_pos = reaper.GetMediaItemInfo_Value(active_item, "D_POSITION") -- + reaper.GetMediaItemInfo_Value(active_item, "D_SNAPOFFSET")
local active_item_pos_qn = reaper.TimeMap2_timeToQN(0, active_item_pos)
local active_item_pos_ppq = tick * active_item_pos_qn
local active_item_event_start_pos_ppq = tick * reaper.MIDI_GetProjQNFromPPQPos(take, 0)

local range_qn = {
    head = reaper.MIDI_GetProjQNFromPPQPos(take, global_range.head - active_item_event_start_pos_ppq),
    tail = reaper.MIDI_GetProjQNFromPPQPos(take, global_range.tail - active_item_event_start_pos_ppq)
}
range_qn.len = range_qn.tail - range_qn.head

-- 复制长度
local copy_start_qn_from_head
local curpos = reaper.TimeMap2_timeToQN(0, reaper.GetCursorPositionEx(0))
copy_start_qn_from_head = curpos - range_qn.head

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    -- local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    -- print(sourceLengthTicks)
    dup(take, copy_start_qn_from_head, range_qn)
    reaper.MIDI_Sort(take)
    -- print(reaper.BR_GetMidiSourceLenPPQ(take))
    -- if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    --     reaper.MIDI_SetAllEvts(take, MIDIstring)
    --     reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
    -- end
end

reaper.Undo_EndBlock("Duplicate Events To Edit Cursor (Fast)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()