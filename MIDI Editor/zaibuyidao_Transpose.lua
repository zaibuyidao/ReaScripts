-- @description Transpose
-- @version 1.3.4
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @provides [main=main,midi_editor,midi_inlineeditor] .
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

if language == "简体中文" then
  title = "移调"
  captions_csv = "半音(±):"
elseif language == "繁体中文" then
  title = "移調"
  captions_csv = "半音(±):"
else
  title = "Transpose"
  captions_csv = "Semitone (±):"
end

local semitone = reaper.GetExtState("Transpose", "Semitone")
if (semitone == "") then semitone = "0" end
uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, semitone)
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

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()