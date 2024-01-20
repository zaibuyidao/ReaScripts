-- @description Set Note Length (Fast)
-- @version 1.0.1
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
    event.offset = event.pos - lastPos
    lastPos = event.pos
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

function main(take, tick)
  local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
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
      local showmsg = ""
      if language == "简体中文" then
        showmsg = "音符有重叠无法解析"
      elseif language == "繁体中文" then
        showmsg = "音符有重叠無法解析"
      else
        showmsg = "Notes are overlapping and cannot be resolved."
      end
      local start = noteStartEventAtPitch[eventPitch]
      if start == nil then error(showmsg) end
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
      --if noteEvents[i].second.pos <= noteEvents[i].first.pos + 30 then goto continue end -- 限制最小音符长度
      noteEvents[i].second.pos = noteEvents[i].first.pos + tick
      --::continue::
      -- if noteEvents[i].first.pos >= noteEvents[i].second.pos then noteEvents[i].second.pos = startppqpos + 30 end
      -- if endppqpos - startppqpos < 30 then noteEvents[i].second.pos = startppqpos + 30 end -- 限制最小音符长度
    end
  end

  setAllEvents(take, events)
  --reaper.MIDI_Sort(take)

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

if language == "简体中文" then
  title = "设置音符长度"
  captions_csv = "输入嘀答数:"
elseif language == "繁体中文" then
  title = "設置音符長度"
  captions_csv = "輸入嘀答數:"
else
  title = "Set Note Length"
  captions_csv = "Enter A Tick:"
end

tick = reaper.GetExtState("SET_NOTE_LENGTH", "Ticks")
if (tick == "") then tick = "10" end
user_ok, tick = reaper.GetUserInputs(title, 1, captions_csv, tick)
reaper.SetExtState("SET_NOTE_LENGTH", "Ticks", tick, false)

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  main(take, tick)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()