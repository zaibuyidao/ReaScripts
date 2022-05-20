--[[
 * ReaScript Name: Trim Note Right Edge (Fast)
 * Version: 1.0.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-5-12)
  + Initial release
--]]

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function print(...)
  local params = {...}
  for i=1, #params do
    if i ~= 1 then reaper.ShowConsoleMsg(" ") end
    reaper.ShowConsoleMsg(tostring(params[i]))
  end
  reaper.ShowConsoleMsg("\n")
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

local function min(a,b)
  if a>b then
    return b
  end
  return a
end

local function max(a,b)
  if a<b then
    return b
  end
  return a
end

function setAllEvents(take, events)
  local lastPos = 0
  for _, event in pairs(events) do
    -- event.pos = min(event.pos, events[#events].pos)
    event.offset = event.pos - lastPos
    lastPos = event.pos
    -- print("calc offset:" .. event.offset .. " " .. event.status)
  end

  local tab = {}
  for _, event in pairs(events) do
    table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function getEventPitch(event) return event.msg:byte(2) end
function getEventSelected(event) return event.flags&1 == 1 end
function getEventType(event) return event.msg:byte(1)>>4 end

function rightPlus(take, ticks)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  -- reaper.MIDIEditor_OnCommand(tTake[take].editor, 40659) -- 删除重叠音符
  local lastPos = 0
  local pitchNotes = {}
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  local stringPos = 1
  local events = {}
  while stringPos < MIDIstring:len() do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    
    local selected = flags&1 == 1
    local pitch = msg:byte(2)
    local status = msg:byte(1)>>4

    if pitchNotes[pitch] == nil then pitchNotes[pitch] = {} end

    local event = {
      pos = lastPos + offset, -- ["pos"] = lastPos + offset,
      flags = flags,
      msg = msg,
      selected = selected,
      pitch = pitch,
      status = status,
    }
    table.insert(events, event)

    if event.status == EVENT_NOTE_END or event.status == EVENT_NOTE_START then
      table.insert(pitchNotes[pitch], event)
    end

    lastPos = lastPos + offset
  end
  
  pitchLastStart = {}
  
  for _, es in pairs(pitchNotes) do
    for i = 1, #es do
      if es[i].selected then
        if es[i].status == EVENT_NOTE_END then
          pitchLastStart[es[i].pitch] = es[i].pos
          if pitchLastStart[es[i].pitch] > es[i].pos + ticks then
            goto continue
          end
          if i == #es then
            --if es[i].pos + ticks < 0 then goto continue end
            es[i].pos = es[i].pos + ticks
          else
            es[i].pos = min((es[i].pos + ticks), es[i+1].pos)
          end
        end
      end
      ::continue::
    end
  end

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
  end
end

function rightMinus(take, ticks)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  -- reaper.MIDIEditor_OnCommand(tTake[take].editor, 40659) -- 删除重叠音符
  local lastPos = 0
  local pitchNotes = {}
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")

  local noteEvents = {}

  local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
  local articulationEventAtPitch = {}
  local events = {}
  local stringPos = 1
  while stringPos < MIDIstring:len() do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    local event = { offset = offset, pos = lastPos + offset, flags = flags, msg = msg }
    table.insert(events, event)

    local eventType = getEventType(event)
    local eventPitch = getEventPitch(event)

    if eventType == EVENT_NOTE_START then
      noteStartEventAtPitch[eventPitch] = event
    elseif eventType == EVENT_NOTE_END then
      local start = noteStartEventAtPitch[eventPitch]
      if start == nil then error("音符有重叠無法解析") end
      table.insert(noteEvents, {
        first = start,
        second = event,
        articulation = articulationEventAtPitch[eventPitch],
        pitch = getEventPitch(start)
      })

      noteStartEventAtPitch[eventPitch] = nil
      articulationEventAtPitch[eventPitch] = nil
    end
    lastPos = lastPos + offset
  end

  setAllEvents(take, events)

  for i = 1, #noteEvents do
    local selected = getEventSelected(noteEvents[i].first)
    local startppqpos = noteEvents[i].first.pos
    local endppqpos = noteEvents[i].second.pos
    if selected then
      if noteEvents[i].second.pos <= noteEvents[i].first.pos + 30 then goto continue end -- 限制最小音符长度
      noteEvents[i].second.pos = noteEvents[i].second.pos + ticks
      ::continue::
      if noteEvents[i].first.pos >= noteEvents[i].second.pos then noteEvents[i].second.pos = startppqpos + 30 end
      if endppqpos - startppqpos < 30 then noteEvents[i].second.pos = startppqpos + 30 end -- 限制最小音符长度
    end
  end

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
  end
end

ticks = reaper.GetExtState("TrimNoteRightEdgeFast", "Ticks")
if (ticks == "") then ticks = "10" end
local user_ok, ticks = reaper.GetUserInputs("Trim Note Right Edge (Fast)", 1, "Enter A Tick", ticks)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("TrimNoteRightEdgeFast", "Ticks", ticks, false)
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  if tonumber(ticks) > 0 then
    rightPlus(take, ticks)
  else
    rightMinus(take, ticks)
  end
end
reaper.Undo_EndBlock("Trim Note Right Edge (Fast)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()