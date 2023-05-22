-- @description Duplicate Musical (Fast)
-- @version 1.0.7
-- @author zaibuyidao
-- @changelog Add support for triplet events.
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

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
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
    jserr = "错误"
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    jserr = "錯誤"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    jserr = "Error"
end

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

if not reaper.APIExists("JS_Localize") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
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

function insertEvents(originEvents, toInsertEvents, startPos, lastCC)
    if (#toInsertEvents == 0) then return end
    local lastEvent = originEvents[#originEvents]
    table.remove(originEvents, #originEvents)
    local startOfToCopy = toInsertEvents[1].pos
    for _, toInsertEvent in ipairs(toInsertEvents) do
        toInsertEvent.pos = startPos + (toInsertEvent.pos - startOfToCopy)
        -- 如果最后一个CC的位置和将要被复制后CC位置一样，那么对原CC进行覆盖，而不是插入新的CC
        if (lastCC and isCCEvent(toInsertEvent) and toInsertEvent.pos == lastCC.pos) then
            lastCC.msg = toInsertEvent.msg
            lastCC.flags = toInsertEvent.flags
            goto continue
        end
        table.insert(originEvents, toInsertEvent)
        ::continue::
    end
    table.insert(originEvents, lastEvent)
end

function isCCEvent(event)   -- 判断是否为CC事件
    return event.type == 11 and event.msg:byte(2) >= 0 and event.msg:byte(2) <= 127
end

function dup(take, copy_start_qn_from_head, global_range_qn)
    if not take or not reaper.TakeIsMIDI(take) then return end
    local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

    local toCopyEvents = {}

    local range = {head = math.huge, tail = -math.huge}

    local lastEventSelected = false

    local lastCC -- 最后一个位置的CC事件

    local events = getAllEvents(take, function(event)
        local selected = event.selected
        if event.selected or (lastEventSelected and (event.msg:find("CCBZ") or event.msg:find("articulation"))) then -- 重复贝塞尔曲线与符号
            local pos = event.pos
            if (isCCEvent(event) and (not lastCC or event.pos > lastCC.pos)) then
                lastCC = event
            end
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
    insertEvents(events, toCopyEvents, math.floor((global_range_qn.head + copy_start_qn_from_head + offset_from_global_head - event_start_pos_qn) * tick), lastCC)

    -- print(global_range_qn.head, copy_start_qn_from_head, offset_from_global_head, event_start_pos_qn)
    -- print((global_range_qn.head + copy_start_qn_from_head + offset_from_global_head - event_start_pos_qn))
    -- print((global_range_qn.head + copy_start_qn_from_head + offset_from_global_head - event_start_pos_qn) * tick, math.floor((global_range_qn.head + copy_start_qn_from_head + offset_from_global_head - event_start_pos_qn) * tick))
    setAllEvents(take, events)
end


local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local global_range = {head = math.huge, tail = -math.huge}
local has_selected = false
for take, _ in pairs(getAllTakes()) do
    getAllEvents(take, function(event)
        if event.selected then
            local item = reaper.GetMediaItemTake_Item(take)
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_pos_qn = reaper.TimeMap2_timeToQN(0, item_pos)
            local item_pos_ppq = tick * item_pos_qn
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

local range_time = {
    head = reaper.MIDI_GetProjTimeFromPPQPos(take, global_range.head- active_item_event_start_pos_ppq),
    tail = reaper.MIDI_GetProjTimeFromPPQPos(take, global_range.tail- active_item_event_start_pos_ppq)
}
range_time.len = range_time.tail - range_time.head

-- print("qn range")
-- table.print(range_qn)

local range_qn_measure = {}
local _, left, right = reaper.TimeMap_QNToMeasures(0, range_qn.head)
range_qn_measure.head  = {left = left, right = right, len = right - left}
local _, left, right = reaper.TimeMap_QNToMeasures(0, range_qn.tail)
range_qn_measure.tail  = {left = left, right = right, len = right - left}

-- print("range_qn_measure")
-- table.print(range_qn_measure)

-- 复制长度
local copy_start_qn_from_head

local _, _, head_cml, _, head_cdenom = reaper.TimeMap2_timeToBeats(0, range_time.head)
local range_beats = (range_qn.len / range_qn_measure.head.len) * head_cml
local qn_per_beat = 4 / head_cdenom

if range_qn.len > range_qn_measure.head.len then -- 选择范围超过了一节(节的长度以左端点所在拍号为准)
    copy_start_qn_from_head = math.ceil(range_qn.len / range_qn_measure.head.len - 0.00001) * range_qn_measure.head.len
elseif head_cdenom == 4 then
    if head_cml == 3 then   -- 3/4 拍
        if range_beats > 1 then
            copy_start_qn_from_head = qn_per_beat * 3
        end
    elseif head_cml == 4 or head_cml == 2 then-- 4/4 2/4 拍
        if range_beats > 2 then
            copy_start_qn_from_head = qn_per_beat * 4
        end
    elseif head_cml == 6 then -- 6/4 拍
        if range_beats > 3 then
            copy_start_qn_from_head = qn_per_beat * 6
        elseif range_beats > 1 then
            copy_start_qn_from_head = qn_per_beat * 3
        end
    end
elseif head_cdenom == 8 then
    if head_cml == 3 then -- 3/8 拍
        if range_beats > 1 then
            copy_start_qn_from_head = qn_per_beat * 3
        end
    elseif head_cml == 4 then -- 4/8 拍
        if range_beats > 2 then
            copy_start_qn_from_head = qn_per_beat * 4
        end
    elseif head_cml == 6 then -- 6/8 拍
        if range_beats > 3 then
            copy_start_qn_from_head = qn_per_beat * 6
        elseif range_beats > 1 then
            copy_start_qn_from_head = qn_per_beat * 3
        end
    end
end

local ret_grid, swing, _ = reaper.MIDI_GetGrid(take)

if not copy_start_qn_from_head then
    local cur_beat = head_cml
    while true do
        if range_beats <= cur_beat + 0.0000001 then
            copy_start_qn_from_head = cur_beat * qn_per_beat
        else 
            break
        end
        if cur_beat > 1 then
            cur_beat = cur_beat - 1
        elseif reaper.GetToggleCommandStateEx(32060, 41004) == 1 then -- Grid: Set grid type to triplet
            cur_beat = cur_beat / 3
        else
            cur_beat = cur_beat / 2
        end
    end
end

-- print("copy_start_qn_from_head", copy_start_qn_from_head)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    -- local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    -- local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    -- print(sourceLengthTicks)

    -- reaper.MIDI_DisableSort(take)
    dup(take, copy_start_qn_from_head, range_qn)
    reaper.MIDI_Sort(take)
    -- print(reaper.BR_GetMidiSourceLenPPQ(take))
    -- if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    --     reaper.MIDI_SetAllEvts(take, MIDIstring)
    --     reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
    -- end
end
reaper.Undo_EndBlock("", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(function() end)