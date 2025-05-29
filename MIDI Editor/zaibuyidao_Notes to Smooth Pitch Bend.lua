-- @description Notes to Smooth Pitch Bend
-- @version 1.0.4
-- @author zaibuyidao
-- @changelog
--   Optimized the logic for inserting the final pitch bend reset (value 0).
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

local language         = getSystemLanguage() -- Detect the system language to display messages in Chinese or English
local range            = 12                  -- Pitch bend range in semitones (±12 semitones)
local auto_switch_lane = true                -- Set to false to preserve the user's original CC lane
local grid_scale       = 1                   -- User-adjustable factor: 1 = normal grid spacing, 0.5 = half spacing (denser interpolation)
local offset_factor    = 0                   -- Pitch bend insertion offset factor: 0 = no offset, 1 = offset by one grid unit, 0.5 = offset by half a grid.

local title, err_title, err_msg1, err_msg2
if language == "简体中文" then
  title = "音符转平滑弯音"
  err_title = "错误"
  err_msg1 = "请检查音符间隔，并将其限制在一个八度内"
  err_msg2 = "请选择两个或更多音符"
elseif language == "繁體中文" then
  title = "音符轉平滑彎音"
  err_title = "錯誤"
  err_msg1 = "請檢查音符間隔，並將其限制在一個八度内"
  err_msg2 = "請選擇兩個或更多音符"
else
  title = "Notes to Smooth Pitch Bend"
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
  reaper.MIDI_DisableSort(take)
  local _, _, cc_cnt, _ = reaper.MIDI_CountEvts(take)
  local del = {}
  local lastWasZero = false

  -- 收集pitch bend 0的顺序
  local pb_idx = {}
  for i = 0, cc_cnt - 1 do
    local _, _, _, _, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if chanmsg == 224 then
      local pitchbend = msg2 + msg3 * 128
      table.insert(pb_idx, {idx = i, val = pitchbend})
    end
  end

  -- 找到所有连续的8192, 并记录要删的index
  for i = 2, #pb_idx do
    if pb_idx[i].val == 8192 and pb_idx[i-1].val == 8192 then
      table.insert(del, pb_idx[i].idx)
    end
  end

  table.sort(del, function(a, b) return a > b end)
  for _, idx in ipairs(del) do
    reaper.MIDI_DeleteCC(take, idx)
  end

  reaper.MIDI_Sort(take)
end

local pitch, startppqpos, endppqpos, vel = {}, {}, {}, {}
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_grid, swing = reaper.MIDI_GetGrid(take)
local tick_grid = midi_tick * cur_grid * grid_scale

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
      return a.type == "off"
    else
      return false
    end
  end)

  local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  local cur_grid, swing = reaper.MIDI_GetGrid(take)
  local tick_grid = midi_tick * cur_grid * grid_scale

  -- 从头到尾扫描所有事件, 找出每个时间点的主音pitch
  local event_bendpoints = {}
  local active_notes = {}
  local prev_pitch = nil

  for _, e in ipairs(note_events) do
    local n = notes[e.idx]
    if e.type == "on" then
      active_notes[#active_notes + 1] = n
    elseif e.type == "off" then
      for j = #active_notes, 1, -1 do
        if active_notes[j].i == e.idx then
          table.remove(active_notes, j)
          break
        end
      end
    end
    local main_note = active_notes[#active_notes]
    local main_pitch = main_note and main_note.pitch or nil
    table.insert(event_bendpoints, {ppq = e.ppq, pitch = main_pitch})
  end

  -- 找出所有音高变化的事件点索引
  local pitch_change_indices = {}
  local prev_pitch = nil
  for i, ev in ipairs(event_bendpoints) do
    if i == 1 then
      prev_pitch = ev.pitch
    else
      if ev.pitch ~= prev_pitch then
        table.insert(pitch_change_indices, i)
      end
      prev_pitch = ev.pitch
    end
  end

  -- 插入弯音事件, 最后一个变换点不加平滑
  local seg = getSegments(range)
  local first_note_pitch = notes[1].pitch
  prev_pitch = nil

  for i, ev in ipairs(event_bendpoints) do
    if i == 1 then
      prev_pitch = ev.pitch
      -- 首事件不插弯音
    else
      local is_pitch_change = false
      for _, idx in ipairs(pitch_change_indices) do
        if idx == i then
          is_pitch_change = true
          break
        end
      end
      local is_last_pitch_change = (i == pitch_change_indices[#pitch_change_indices])

      if is_pitch_change and not is_last_pitch_change then
        -- 1. 平滑点: 非最后一个音高变换点才加
        local insert_ppq = ev.ppq - tick_grid + (tick_grid * offset_factor)
        if prev_pitch ~= nil and insert_ppq >= 0 then
          local bend_val_prev = prev_pitch - first_note_pitch
          local pb_prev = bend_val_prev > 0 and pitchUp(bend_val_prev, seg) or pitchDown(bend_val_prev, seg)
          local LSB_prev = pb_prev & 0x7F
          local MSB_prev = (pb_prev >> 7) + 64
          insertUniquePitchBend(insert_ppq, LSB_prev, MSB_prev, 1)
        end
      end
      -- 2. 正常点: 插入当前音的弯音
      if ev.pitch ~= nil then
        local bend_val = ev.pitch - first_note_pitch
        local pitchbend = bend_val > 0 and pitchUp(bend_val, seg) or pitchDown(bend_val, seg)
        local LSB = pitchbend & 0x7F
        local MSB = (pitchbend >> 7) + 64
        insertUniquePitchBend(ev.ppq + (tick_grid * offset_factor), LSB, MSB, 0)
      end
      prev_pitch = ev.pitch
    end
  end

  -- 删除所有选中音符
  for i = #index, 1, -1 do
    reaper.MIDI_DeleteNote(take, index[i])
  end

  -- 插入延长的主音符
  local first = notes[1]
  local max_endppq = 0
  for _, n in ipairs(notes) do
    if n.e > max_endppq then max_endppq = n.e end
  end
  if first then
    reaper.MIDI_InsertNote(take, true, first.muted or false, first.s, max_endppq, first.chan, first.pitch, first.vel, true)
  end
  -- insertUniquePitchBend(max_endppq, 0, 64, 0) -- 在最后位置插入归零

  -- 如果提前归零，则不用再最好位置归零。
  local last_sel_ppq = nil
  local last_sel_val = nil
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= -1 do
    local _, _, _, ppq, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, val)
    if chanmsg == 224 then
      if (not last_sel_ppq) or (ppq > last_sel_ppq) then
        last_sel_ppq = ppq
        last_sel_val = msg2 + msg3 * 128
      end
    end
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  -- print(string.format("last_sel_ppq = %.2f, last_sel_val = %d\n", last_sel_ppq or -1, last_sel_val or -1))
  -- if not (last_sel_val and last_sel_val == 8192) then
  --   print(">> 插入归零 pitch bend\n")
  --   insertUniquePitchBend(max_endppq, 0, 64, 0)
  -- else
  --   print(">> 不插入归零\n")
  -- end

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