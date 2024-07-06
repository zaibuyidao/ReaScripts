-- @description Set Note Length
-- @version 1.6
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()
local getTakes = getAllTakes()

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
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
      elseif language == "繁體中文" then
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
    elseif language == "繁體中文" then
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
elseif language == "繁體中文" then
  title = "設置音符長度"
  captions_csv = "輸入嘀答數:"
else
  title = "Set Note Length"
  captions_csv = "Enter A Tick:"
end

local tick = reaper.GetExtState("SET_NOTE_LENGTH", "Ticks")
if (tick == "") then tick = "10" end

uok, tick = reaper.GetUserInputs(title, 1, captions_csv, tick)
if not uok then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("SET_NOTE_LENGTH", "Ticks", tick, false)

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
  main(take, tick)
end
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()