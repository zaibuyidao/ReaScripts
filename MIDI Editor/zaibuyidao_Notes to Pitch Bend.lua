-- @description Notes to Pitch Bend
-- @version 1.0.10
-- @author zaibuyidao
-- @changelog
--   Optimized the logic for inserting the final pitch bend reset (value 0).
--   Added mode selection:
--     1. Set selected notes to the target channel and mute them.
--     2. Delete selected notes.
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Pitch Bend Script Series, filter "zaibuyidao pitch bend" in ReaPack or Actions to access all scripts.
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

-- Configuration Section -----------------------------
local range            = 12   -- Pitch bend range in semitones (±12 semitones)
local auto_switch_lane = true -- Set to false to preserve the user's original CC lane
local mode             = 1    -- 1 = Move selected notes to target channel; 2 = Delete selected notes
local target_chan      = 1    -- Target MIDI channel (0-15), default is 1 (which means Channel 2, since MIDI channels are zero-based)
------------------------------------------------------

local language         = getSystemLanguage() -- Detect the system language to display messages in Chinese or English
local title, err_title, err_msg1, err_msg2
if language == "简体中文" then
  title = "音符转弯音"
  err_title = "错误"
  err_msg1 = "请检查音符间隔，并将其限制在一个八度内"
  err_msg2 = "请选择两个或更多音符"
elseif language == "繁體中文" then
  title = "音符轉彎音"
  err_title = "錯誤"
  err_msg1 = "請檢查音符間隔，並將其限制在一個八度内"
  err_msg2 = "請選擇兩個或更多音符"
else
  title = "Notes to Pitch Bend"
  err_title = "Error"
  err_msg1 = "Please check the note interval and limit it to one octave."
  err_msg2 = "Please select two or more notes."
end

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= -1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

-- 插值表
function getSegments(n)
  local x = 8192
  local p = math.floor((x / n) + 0.5) -- 四舍五入
  local arr = {}
  local cur = 0
  for i = 1, n do
    cur = cur + p
    table.insert(arr, math.min(cur, x))
  end
  local res = {}
  for i = #arr, 1, -1 do
    table.insert(res, -arr[i])
  end
  table.insert(res, 0)
  for i = 1, #arr do
    table.insert(res, arr[i])
  end
  res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
  return res
end

local function pitchUp(o, targets)
  return targets[o + (range + 1)]
end

local function pitchDown(p, targets)
  return targets[p + (range + 1)]
end

local function DeselectAllPitchBendCC(take)
  local _, _, cc_cnt, _ = reaper.MIDI_CountEvts(take)
  for i = 0, cc_cnt - 1 do
    local retval, selected, muted, ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if chanmsg == 224 and selected then
      reaper.MIDI_SetCC(take, i, false, muted, ppq, chanmsg, chan, msg2, msg3)
    end
  end
end

function RemoveConsecutiveZeroPitchBends(take)
  if not take then return end

  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= -1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  local idx = -1
  local lastWasZero = false

  reaper.MIDI_DisableSort(take)

  for i = 1, #index do
    index[i] = reaper.MIDI_EnumSelCC(take, idx)
    local _, _, _, _, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    if chanmsg == 224 then
      local pitchbend = msg2 + msg3 * 128
      if pitchbend == 8192 then
        if lastWasZero then
          reaper.MIDI_DeleteCC(take, index[i])
        else
          lastWasZero = true
          idx = index[i]
        end
      else
        lastWasZero = false
        idx = index[i]
      end
    else
      idx = index[i]
    end
  end

  reaper.MIDI_Sort(take)
end

function CleanAndInsertPitchBendReset(take, max_endppq)
  -- 收集所有选中的 pitch bend
  local pb = {}  -- {idx, ppq, value}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= -1 do
    local _, _, _, ppq, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, val)
    if chanmsg == 224 then
      table.insert(pb, {idx = val, ppq = ppq, value = msg2 + msg3 * 128})
    end
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  -- reaper.ShowConsoleMsg("---- 原始选中弯音 ----\n")
  -- for i, v in ipairs(pb) do
  --   reaper.ShowConsoleMsg(string.format("idx=%d, ppq=%.2f, value=%d\n", v.idx, v.ppq, v.value))
  -- end

  -- if #pb == 0 then
  --   reaper.ShowConsoleMsg("无选中弯音，结束处理。\n")
  --   return
  -- end

  -- 按 ppq 升序排序
  table.sort(pb, function(a, b) return a.ppq < b.ppq end)

  -- 找到最后一段连续0的起点
  local last_nonzero = #pb
  while last_nonzero > 0 and pb[last_nonzero].value == 8192 do
    last_nonzero = last_nonzero - 1
  end

  -- 是否需要插入归零
  if pb[#pb].value ~= 8192 then
    -- reaper.ShowConsoleMsg(string.format(">> 最后一个弯音不是归零，插入归零到 ppq=%.2f\n", max_endppq))
    reaper.MIDI_InsertCC(take, true, false, max_endppq, 224, 0, 0, 64)
    local _, _, new_cc_cnt, _ = reaper.MIDI_CountEvts(take)
    reaper.MIDI_SetCCShape(take, new_cc_cnt - 1, 0, 0, false)
  else
    -- reaper.ShowConsoleMsg(">> 最后一个弯音已归零，无需插入归零\n")
  end
end

local pitch, startppqpos, endppqpos, vel = {}, {}, {}, {}
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_grid, swing = reaper.MIDI_GetGrid(take)
local tick_grid = midi_tick * cur_grid

-- 插入弯音设置形状
local function insertUniquePitchBend(ppq, LSB, MSB, shape_type)
  shape_type = shape_type or 0 -- 默认线性
  -- 插入新的 pitch bend 事件
  reaper.MIDI_InsertCC(take, true, false, ppq, 224, 0, LSB, MSB)
  -- 获取插入后的事件索引
  local _, _, new_cc_cnt, _ = reaper.MIDI_CountEvts(take)
  local last_idx = new_cc_cnt - 1
  -- 设置该事件的形状
  reaper.MIDI_SetCCShape(take, last_idx, shape_type, 0, false)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if #index > 1 then
  local note_events = {}
  local notes = {}
  
  for i = 1, #index do
    local retval, selected, m, s_ppq, e_ppq, c, p, v = reaper.MIDI_GetNote(take, index[i])
    if selected then
      table.insert(notes, {
        i = i,
        s = s_ppq,
        e = e_ppq,
        pitch = p,
        chan = c,
        vel = v,
        muted = m,
      })
      note_events[#note_events + 1] = {ppq = s_ppq, type = "on", idx = i}
      note_events[#note_events + 1] = {ppq = e_ppq, type = "off", idx = i}
    end
  end
  
  table.sort(note_events, function(a, b)
    if a.ppq ~= b.ppq then
      return a.ppq < b.ppq
    elseif a.type ~= b.type then
      -- 先 off 再 on (off < on)
      return a.type == "off"
    else
      return false
    end
  end)
  
  local active_notes = {}
  local prev_pitch = nil
  local prevLSB, prevMSB = 0, 64
  local seg = getSegments(range)
  local max_endppq = 0
  local chan, muted
  
  local is_first_event = true
  
  for _, e in ipairs(note_events) do
    local n = notes[e.idx]
    if e.type == "on" then
      active_notes[#active_notes + 1] = n
      if n.e > (max_endppq or 0) then max_endppq = n.e end
    elseif e.type == "off" then
      -- 移除
      for j = #active_notes, 1, -1 do
        if active_notes[j].i == e.idx then
          table.remove(active_notes, j)
          break
        end
      end
    end

    -- 当前最上层音符, 永远是active_notes最后一个
    local main_note = active_notes[#active_notes]
    local main_pitch = main_note and main_note.pitch or prev_pitch
  
    if is_first_event then
      -- 首事件不插弯音
      is_first_event = false
      prev_pitch = main_pitch
    else
      if main_note then
        -- 计算bend到的音高
        local bend_val = main_pitch - notes[1].pitch
        local pitchbend = bend_val > 0 and pitchUp(bend_val, seg) or pitchDown(bend_val, seg)
        local LSB = pitchbend & 0x7F
        local MSB = (pitchbend >> 7) + 64
        insertUniquePitchBend(e.ppq, LSB, MSB, 0)
        prevLSB, prevMSB = LSB, MSB
        prev_pitch = main_pitch
      else
        -- 没有音符时归零
        -- insertUniquePitchBend(e.ppq, 0, 64, 0)
        prevLSB, prevMSB = 0, 64
        prev_pitch = nil
      end
    end
  end

  if mode == 1 then
    for i = 1 , #notes do
      local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
      for i = 0, noteCount - 1 do
        local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        if selected then
          reaper.MIDI_SetNote(take, i, false, true, nil, nil, target_chan, nil, nil, false)
        end
      end
    end
  elseif mode == 2 then
    -- 删除所有选中音符
    for i = #notes, 1, -1 do
      reaper.MIDI_DeleteNote(take, notes[i])
    end
  end

  -- 删除所有选中音符 v2
  -- j = reaper.MIDI_EnumSelNotes(take, -1)
  -- while j > -1 do
  --   reaper.MIDI_DeleteNote(take, j)
  --   j = reaper.MIDI_EnumSelNotes(take, -1)
  -- end
  
  -- 插入延长的主音符
  local first = notes[1]
  if first then
    reaper.MIDI_InsertNote(take, true, first.muted or false, first.s, max_endppq, first.chan, first.pitch, first.vel, true)
  end
  -- insertUniquePitchBend(max_endppq, 0, 64, 0) -- 在最后位置插入归零
  CleanAndInsertPitchBendReset(take, max_endppq)
  -- RemoveConsecutiveZeroPitchBends(take)
  DeselectAllPitchBendCC(take)
else
  reaper.MB(err_msg2, err_title, 0)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
if auto_switch_lane then
  reaper.MIDIEditor_OnCommand(editor, 40366) -- CC: Set CC lane to Pitch
end