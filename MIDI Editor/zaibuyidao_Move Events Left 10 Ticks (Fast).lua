--[[
 * ReaScript Name: Move Events Left 10 Ticks (Fast)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-5-29)
  + Initial release
--]]

local ticks = -10

function print(param)
  if type(param) == "table" then
    table.print(param)
    return
  end
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
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

function open_url(url)
  if not OS then local OS = reaper.GetOS() end
  if OS=="OSX32" or OS=="OSX64" then
    os.execute("open ".. url)
  else
    os.execute("start ".. url)
  end
end

if not reaper.BR_GetMidiSourceLenPPQ then
  local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
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
      if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tTake[take] = nil end -- Remove takes that were not affected by deselection
    end
  end
  if not next(tTake) then return end
  return tTake
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

local function setAllEvents(take, events)
  local lastPos = 0
  for _, event in pairs(events) do -- 把事件的位置转换成偏移量
    event.offset = event.pos - lastPos
    lastPos = event.pos
  end

  local tab = {}
  for _, event in pairs(events) do
    table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function setItemExtent(take)
  local range = {head = math.huge, tail = -math.huge}
  local events = getAllEvents(take, function(event)
    if event.selected then
      local pos = event.pos
      range.head = math.min(range.head, pos)
      range.tail = math.max(range.tail, pos)
    end
  end)
  local range_qn = {
    head = reaper.MIDI_GetProjQNFromPPQPos(take, range.head),
    tail = reaper.MIDI_GetProjQNFromPPQPos(take, range.tail)
  }
  range_qn.len = range_qn.tail - range_qn.head

  local item = reaper.GetMediaItemTake_Item(take)
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- + reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
  local qn_item_pos = reaper.TimeMap2_timeToQN(0, item_pos)
  local qn_item_len = reaper.TimeMap2_timeToQN(0, item_len)
  local qn_item_end = qn_item_pos + qn_item_len
  local event_start_pos_qn = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
  
  local result_tail_qn = range_qn.head + (range_qn.tail - range_qn.head)
  if result_tail_qn > qn_item_len + qn_item_pos then
    reaper.MIDI_SetItemExtents(item, qn_item_pos, result_tail_qn)
  end
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  -- local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  local lastPos = 0
  local events = {}
  
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local selectedStartEvents = {}
  local pitchLastStart = {}
  
  local stringPos = 1
  while stringPos < MIDI:len() do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDI, stringPos)
  
    local selected = flags&1 == 1
    local pitch = msg:byte(2)
    local status = msg:byte(1)>>4
    local event = {
      ["pos"] = lastPos + offset,
      ["flags"] = flags,
      ["msg"] = msg,
      ["selected"] = selected,
      ["pitch"] = pitch,
      ["status"] = status,
    }
    table.insert(events, event)

    if event.selected then
      if selectedStartEvents[event.pos] == nil then selectedStartEvents[event.pos] = {} end
      table.insert(selectedStartEvents[event.pos], event)
    end

    lastPos = lastPos + offset
  end
  
  for _, es in pairs(selectedStartEvents) do
    for i=1, #es do
      es[i].pos = es[i].pos + ticks
    end
  end
  
--   local last = events[#events]
--   table.remove(events, #events)
--   table.sort(events,function(a,b) -- 事件重新排序
--     -- if a.status == 11 then return false end
--     if a.pos == b.pos then
--       if a.status == b.status then
--         return a.pitch < b.pitch
--       end
--       return a.status < b.status
--     end
--     return a.pos < b.pos
--   end)
--   table.insert(events, last)
  
  setAllEvents(take, events)
  setItemExtent(take)
  reaper.MIDI_Sort(take)
  
--   if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
--     reaper.MIDI_SetAllEvts(take, MIDI)
--     reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
--   end
end

reaper.Undo_EndBlock("Move Events Left 10 Ticks (Fast)", -1)
reaper.UpdateArrange()