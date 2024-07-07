-- @description Set Note Ends to Edit Cursor
-- @version 1.0
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

local function min(a,b)
  if a>b then
    return b
  end
  return a
end

function setAllEvents(take, events)
  local lastPos = 0
  for _, event in pairs(events) do -- 把事件的位置转换成偏移量
    -- event.pos = min(event.pos, events[#events].pos)
    event.offset = event.pos - lastPos
    lastPos = event.pos
    -- print("calc offset:" .. event.offset .. " " .. event.status)
  end

  local tab = {}
  for _, event in pairs(events) do
    table.insert(tab, string.pack("i4Bs4", math.floor(0.5 + event.offset), event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function endTime(take)
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
  
  local dur = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 获取光标位置
  for _, es in pairs(pitchNotes) do
    for i = 1, #es do
      if not es[i].selected then
        goto continue
      end

      if es[i].status == 9 then
        pitchLastStart[es[i].pitch] = es[i].pos
      elseif es[i].status == 8 then
        if pitchLastStart[es[i].pitch] == nil then error("Overlapping notes detected, unable to parse") end
      end

      if pitchLastStart[es[i].pitch] >= dur then
        goto continue
      end

      if es[i].status == 8 then
        if i == #es then 
          es[i].pos = dur
        else
          es[i].pos = min(dur, es[i+1].pos)
        end
        pitchLastStart[es[i].pitch] = nil
      end
      -- print(tostring(es[i].pos) .. " " .. tostring(es[i].status))
      ::continue::
      -- table.insert(events, es[i])
    end
  end
  
  -- local last = events[#events]
  -- table.remove(events, #events) -- 排除 All-Note-Off 事件
  -- table.sort(events,function(a,b)
  --     if a.pos == b.pos then
  --         if a.status == b.status then
  --             return a.pitch < b.pitch
  --         end
  --         return a.status < b.status
  --     end
  --     return a.pos < b.pos
  -- end)
  -- table.insert(events, last)

  setAllEvents(take, events)
  reaper.MIDI_Sort(take)

  if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDI)
    reaper.ShowMessageBox("The script caused event position displacement, original MIDI data has been restored.", "Error", 0)
  end
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getTakes) do
  endTime(take)
end
reaper.Undo_EndBlock("Set Note Ends to Edit Cursor", -1)
reaper.UpdateArrange()