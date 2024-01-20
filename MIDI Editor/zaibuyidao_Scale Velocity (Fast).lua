-- @description Scale Velocity (Fast)
-- @version 1.0.5
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ")
  end
  reaper.ShowConsoleMsg("\n")
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

if not reaper.SN_FocusMIDIEditor then
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

local title, captions_csv = "", ""
if language == "简体中文" then
  title = "力度缩放(快速)"
  captions_csv = "开始,结束,模式:直线-百分比-正弦-凹-凸"
elseif language == "繁体中文" then
  title = "力度縮放(快速)"
  captions_csv = "開始,結束,模式:直綫-百分比-正弦-凹-凸"
else
  title = "Scale Velocity (Fast)"
  captions_csv = "Begin,End,Mode:Line-Percent-Sine-In-Out"
end

local vel_start = reaper.GetExtState("SCALE_VELOCITY_FAST", "Start")
local vel_end = reaper.GetExtState("SCALE_VELOCITY_FAST", "End")
local toggle = reaper.GetExtState("SCALE_VELOCITY_FAST", "Toggle")
if (vel_start == "") then vel_start = "100" end
if (vel_end == "") then vel_end = "100" end
if (toggle == "") then toggle = "0" end

local uok, uinput = reaper.GetUserInputs(title, 3, captions_csv, vel_start..','..vel_end..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
vel_start, vel_end, toggle = uinput:match("(%d*),(%d*),(%d*)")
if not tonumber(vel_start) or not tonumber(vel_end) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
vel_start, vel_end = tonumber(vel_start), tonumber(vel_end)

reaper.SetExtState("SCALE_VELOCITY_FAST", "Start", vel_start, false)
reaper.SetExtState("SCALE_VELOCITY_FAST", "End", vel_end, false)
reaper.SetExtState("SCALE_VELOCITY_FAST", "Toggle", toggle, false)

function process(take)
  local selectedNoteEvents = {}
  local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
  
  local events = getAllEvents(take, function (event)
    local eventType = getEventType(event)
    local eventPitch = getEventPitch(event)
    if eventType == EVENT_NOTE_START then
      noteStartEventAtPitch[eventPitch] = event
      local start = noteStartEventAtPitch[eventPitch]
      if getEventSelected(event) then
        table.insert(selectedNoteEvents, {
          first = start,
          second = event,
          pitch = eventPitch
        })
      end
    end
  end)
  
  -- local events = getAllEvents(take, function (event)
  --   local eventType = getEventType(event)
  --   local eventPitch = getEventPitch(event)
  --   if eventType == EVENT_NOTE_START then
  --     noteStartEventAtPitch[eventPitch] = event
  --   elseif eventType == EVENT_NOTE_END then
  --     local start = noteStartEventAtPitch[eventPitch]
  --     if start == nil then error("音符有重叠無法解析") end
  --     noteStartEventAtPitch[eventPitch] = nil
  --     if getEventSelected(event) then
  --       table.insert(selectedNoteEvents, {
  --         first = start,
  --         second = event,
  --         pitch = eventPitch
  --       })
  --     end
  --   end
  -- end)
  
  if #selectedNoteEvents == 0 then return end

  local f = curve_fun_builders[toggle](
    vel_start, vel_end,
    selectedNoteEvents[#selectedNoteEvents].first.pos - selectedNoteEvents[1].first.pos
  )
  
  for _, noteEvent in pairs(selectedNoteEvents) do
    local vel = getEventVel(noteEvent.first)
    if selectedNoteEvents[1].first.pos ~= selectedNoteEvents[#selectedNoteEvents].first.pos then
      local x = noteEvent.first.pos - selectedNoteEvents[1].first.pos
      if vel_start == vel_end and toggle ~= "1" then
        setEventVel(noteEvent.first, vel_start)
      else
        local vel = getEventVel(noteEvent.first)
        local newVel = math.floor(f(x, vel))
        if newVel < 1 then newVel = 1 elseif newVel > 127 then newVel = 127 end
        setEventVel(noteEvent.first, newVel)
      end
    else
      setEventVel(noteEvent.first, vel_start)
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
    if language == "简体中文" then
      msgbox = "脚本造成事件位置位移，原始MIDI数据已恢复"
      errbox = "错误"
    elseif language == "繁体中文" then
      msgbox = "腳本造成事件位置位移，原始MIDI數據已恢復"
      errbox = "錯誤"
    else
      msgbox = "The script caused event position displacement, original MIDI data has been restored."
      errbox = "Error"
    end
    reaper.ShowMessageBox(msgbox, errbox, 0)
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.SN_FocusMIDIEditor()