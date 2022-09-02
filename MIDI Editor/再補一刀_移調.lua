-- @description 移調
-- @version 1.3.3
-- @author 再補一刀
-- @changelog 優化代碼
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repository https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_inlineeditor] .
-- @about Requires SWS Extensions

EVENT_NOTE_START = 9 -- Note-on 音符开
EVENT_NOTE_END = 8 -- Note-off 音符关
EVENT_AFTER_TOUCH = 10 -- After Touch 触后
EVENT_CC = 11 -- Continuous Controller CC控制器
EVENT_PROGRAM = 12 -- Program 程序选择
EVENT_CHPRESS = 13 -- Channel Pressure 通道压力
EVENT_PITCH = 14 -- Pitch Wheel 弯音事件
EVENT_ARTICULATION = 15 -- Articulation 符号

--EVENT_BANKPROG = 11 and (msg:byte(2) == 0 or msg:byte(2) == 32) -- 音色库事件
--EVENT_TEXT = msg:byte(1) == 0xFF and not (msg:byte(2) == 0x0F) -- 文本事件，排除 notation text 事件
--EVENT_SYSEX = 0xF and not (msg:byte(1) == 0xFF) -- 系统码事件

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

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
end

function setAllEvents(take, events)
  local headPos = math.huge -- 开头位置，用于扩展边界
  local tailPos = 0 -- 末尾位置，用于扩展边界
  local lastPos = 0 -- 上一次遍历到的位置
  
  -- local minPos = math.huge
  -- for _, event in pairs(events) do minPos = math.min(minPos, event.pos) end
  -- local lastPos = math.min(minPos, 0) -- 上一次遍历到的位置

  for _, event in pairs(events) do
    headPos = math.min(headPos, event.pos)
    tailPos = math.max(tailPos, event.pos)
    event.offset = event.pos - lastPos
    lastPos = event.pos
  end
  
  -- item边界扩展处理
  events[#events].pos = math.max(events[#events].pos, tailPos)
  local item = reaper.GetMediaItemTake_Item(take)
  reaper.MIDI_SetItemExtents(
    item, 
    reaper.MIDI_GetProjQNFromPPQPos(take, math.min(0, headPos)), -- reaper.TimeMap2_timeToQN(0, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
    reaper.MIDI_GetProjQNFromPPQPos(take, events[#events].pos)
  )

  local tab = {}
  for _, event in pairs(events) do
    table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab))
end

function getAllEvents(take, onEach)
  local getters = {
    selected = function (event) return event.flags & 1 == 1 end, -- 选中
    pitch = function (event)  -- 音高
      if event.isArticulation then  -- 音符事件的通道和音高需要特殊处理
        local _, pitch = event.msg:match("NOTE (%d+) (%d+) ")
        return tonumber(pitch)
      end
      return event.msg:byte(2) 
    end,
    velocity = function (event) return event.msg:byte(3) end, -- 力度
    channel = function (event)  -- 通道
      if event.isArticulation then  -- 音符事件的通道和音高需要特殊处理
        local channel, _ = event.msg:match("NOTE (%d+) (%d+) ")
        return tonumber(channel)
      end
      return event.msg:byte(1)&0x0F 
    end,
    type = function (event) return event.msg:byte(1) >> 4 end, -- 类型
    articulation = function (event) return event.msg:byte(1) >> 4 end,
    isArticulation = function (event) if event.type == EVENT_ARTICULATION and event.msg:find("articulation") then return true end return false end,
    isCCBZ = function (event) if event.type == EVENT_ARTICULATION and event.msg:find("CCBZ") then return true end return false end,
  }
  local setters = {
    pitch = function (event, value)
      if event.isArticulation then  -- 音符事件的通道和音高需要特殊处理
        event.msg = event.msg:gsub("NOTE (%d+) (%d+) ", function (channel, pitch)
          return string.format("NOTE %s %d ", channel, value)
        end)
        return
      end
      event.msg = string.pack("BBB", event.msg:byte(1), value or event.msg:byte(2), event.msg:byte(3))
    end,
    channel = function (event, value)
      if event.isArticulation then  -- 音符事件的通道和音高需要特殊处理
        event.msg = event.msg:gsub("NOTE (%d+) (%d+) ", function (channel, pitch)
          return string.format("NOTE %d %s ", value, pitch)
        end)
        return
      end
      event.msg = string.pack("BBB", ((event.msg:byte(1)&0xF0) | (value&0x0F)) , event.msg:byte(2), event.msg:byte(3))
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

function getAllTakes()
  tTake = {}
  if reaper.MIDIEditor_EnumTakes then
    local editor = reaper.MIDIEditor_GetActive()
    for i = 0, math.huge do
      take = reaper.MIDIEditor_EnumTakes(editor, i, false)
      if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
        tTake[take] = true
        tTake[take] = {item = reaper.GetMediaItemTake_Item(take), editor = editor}
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

local window, _, _ = reaper.BR_GetMouseCursorContext()
local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()

local semitone = reaper.GetExtState("Transpose", "Semitone")
if (semitone == "") then semitone = "0" end

uok, uinput = reaper.GetUserInputs("移調", 1, "半音(±)", semitone)
if not uok or not tonumber(semitone) then return reaper.SN_FocusMIDIEditor() end
semitone = uinput:match("(.*)")

semitone = tonumber(semitone)
reaper.SetExtState("Transpose", "Semitone", semitone, false)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if window == "midi_editor" then
  if not inline_editor then
    for i = 1, math.abs(semitone) do
      if semitone > 0 then
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40177) -- Edit: Move notes up one semitone
      else
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40178) -- Edit: Move notes down one semitone
      end
    end
  else
    local take = reaper.BR_GetMouseCursorContext_Take()
    local articulationMap = {} -- 符号事件记录表
    local noteEvents = {}

    local events = getAllEvents(take, function (event)
      if event.isArticulation then
        articulationMap[event.pos] = articulationMap[event.pos] or {}
        articulationMap[event.pos][event.pitch] = event
      end

      if (event.type == EVENT_NOTE_START or event.type == EVENT_NOTE_END) and event.selected then
        table.insert(noteEvents, event)
      end
    end)
  
    for _, event in pairs(noteEvents) do
      local originPos = event.pos
      local originPitch = event.pitch
      -- 移动音符
      event.pitch = math.min(event.pitch + semitone, 127)
      -- 移动符号
      if event.type == EVENT_NOTE_START and articulationMap[originPos] and articulationMap[originPos][originPitch] then
        articulationMap[originPos][originPitch].pitch = event.pitch
      end
    end
    
    setAllEvents(take, events)
    reaper.MIDI_Sort(take)
  end
  if not inline_editor then reaper.SN_FocusMIDIEditor() end
else
  for take, _ in pairs(getAllTakes()) do
    local articulationMap = {} -- 符号事件记录表
    local noteEvents = {}

    local events = getAllEvents(take, function (event)
      if event.isArticulation then
        articulationMap[event.pos] = articulationMap[event.pos] or {}
        articulationMap[event.pos][event.pitch] = event
      end

      if (event.type == EVENT_NOTE_START or event.type == EVENT_NOTE_END) and event.selected then
        table.insert(noteEvents, event)
      end
    end)
  
    for _, event in pairs(noteEvents) do
      local originPos = event.pos
      local originPitch = event.pitch
      -- 移动音符
      event.pitch = math.min(event.pitch + semitone, 127)
      -- 移动符号
      if event.type == EVENT_NOTE_START and articulationMap[originPos] and articulationMap[originPos][originPitch] then
        articulationMap[originPos][originPitch].pitch = event.pitch
      end
    end
    
    setAllEvents(take, events)
    reaper.MIDI_Sort(take)
  end
  
  -- for take, _ in pairs(getAllTakes()) do
  --   if reaper.TakeIsMIDI(take) then
  --     local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
  --     local note = {}
  --     for i = 1, notecnt do
  --       note[i] = {}
  --       note[i].ret,
  --       note[i].sel,
  --       note[i].muted,
  --       note[i].startppqpos,
  --       note[i].endppqpos,
  --       note[i].chan,
  --       note[i].pitch,
  --       note[i].vel = reaper.MIDI_GetNote(take, i - 1)
  --     end
  --     for i = 1, notecnt do
  --       reaper.MIDI_DeleteNote(take, 0)
  --     end
  --     for i = 1, notecnt do
  --       reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch + semitone, note[i].vel, false)
  --     end
  --   end
  --   reaper.MIDI_Sort(take)
  -- end
end

reaper.Undo_EndBlock("移調", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
