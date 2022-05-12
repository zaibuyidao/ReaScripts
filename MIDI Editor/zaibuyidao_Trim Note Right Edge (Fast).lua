--[[
 * ReaScript Name: Trim Note Right Edge (Fast)
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

function setAllEvents(take, events)
  local tab = {}
  for _, event in pairs(events) do
    table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function main(take, amount)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  local lastPos = 0
  local pitchNotes = {}
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos = 1
  local events = {}
  while pos < MIDI:len() do
    local offset, flags, msg
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
    
    local selected = flags&1 == 1
    local pitch = msg:byte(2)
    local status = msg:byte(1)>>4
    if pitchNotes[pitch] == nil then pitchNotes[pitch] = {} end
    local e = {
      ["pos"] = lastPos + offset,
      ["flags"] = flags,
      ["msg"] = msg,
      ["selected"] = selected,
      ["pitch"] = pitch,
      ["status"] = status,
    }
    table.insert(events, e)

    if e.status == 8 or e.status == 9 then
      table.insert(pitchNotes[pitch], e)
    end

    lastPos = lastPos + offset
  end

  pitchLastStart = {}
  
  for _, es in pairs(pitchNotes) do
    for i = 1, #es do
      if not es[i].selected then
        goto continue
      end

      if es[i].status == 9 then
        pitchLastStart[es[i].pitch] = es[i].pos
      end
  
      if pitchLastStart[es[i].pitch] > es[i].pos + amount then
        goto continue
      end
      
      if es[i].status == 8 then
        if i == #es then
          es[i].pos = es[i].pos + amount
        else
          es[i].pos = min((es[i].pos + amount), es[i+1].pos)
        end
      end

      -- print(tostring(es[i].pos) .. " " .. tostring(es[i].status))
      ::continue::
      -- table.insert(events, es[i])
    end
  end
  
  local lastPos = 0
  for _, event in pairs(events) do
    event.pos = min(event.pos, events[#events].pos)
    event.offset = event.pos - lastPos
    lastPos = event.pos
    -- print("calc offset:" .. event.offset .. " " .. event.status)
  end

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDI)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
  end
end

reaper.Undo_BeginBlock()
amount = reaper.GetExtState("TrimNoteRightEdgeFast", "Amount")
if (amount == "") then amount = "-10" end
local user_ok, amount = reaper.GetUserInputs("Trim Note Right Edge (Fast)", 1, "Amount", amount)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("TrimNoteRightEdgeFast", "Amount", amount, false)
for take, _ in pairs(getAllTakes()) do
  main(take, amount)
end
reaper.UpdateArrange()
reaper.Undo_EndBlock("Trim Note Right Edge (Fast)", -1)
reaper.SN_FocusMIDIEditor()