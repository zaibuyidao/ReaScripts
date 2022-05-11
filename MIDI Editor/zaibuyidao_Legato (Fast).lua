--[[
 * ReaScript Name: Legato (Fast)
 * Version: 1.0.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-1-2)
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

function setAllEvents(take, events)
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

local function getAllNotesQuick()
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  local MIDIlen = MIDIstring:len()
  local result = {}
  local stringPos = 1
  while stringPos < MIDIlen do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    -- if msg:len() == 3 then -- 如果msg包含3个字节
      local selected = flags&1 == 1
      local pitch = msg:byte(2)
      local status = msg:byte(1)>>4
      table.insert(result, {
        ["offset"] = offset,
        ["flags"] = flags,
        ["msg"] = msg,
        ["selected"] = selected,
        ["pitch"] = pitch,
        ["status"] = status,
      })
    -- end
  end
  return result
end

local function getGroupPitchEvents()
  local lastPos = 0
  local pitchNotes = {}
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  local MIDIlen = MIDIstring:len()
  local stringPos = 1
  while stringPos < MIDIlen do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    -- if msg:len() == 3 then -- 如果msg包含3个字节
    local selected = flags&1 == 1
    local pitch = msg:byte(2)
    local status = msg:byte(1)>>4
    if pitchNotes[pitch] == nil then pitchNotes[pitch] = {} end
    table.insert(pitchNotes[pitch], {
      ["pos"] = lastPos + offset,
      ["flags"] = flags,
      ["msg"] = msg,
      ["selected"] = selected,
      ["pitch"] = pitch,
      ["status"] = status,
    })
    lastPos = lastPos + offset
    -- end
  end
  return pitchNotes
end

function legato(take)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
  local lastPos = 0
  local events = {}
  local pitchLastStart = {} -- 每个音高上一个音符的开始位置
  local startPoss = {}
  local startPosIndex = {}
  local endEvents = {}
  
  local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
  local pos = 1
  while pos < MIDI:len() do
    local offset, flags, msg
    offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)

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

    if not event.selected then
      goto continue
    end

    if event.status == 9 then
      -- 遍历到了一个新的开始事件位置
      if #startPoss == 0 or event.pos > startPoss[#startPoss] then
        -- 记录开始位置
        table.insert(startPoss, event.pos)  
        startPosIndex[event.pos] = #startPoss
        
        -- 对缓存的结束事件赋值
        for _, endEvent in pairs(endEvents) do
          endEvent.pos = event.pos
        end
        endEvents = {}
      end

      pitchLastStart[event.pitch] = event.pos
    elseif event.status == 8 then
      local startPosindex = startPosIndex[pitchLastStart[event.pitch]] -- 当前结束事件对应的音符的开始位置索引值
      if startPosindex ~= #startPoss then
        event.pos = startPoss[startPosindex + 1]
      else
        -- 加入缓存，等待新的开始事件出现
        table.insert(endEvents, event)
      end
    end

    ::continue::
    lastPos = lastPos + offset
  end
  
  -- table.sort(events,function(a,b) -- 事件重新排序
  --     -- if a.status == 11 then return false end
  --     if a.pos == b.pos then
  --         if a.status == b.status then
  --             return a.pitch < b.pitch
  --         end
  --         return a.status < b.status
  --     end
  --     return a.pos < b.pos
  -- end)

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDI)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 位置偏移\n\n已恢復原始數據", "錯誤", 0)
  end
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  legato(take)
end
reaper.UpdateArrange()
reaper.Undo_EndBlock("Legato (Fast)", -1)