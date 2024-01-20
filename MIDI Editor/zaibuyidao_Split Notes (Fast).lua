-- @description Split Notes (Fast)
-- @version 1.0.6
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

if language == "简体中文" then
  swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
  swserr = "警告"
  jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
  jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁体中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
end

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

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
end

local function clone(object)
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

local EventMeta = {
  __index = function (event, key)
    if (key == "selected") then
      return event.flags & 1 == 1
    elseif key == "pitch" then
      return event.msg:byte(2)
    elseif key == "Velocity" then
      return event.msg:byte(3)
    elseif key == "type" then
      return event.msg:byte(1) >> 4
    elseif key == "articulation" then
      return event.msg:byte(1) >> 4
    end
  end,
  __newindex = function (event, key, value)
    if key == "pitch" then
      event.msg = string.pack("BBB", event.msg:byte(1), value or event.msg:byte(2), event.msg:byte(3))
    elseif key == "Velocity" then
      event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2), value or event.msg:byte(3))
    end
  end
}

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
      local event = setmetatable({
        offset = offset,
        pos = lastPos + offset,
        flags = flags,
        msg = msg
      }, EventMeta)
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

function main(div, take)
    if div == nil then return end
    reaper.MIDI_DisableSort(take)
    local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    local notes = {}
    local noteLastEventAtPitch = {}
    local articulationEventAtPitch = {}

    local events = getAllEvents(take, function(event)
      if event.type == EVENT_NOTE_START then
        noteLastEventAtPitch[event.pitch] = event
      elseif event.type == EVENT_NOTE_END then
        local showmsg = ""
        if language == "简体中文" then
          showmsg = "音符有重叠无法解析"
        elseif language == "繁体中文" then
          showmsg = "音符有重叠無法解析"
        else
          showmsg = "Notes are overlapping and cannot be resolved."
        end
        local head = noteLastEventAtPitch[event.pitch]
        if head == nil then error(showmsg) end
        local tail = event
        if event.selected and div <= tail.pos - head.pos then
            table.insert(notes, {
              head = head,
              tail = tail,
              articulation = articulationEventAtPitch[event.pitch],
              pitch = event.pitch
            })
        end
        noteLastEventAtPitch[event.pitch] = nil
        articulationEventAtPitch[event.pitch] = nil
      elseif event.type == EVENT_ARTICULATION then
        if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
          -- text event
        elseif event.msg:find("articulation") then
          local chan, pitch = event.msg:match("NOTE (%d+) (%d+) ")
          articulationEventAtPitch[tonumber(pitch)] = event
        end
      end
    end)

    local skipEvents = {}
    local replacementForEvent = {}
    local copyAritulationForEachNote = false -- 如果为true，则切割后的每一个音符都将带上原有符号信息

    for _, note in ipairs(notes) do
      local replacement = {}
      skipEvents[note.head] = true
      skipEvents[note.tail] = true
      local len = note.tail.pos - note.head.pos
      local len_div = math.floor(len / div)
      local mult_len = note.head.pos + div * len_div
      local first = true -- 是否是切割后的第一个音符
      for j = 1, len_div do
        local newNote = clone(note)
        newNote.head.pos = note.head.pos + (j - 1) * div
        newNote.tail.pos = note.head.pos + (j - 1) * div + div
        if newNote.articulation then newNote.articulation.pos = newNote.head.pos end
        table.insert(replacement, newNote.head)
        if first or copyAritulationForEachNote then
          table.insert(replacement, newNote.articulation)
        end
        table.insert(replacement, newNote.tail)
        first = false
      end
      if mult_len < note.tail.pos then
        local newNote = clone(note)
        newNote.head.pos = note.head.pos + div * len_div
        newNote.tail.pos = note.tail.pos
        if newNote.articulation then newNote.articulation.pos = newNote.head.pos end
        table.insert(replacement, newNote.head)
        if first or copyAritulationForEachNote then
          table.insert(replacement, newNote.articulation)
        end
        table.insert(replacement, newNote.tail)
        first = false
      end
      replacementForEvent[note.tail] = replacement
    end
    
    local newEvents = {}
    local last = events[#events]
    table.remove(events, #events) -- 排除 All-Note-Off 事件
    for _, event in ipairs(events) do
      if replacementForEvent[event] then
        for _, e in ipairs(replacementForEvent[event]) do table.insert(newEvents, e) end
      end
      if not skipEvents[event] then
        table.insert(newEvents, event)
      end
    end
    table.insert(newEvents, last) -- 排除 All-Note-Off 事件
    setAllEvents(take, newEvents)
    reaper.MIDI_Sort(take)
end

local title = ""
local captions_csv = ""
local msgbox = ""
local errbox = ""

if language == "简体中文" then
  title = "分割音符(快速)"
  captions_csv = "长度 (tick):"
  msgbox = "脚本造成事件位置位移，原始MIDI数据已恢复"
  errbox = "错误"
elseif language == "繁体中文" then
  title = "分割音符(快速)"
  captions_csv = "長度 (tick):"
  msgbox = "腳本造成事件位置位移，原始MIDI數據已恢復"
  errbox = "錯誤"
else
  title = "Split Notes (Fast)"
  captions_csv = "Length (tick):"
  msgbox = "The script caused event position displacement, original MIDI data has been restored."
  errbox = "Error"
end

div_ret = reaper.GetExtState("SPLIT_NOTES_FAST", "Length")
if (div_ret == "") then div_ret = "240" end

uok, div_ret = reaper.GetUserInputs(title, 1, captions_csv, div_ret)
reaper.SetExtState("SPLIT_NOTES_FAST", "Length", div_ret, false)
div = tonumber(div_ret)
if not uok then return reaper.SN_FocusMIDIEditor() end

reaper.Undo_BeginBlock()
if div ~= nil then 
  for take, _ in pairs(getAllTakes()) do
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    main(div, take)

    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
      reaper.MIDI_SetAllEvts(take, MIDIstring)
      reaper.ShowMessageBox(msgbox, errbox, 0)
    end
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.SN_FocusMIDIEditor()