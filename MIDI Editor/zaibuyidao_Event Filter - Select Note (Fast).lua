-- @description Event Filter - Select Note (Fast)
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  local params = {...}
  for i=1, #params do
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
    articulation = function(event) return event.msg:byte(1) >> 4 end,
    channel = function(event) return event.msg:byte(1)&0x0F end
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
      if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
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

local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

local min_key = reaper.GetExtState("SelectNote", "MinKey") -- 音高范围小
if (min_key == "") then min_key = "0" end
local max_key = reaper.GetExtState("SelectNote", "MaxKey") -- 音高范围大
if (max_key == "") then max_key = "127" end
local min_vel = reaper.GetExtState("SelectNote", "MinVel") -- 力度范围小
if (min_vel == "") then min_vel = "1" end
local max_vel = reaper.GetExtState("SelectNote", "MaxVel") -- 力度范围大
if (max_vel == "") then max_vel = "127" end
local min_dur = reaper.GetExtState("SelectNote", "MinDur") -- 时值范围小
if (min_dur == "") then min_dur = "0" end
local max_dur = reaper.GetExtState("SelectNote", "MaxDur") -- 时值范围大
if (max_dur == "") then max_dur = "65535" end
local min_chan = reaper.GetExtState("SelectNote", "MinChan") -- 通道范围小
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectNote", "MaxChan") -- 通道范围大
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectNote", "MinMeas") -- 小节范围小
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectNote", "MaxMeas") -- 小节范围大
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectNote", "MinTick") -- tick范围小
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectNote", "MaxTick") -- tick范围大
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectNote", "Reset")
if (reset == "") then reset = "n" end

if language == "简体中文" then
  title = "选择音符(快速)"
  captions_csv = "音高,,力度,,时值,,通道,,拍子,,嘀嗒,,重置 (y/n)"
  msgbox = "检测到重叠音符，解析失败。"
  msgbox2 = "找不到开始事件，解析失败。"
  msgerr = "错误"
elseif language == "繁体中文" then
  title = "選擇音符(快速)"
  captions_csv = "音高,,力度,,時值,,通道,,拍子,,嘀嗒,,重置 (y/n)"
  msgbox = "檢測到重叠音符，解析失敗"
  msgbox2 = "找不到開始事件，解析失敗"
  msgerr = "錯誤"
else
  title = "Select Note"
  captions_csv = "Key,,Velocity,,Duration,,Channel,,Beat,,Tick,,Reset (y/n)"
  msgbox = "Overlapping notes detected, parsing failed."
  msgbox2 = "Start event not found, parsing failed."
  msgerr = "Error"
end

retval_ok, retvals_csv = reaper.GetUserInputs(title, 13, captions_csv, min_key ..','.. max_key ..','.. min_vel ..','.. max_vel ..','.. min_dur ..','.. max_dur ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not retval_ok then return reaper.SN_FocusMIDIEditor() end

min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_key) or not tonumber(max_key) or not tonumber(min_vel) or not tonumber(max_vel) or not tonumber(min_dur) or not tonumber(max_dur) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tostring(reset) then return reaper.SN_FocusMIDIEditor() end
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tostring(reset)

reaper.SetExtState("SelectNote", "MinKey", min_key, false)
reaper.SetExtState("SelectNote", "MaxKey", max_key, false)
reaper.SetExtState("SelectNote", "MinVel", min_vel, false)
reaper.SetExtState("SelectNote", "MaxVel", max_vel, false)
reaper.SetExtState("SelectNote", "MinDur", min_dur, false)
reaper.SetExtState("SelectNote", "MaxDur", max_dur, false)
reaper.SetExtState("SelectNote", "MinChan", min_chan, false)
reaper.SetExtState("SelectNote", "MaxChan", max_chan, false)
reaper.SetExtState("SelectNote", "MinMeas", min_meas, false)
reaper.SetExtState("SelectNote", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectNote", "MinTick", min_tick, false)
reaper.SetExtState("SelectNote", "MaxTick", max_tick, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

if reset == "y" then
  min_key = "0"
  max_key = "127"
  min_vel = "1"
  max_vel = "127"
  min_dur = "0"
  max_dur = "65535"
  min_chan = "1"
  max_chan = "16"
  min_meas = "1"
  max_meas = "99"
  min_tick = "0"
  max_tick = "1919"
  reset = "n"

  retval_ok, retvals_csv = reaper.GetUserInputs(title, 13, captions_csv, min_key ..','.. max_key ..','.. min_vel ..','.. max_vel ..','.. min_dur ..','.. max_dur ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
  if not retval_ok then return reaper.SN_FocusMIDIEditor() end

  min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(min_key) or not tonumber(max_key) or not tonumber(min_vel) or not tonumber(max_vel) or not tonumber(min_dur) or not tonumber(max_dur) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tostring(reset) then return reaper.SN_FocusMIDIEditor() end
  min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tostring(reset)
  
  reaper.SetExtState("SelectNote", "MinKey", min_key, false)
  reaper.SetExtState("SelectNote", "MaxKey", max_key, false)
  reaper.SetExtState("SelectNote", "MinVel", min_vel, false)
  reaper.SetExtState("SelectNote", "MaxVel", max_vel, false)
  reaper.SetExtState("SelectNote", "MinDur", min_dur, false)
  reaper.SetExtState("SelectNote", "MaxDur", max_dur, false)
  reaper.SetExtState("SelectNote", "MinChan", min_chan, false)
  reaper.SetExtState("SelectNote", "MaxChan", max_chan, false)
  reaper.SetExtState("SelectNote", "MinMeas", min_meas, false)
  reaper.SetExtState("SelectNote", "MaxMeas", max_meas, false)
  reaper.SetExtState("SelectNote", "MinTick", min_tick, false)
  reaper.SetExtState("SelectNote", "MaxTick", max_tick, false)
  
  min_chan = min_chan - 1
  max_chan = max_chan - 1
  min_meas = min_meas - 1
end

local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  local last_note_event_at_pitch = {}
  local note_events = {}

  local events = getAllEvents(take, function(event)
    if not event.selected then
      goto continue
    end

    if event.type == EVENT_NOTE_START then
      if last_note_event_at_pitch[event.pitch] then
        reaper.ShowMessageBox(msgbox, msgerr, 0)
        return
      end
      last_note_event_at_pitch[event.pitch] = event
    elseif event.type == EVENT_NOTE_END then
      if not last_note_event_at_pitch[event.pitch] then
        reaper.ShowMessageBox(msgbox2, msgerr, 0)
        return
      end
      table.insert(note_events, {left = last_note_event_at_pitch[event.pitch], right = event})
      last_note_event_at_pitch[event.pitch] = nil
    end

    ::continue::
  end)
  for _, note_event in pairs(note_events) do

    local startppqpos, endppqpos = note_event.left.pos, note_event.right.pos
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    local duration = endppqpos - startppqpos

    note_event.left.selected = 
      (note_event.left.pitch >= min_key and note_event.left.pitch <= max_key)
      and (note_event.left.velocity >= min_vel and note_event.left.velocity <= max_vel)
      and ((note_event.right.pos - note_event.left.pos) >= min_dur and (note_event.right.pos - note_event.left.pos) <= max_dur)
      and (note_event.left.channel >= min_chan and note_event.left.channel <= max_chan)
      and (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick)
      and (tick >= min_tick and tick <= max_tick)

    note_event.right.selected = note_event.left.selected
  end
  setAllEvents(take, events)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()