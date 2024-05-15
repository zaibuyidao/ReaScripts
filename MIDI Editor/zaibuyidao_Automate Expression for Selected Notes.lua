-- @description Automate Expression for Selected Notes
-- @version 1.0
-- @author zaibuyidao, YS
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   This script is used to automate the expression of selected notes in REAPER by inserting Control Change (CC) messages into the MIDI data of the notes.
--   The script automatically inserts CC messages based on the length and position of the notes at specified intervals, thereby automating the dynamic expression of the notes.
--   Requires JS_ReaScriptAPI & SWS Extension

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
if not checkMidiNoteSelected() then return end

-- dangguidan的速度代码优化版
function bpm_average()
  local minPPQ = math.huge
  local maxPPQ = -1
  local editor = reaper.MIDIEditor_GetActive()

  if not editor then
    reaper.ShowMessageBox("No active MIDI editor found.", "Error", 0)
    return
  end

  local takeIndex = 0
  local take = reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)
  local validTake = nil  -- 用于存储最后一个有效的 take

  while take do
    reaper.MIDI_DisableSort(take)
    local noteIndex = -1
    local note = reaper.MIDI_EnumSelNotes(take, noteIndex)
    while note ~= -1 do
      local _, _, _, startPPQ, endPPQ = reaper.MIDI_GetNote(take, note)
      minPPQ = math.min(minPPQ, startPPQ)
      maxPPQ = math.max(maxPPQ, endPPQ)
      noteIndex = note
      note = reaper.MIDI_EnumSelNotes(take, noteIndex)
    end
    reaper.MIDI_Sort(take)

    validTake = take  -- 更新最后一个有效的 take
    takeIndex = takeIndex + 1
    take = reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)
  end

  if not validTake or maxPPQ == -1 then
    reaper.ShowMessageBox("No valid take or selected notes found.", "Error", 0)
    return
  end

  local firstQN = reaper.MIDI_GetProjQNFromPPQPos(validTake, minPPQ)
  local endTime = reaper.MIDI_GetProjTimeFromPPQPos(validTake, maxPPQ)

  local totalBPM = 0
  local qnCount = 0
  local pos = reaper.TimeMap_QNToTime(firstQN)
  local ptIdx = reaper.FindTempoTimeSigMarker(0, pos)
  local retval, _, _, _, bpm = reaper.GetTempoTimeSigMarker(0, ptIdx)

  if bpm == 0 then
    bpm = reaper.Master_GetTempo()  -- 直接获取工程的全局BPM
  end

  while pos < endTime do
    totalBPM = totalBPM + bpm
    qnCount = qnCount + 1
    firstQN = firstQN + 1
    pos = reaper.TimeMap_QNToTime(firstQN)
    ptIdx = reaper.FindTempoTimeSigMarker(0, pos)
    retval, _, _, _, bpm = reaper.GetTempoTimeSigMarker(0, ptIdx)

    if bpm == 0 then
      bpm = reaper.Master_GetTempo()  -- 如果标尺上没有速度变化，使用全局BPM
    end
  end

  local averageBPM = totalBPM / qnCount
  return averageBPM
end

bpm_average = bpm_average()

-- 直线模式
function linear_mapper(from, to, width)
  local k = (to - from) / width
  return function (x, y)
    return from + x * k
  end
end

-- 圆弧形模式
function arc_mapper(from, to, width)
  return function (x, y)
    if from > to then
      return to + (from - to) * math.sqrt(1 - (x / width) ^ 2)
    end
    x = width - x
    return from + (to - from) * math.sqrt(1 - (x / width) ^ 2)
  end
end

-- 获取线性映射器
function get_linear_mapper(fromL, fromR, toL, toR)
  local fromW = fromR - fromL
  local toW = toR - toL
  return function (x)
    return toL + (((x - fromL) / fromW) * toW)
  end
end

-- 旧代码，只是备用
-- function compress_builder(builder, percent)
--   if percent == 0.5 then
--     return function (from, to, width)
--       local linear_func = linear_mapper(from, to, width)
--       return function (x, y)
--         return linear_func(x, y)
--       end
--     end
--   else
--     return function (from, to, width)
--       local l, r = width * percent, width - width * percent
--       local func = builder(from, to, width)
--       local x_mapper = get_linear_mapper(0, width, l, r)
--       local y_mapper = get_linear_mapper(func(l), func(r), func(0), func(width))
--       return function (x, y)
--         return y_mapper(func(x_mapper(x), y))
--       end
--     end
--   end
-- end

-- 压缩生成器
function compress_builder(builder, percent)
  if percent == 0.5 then
    return function (from, to, width)
      --print("Using linear mapper for percent = 0.5\n")
      local linear_func = linear_mapper(from, to, width)
      return function (x, y)
        return linear_func(x, y)
      end
    end
  else
    return function (from, to, width)
      --print(string.format("Using arc mapper with percent = %.2f\n", percent))
      local l = width * percent
      local r = width - l
      local func = builder(from, to, width)
      local x_mapper = get_linear_mapper(0, width, l, r)
      local y_mapper = get_linear_mapper(func(l), func(r), from, to)
      return function (x, y)
        local mapped_x = x_mapper(x)
        local mapped_y = func(mapped_x, y)
        return y_mapper(mapped_y)
      end
    end
  end
end

-- 根据模式选择映射函数
function select_mapper(mode, percent)
  if mode == 2 then
    --print("Using arc mapper mode\n")
    return compress_builder(arc_mapper, percent or 1)
  else
    --print("Using linear mapper mode\n")
    return linear_mapper
  end
end

function autoExp(take, mode, bezier_in, bezier_out)
  mode = mode or 1  -- 默认模式为1（直线）
  local mapper_builder = select_mapper(mode, 0)
  local flag = 0
  local quaver = false
  local minmin = min_val -- 确保最小值是用户输入的值
  local minmin2 = math.modf(min_val + ((max_val - min_val) / 3)) -- 偏移最小值

  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      ppq_len = endppqpos[i] - startppqpos[i]
      
      if speed == 1 then
        if ppq_len >= tick/2 and ppq_len < tick then -- 大于等于 240 并且 小于 480
          local mapper_builder = select_mapper(mode, bezier_in) -- 弧线模式，无压缩
          
          local func = mapper_builder(min_val, max_val, math.floor(tick * 0.4))
          for k = 0, tick * 0.4, tick_interval do
            local cc_val = math.floor(func(k, 0))
            reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i] + k, 0xB0, chan, cc_number, cc_val)
          end

          if quaver == false then
            min_val = math.modf(min_val + ((max_val - min_val) / 3))
            quaver = true
          end
        else
          quaver = false
          min_val = minmin2
        end

        if ppq_len > 0 and ppq_len < tick/2 then -- 大于 0 并且 小于 240
          if flag == 0 then
            reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_number, max_val)
            flag = 1
          end
        else
          flag = 0
        end
      elseif speed == 3 then
        if bpm_average < 96 then
          if ppq_len >= tick/2 and ppq_len < tick then -- 大于等于 240 并且 小于 480
            local mapper_builder = select_mapper(mode, bezier_in) -- 弧线模式，无压缩
            local func = mapper_builder(min_val, max_val, math.floor(tick * 0.4))
            for k = 0, tick * 0.4, tick_interval do
              local cc_val = math.floor(func(k, 0))
              reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i] + k, 0xB0, chan, cc_number, cc_val)
            end
  
            if quaver == false then
              min_val = math.modf(min_val + ((max_val - min_val) / 3))
              quaver = true
            end
          else
            quaver = false
            min_val = minmin2
          end
        end
        if bpm_average < 96 then dur = tick/2 else dur = tick end
        if ppq_len > 0 and ppq_len < dur then -- 大于 0 并且 小于 240
          if flag == 0 then
            reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_number, max_val)
            flag = 1
          end
        else
          flag = 0
        end
      else
        if ppq_len > 0 and ppq_len < tick then -- 大于 0 并且 小于 480 (快速,最小音符采用 480)
          if flag == 0 then
            reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_number, max_val)
            flag = 1
          end
        else
          flag = 0
        end
      end

      if ppq_len >= tick and ppq_len < tick*2 then -- 大于等于 480 并且 小于960
        min_val = minmin
        local mapper_builder = select_mapper(mode, bezier_in) -- 弧线模式，无压缩
        local func = mapper_builder(min_val, max_val, math.floor(tick * 0.75))
        for k = 0, tick * 0.75, tick_interval do
          local cc_val = math.floor(func(k, 0))
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i] + k, 0xB0, chan, cc_number, cc_val)
        end
      elseif ppq_len == tick*2 then -- 等于 960
        min_val = minmin
        local mapper_builder = select_mapper(mode, bezier_in) -- 弧线模式，无压缩
        local func = mapper_builder(min_val, max_val, tick)
        for k = 0, tick, tick_interval do
          local cc_val = math.floor(func(k, 0))
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i] + k, 0xB0, chan, cc_number, cc_val)
        end
      elseif ppq_len > tick*2 then -- 大于 960
        min_val = minmin
        local mapper_builder = select_mapper(mode, bezier_in) -- 弧线模式，无压缩
        local func = mapper_builder(min_val, max_val, math.floor(tick * 1.5))
        for k = 0, tick * 1.5, tick_interval do
          local cc_val = math.floor(func(k, 0))
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i] + k, 0xB0, chan, cc_number, cc_val)
        end
      end
      if ppq_len >= tick*2 then -- 大于等于 960, 插入减弱表情，从最大值开始递减
        min_val = minmin
        local mapper_builder = select_mapper(mode, bezier_out) -- 弧线模式，无压缩
        local func = mapper_builder(max_val, math.modf(((max_val-min_val)/max_val)*65) + min_val, math.floor(tick * 0.75 + 0.5)-20) -- 最小值特殊处理. tick*0.75减去20 同步缩短插入范围
        for k = 0, tick*0.75-20, tick_interval do -- tick*0.75减去20 缩短插入范围
          local cc_val = math.floor(func(k, 0))
          reaper.MIDI_InsertCC(take, selected, muted, endppqpos[i] - tick*0.75 + k, 0xB0, chan, cc_number, cc_val)
        end
      end
    end

    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

if language == "简体中文" then
  title = "自动表情 (平均速度: " .. bpm_average ..")"
  captions_csv = "CC编号,最小值,最大值,速度 (1=慢速 2=快速 3=自动),开始弧度 (0 至 1),结束弧度 (0 至 1),嘀嗒间隔,extrawidth=5"
elseif language == "繁体中文 " then
  title = "自動表情 (平均速度: " .. bpm_average ..")"
  captions_csv = "CC編號,最小值,最大值,速度 (1=慢速 2=快速 3=自動),開始弧度 (0 至 1),結束弧度 (0 至 1),嘀嗒間隔,extrawidth=5"
else
  title = "Automate Expression (Average Speed: " .. bpm_average ..")"
  captions_csv = "CC Number,Minimum,Maximum,Speed (1=Slow 2=Fast 3=Auto),Bezier In (0 to 1),Bezier Out (0 to 1),Intervals (tick),extrawidth=5"
end

cc_number = reaper.GetExtState("AutomateExpressionforSelectedNotes", "CC")
if (cc_number == "") then cc_number = "11" end
min_val = reaper.GetExtState("AutomateExpressionforSelectedNotes", "MinVal")
if (min_val == "") then min_val = "88" end
max_val = reaper.GetExtState("AutomateExpressionforSelectedNotes", "MaxVal")
if (max_val == "") then max_val = "127" end
speed = reaper.GetExtState("AutomateExpressionforSelectedNotes", "Speed")
if (speed == "") then speed = "3" end
bezier_in = reaper.GetExtState("AutomateExpressionforSelectedNotes", "BezierIn")
if (bezier_in == "") then bezier_in = "0.15" end
bezier_out = reaper.GetExtState("AutomateExpressionforSelectedNotes", "BezierOut")
if (bezier_out == "") then bezier_out = "0.1" end
tick_interval = reaper.GetExtState("AutomateExpressionforSelectedNotes", "TickInterval")
if (tick_interval == "") then tick_interval = "10" end

local uok, uinput_csv = reaper.GetUserInputs(title, 7, captions_csv, cc_number ..','..min_val ..','.. max_val ..','.. speed ..','..bezier_in ..','.. bezier_out ..','.. tick_interval)
if not uok then return reaper.SN_FocusMIDIEditor() end
cc_number, min_val, max_val, speed, bezier_in, bezier_out, tick_interval = uinput_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_number) or not tonumber(min_val) or not tonumber(max_val)  or not tonumber(speed) or not tonumber(bezier_in) or not tonumber(bezier_out) or not tonumber(tick_interval) then return reaper.SN_FocusMIDIEditor() end
cc_number, min_val, max_val, speed, bezier_in, bezier_out, tick_interval = tonumber(cc_number), tonumber(min_val), tonumber(max_val), tonumber(speed), tonumber(bezier_in), tonumber(bezier_out), tonumber(tick_interval)

if bezier_in > 1 or bezier_in < 0 then return end
if bezier_out > 1 or bezier_out < 0 then return end

reaper.SetExtState("AutomateExpressionforSelectedNotes", "CC", cc_number, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "MinVal", min_val, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "MaxVal", max_val, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "Speed", speed, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "BezierIn", bezier_in, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "BezierOut", bezier_out, false)
reaper.SetExtState("AutomateExpressionforSelectedNotes", "TickInterval", tick_interval, false)

local note_starts = {}
for take, _ in pairs(getTakes) do
  local i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected then
      table.insert(note_starts, startppqpos)
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

if #note_starts > 0 then
  local first_pos = math.min(table.unpack(note_starts))
  local last_pos = math.max(table.unpack(note_starts))
  width = last_pos - first_pos
end

tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
startppqpos = {} -- 音符开头位置
endppqpos = {} -- 音符尾巴位置
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

for take, _ in pairs(getTakes) do
  reaper.MIDI_DisableSort(take)
  autoExp(take, 2, bezier_in, bezier_out) -- 使用模式2（弧线模式）

  j = reaper.MIDI_EnumSelCC(take, -1)
  while j ~= -1 do
    --reaper.MIDI_SetCCShape(take, j, 1, 0, false) -- 不设置形状
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
    j = reaper.MIDI_EnumSelCC(take, j)
  end
  
  reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()