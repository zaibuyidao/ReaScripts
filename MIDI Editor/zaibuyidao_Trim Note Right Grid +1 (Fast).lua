--[[
 * ReaScript Name: Trim Note Right Grid +1 (Fast)
 * Version: 1.0
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
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

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
      if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tT[take] = nil end -- Remove takes that were not affected by deselection
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

local active_take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not active_take or not reaper.TakeIsMIDI(active_take) then return end

function rightPlus(take, ticks)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  reaper.MIDIEditor_OnCommand(tTake[take].editor, 40659) -- 删除重叠音符
  local cur_gird, swing = reaper.MIDI_GetGrid(take)
  local tick_gird = midi_tick * cur_gird
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
          local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, pitchLastStart[es[i].pitch])
          local tick_start = pitchLastStart[es[i].pitch] - start_meas
          local tick_pos = tick_start % tick_gird
          -- if pitchLastStart[es[i].pitch] > es[i].pos + ticks then
          --   goto continue
          -- end
          if i == #es then
            --if es[i].pos + ticks < 0 then goto continue end -- 向右侧不需要
            if tick_pos ~= 0 then
              es[i].pos = es[i].pos + (tick_gird - tick_pos)
            else
              es[i].pos = es[i].pos + tick_gird
            end
          else
            if tick_pos ~= 0 then
              es[i].pos = min((es[i].pos + (tick_gird - tick_pos)), es[i+1].pos)
            else
              es[i].pos = min((es[i].pos + tick_gird), es[i+1].pos)
            end
          end
        end
      end
      -- ::continue::
    end
  end

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
  end
end

ticks = 0
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  rightPlus(take, ticks)
end
reaper.UpdateArrange()
reaper.Undo_EndBlock("Trim Note Right Grid +1 (Fast)", -1)