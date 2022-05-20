--[[
 * ReaScript Name: 分割音符(快速)
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
 * About: Requires SWS Extensions
--]]

--[[
 * Changelog:
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

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
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

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ALL_NOTES_OFF = 11
EVENT_ARTICULATION = 15

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
            local head = noteLastEventAtPitch[event.pitch]
            if head == nil then error("音符有重叠無法解析") end
            local tail = event
            if event.selected and div <= tail.pos - head.pos then
                table.insert(notes, {
                    head = head,
                    tail = tail,
                    articulation = event.pitch,
                    pitch = event.pitch
                })
            end
            noteLastEventAtPitch[event.pitch] = nil
            articulationEventAtPitch[event.pitch] = nil
        elseif event.type == EVENT_ARTICULATION then
            if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
                -- text event
            else
                local chan, pitch = event.msg:match("NOTE (%d+) (%d+) ")
                articulationEventAtPitch[tonumber(pitch)] = event
            end
        end
    end)

    local skipEvents = {}
    local replacementForEvent = {}

    for _, note in ipairs(notes) do
      local replacement = {}
      skipEvents[note.head] = true
      skipEvents[note.tail] = true
      local len = note.tail.pos - note.head.pos
      local len_div = math.floor(len / div)
      local mult_len = note.head.pos + div * len_div
      for j = 1, len_div do
          local newNote = clone(note)
          newNote.head.pos = note.head.pos + (j - 1) * div
          newNote.tail.pos = note.head.pos + (j - 1) * div + div
          table.insert(replacement, newNote.head)
          table.insert(replacement, newNote.tail)
      end
      if mult_len < note.tail.pos then
        local newNote = clone(note)
        newNote.head.pos = note.head.pos + div * len_div
        newNote.tail.pos = note.tail.pos
        table.insert(replacement, newNote.head)
        table.insert(replacement, newNote.tail)
      end
      replacementForEvent[note.tail] = replacement
    end
    
    local newEvents = {}
    for _, event in ipairs(events) do
      if replacementForEvent[event] then
        for _, e in ipairs(replacementForEvent[event]) do table.insert(newEvents, e) end
      end
      if not skipEvents[event] then
        table.insert(newEvents, event)
      end
    end
    setAllEvents(take, newEvents)
    reaper.MIDI_Sort(take)
end

div_ret = reaper.GetExtState("SplitNotesFast", "Length")
if (div_ret == "") then div_ret = "240" end
user_ok, div_ret = reaper.GetUserInputs('分割音符(快速)', 1, '長度', div_ret)
reaper.SetExtState("SplitNotesFast", "Length", div_ret, false)
div = tonumber(div_ret)
if not user_ok then return reaper.SN_FocusMIDIEditor() end

reaper.Undo_BeginBlock()
if div ~= nil then 
  for take, _ in pairs(getAllTakes()) do
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    main(div, take)

    local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDIstring)
        reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
    end
  end
end
reaper.Undo_EndBlock("分割音符(快速)", -1)
reaper.SN_FocusMIDIEditor()