--[[
 * ReaScript Name: 力度縮放(快速)
 * Version: 1.0.4
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
 * About: Requires SWS Extensions
--]]

--[[
 * Changelog:
 * v1.0 (2022-5-5)
  + Initial release
--]]

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function open_url(url)
  if not OS then local OS = reaper.GetOS() end
  if OS=="OSX32" or OS=="OSX64" then
    os.execute("open ".. url)
   else
    os.execute("start ".. url)
  end
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
end

function print(...)
  local params = {...}
  for i=1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
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
  local events = {}
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  local stringPos = 1
  local lastPos = 0
  while stringPos <= MIDIstring:len() do
      local offset, flags, msg
      offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
      local event = { offset = offset, pos = lastPos + offset, flags = flags, msg = msg }
      table.insert(events, event)
      onEach(event)
      lastPos = lastPos + offset
  end
  return events
end

function getEventSelected(event) return event.flags&1 == 1 end
function getEventType(event) return event.msg:byte(1)>>4 end
function getArticulationInfo(event) return event.msg:match("NOTE (%d+) (%d+) ") end

function getEventPitch(event) return event.msg:byte(2) end
function setEventPitch(event, pitch) event.msg = string.pack("BBB", event.msg:byte(1), pitch or event.msg:byte(2), event.msg:byte(3)) end

function getEventVel(event) return event.msg:byte(3) end
function setEventVel(event, vel) event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2), vel or event.msg:byte(3)) end

curve_fun_builders = {
  ["0"] = function (from, to, width)
    local k = (to - from) / width
    return function (x, y)
      return from + x * k
    end
  end,
  ["1"] = function (from, to, width)
    local k = (to - from) / width
    return function (x, y)
      return y * ((x * k + from) / 100)
    end
  end,
  ["2"] = function (from, to, width)
    return function (x, y)
      local scale = (from - to) / 2
      local mid = (from + to) / 2
      return mid + scale * math.cos((x / width) * math.pi)
    end
  end,
  ["3"] = function (from, to, width)  -- 凸
    return function (x, y)
      if from > to then
        return to + (from - to) * math.sqrt(1 - (x / width) ^ 2)
      end
      x = width - x
      return from + (to - from) * math.sqrt(1 - (x / width) ^ 2)
    end
  end,
  ["4"] = function (from, to, width) -- 凹
    return function (x, y)
      if from < to then
        return to + (from - to) * math.sqrt(1 - (x / width) ^ 2)
      end
      x = width - x
      return from + (to - from) * math.sqrt(1 - (x / width) ^ 2)
    end
  end
}

function get_linear_mapper(fromL, fromR, toL, toR)
  local fromW = fromR - fromL
  local toW = toR - toL
  return function (x)
     return toL + (((x - fromL) / fromW) * toW)
  end
end

function compress_builder(builder, percent)
  return function (from, to, width)
    local l, r  = width * percent, width - width * percent
    local func = builder(from, to, width)
    local x_mapper = get_linear_mapper(0, width, l, r)
    local y_mapper = get_linear_mapper(func(l), func(r), func(0), func(width))
    return function (x, y)
      return y_mapper(func(x_mapper(x), y))
    end
  end
end

curve_fun_builders["2"] = compress_builder(curve_fun_builders["2"], 0.95)
curve_fun_builders["3"] = compress_builder(curve_fun_builders["3"], 0.8)
curve_fun_builders["4"] = compress_builder(curve_fun_builders["4"], 0.8)

local vel_start = reaper.GetExtState("ScaleVelocityFast", "Start")
local vel_end = reaper.GetExtState("ScaleVelocityFast", "End")
local toggle = reaper.GetExtState("ScaleVelocityFast", "Toggle")
if (vel_start == "") then vel_start = "100" end
if (vel_end == "") then vel_end = "100" end
if (toggle == "") then toggle = "0" end
local uok, retvals_csv = reaper.GetUserInputs("力度縮放(快速)", 3, "開始,結束,模式:直綫-百分比-正弦-凹-凸", vel_start..','..vel_end..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
vel_start, vel_end, toggle = retvals_csv:match("(%d*),(%d*),(%d*)")
if not tonumber(vel_start) or not tonumber(vel_end) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
vel_start, vel_end = tonumber(vel_start), tonumber(vel_end)
reaper.SetExtState("ScaleVelocityFast", "Start", vel_start, false)
reaper.SetExtState("ScaleVelocityFast", "End", vel_end, false)
reaper.SetExtState("ScaleVelocityFast", "Toggle", toggle, false)

function process(take)
  local selectedNoteEvents = {}
  local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
  
  local events = getAllEvents(take, function (event)
    local eventType = getEventType(event)
    local eventPitch = getEventPitch(event)
    if eventType == EVENT_NOTE_START then
      noteStartEventAtPitch[eventPitch] = event
    elseif eventType == EVENT_NOTE_END then
      local start = noteStartEventAtPitch[eventPitch]
      if start == nil then error("音符有重叠無法解析") end
      noteStartEventAtPitch[eventPitch] = nil
      if getEventSelected(event) then
        table.insert(selectedNoteEvents, {
          first = start,
          second = event,
          pitch = eventPitch
        })
      end
    end
  end)
  
  if #selectedNoteEvents == 0 then return end

  local f = curve_fun_builders[toggle](
    vel_start, vel_end,
    selectedNoteEvents[#selectedNoteEvents].first.pos - selectedNoteEvents[1].first.pos
  )
  
  for _, noteEvent in pairs(selectedNoteEvents) do
    local x = noteEvent.first.pos - selectedNoteEvents[1].first.pos
    if vel_start == vel_end and toggle ~= "1" then
      setEventVel(noteEvent.first, vel_start)
      setEventVel(noteEvent.second, vel_start)
    else 
      local vel = getEventVel(noteEvent.first)
      local newVel = math.floor(f(x, vel))
      if newVel < 1 then newVel = 1 elseif newVel > 127 then newVel = 127 end
      setEventVel(noteEvent.first, newVel)
      setEventVel(noteEvent.second, newVel)
    end
  end
  setAllEvents(take, events)
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  process(take)

  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
  end
end
reaper.Undo_EndBlock("力度縮放(快速)", -1)
reaper.SN_FocusMIDIEditor()