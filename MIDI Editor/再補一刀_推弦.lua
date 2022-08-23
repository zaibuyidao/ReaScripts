-- @description 推弦
-- @version 1.0
-- @author 再補一刀
-- @changelog 首次发布
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

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

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_end <= loop_start then return reaper.SN_FocusMIDIEditor() end
local loop_len = loop_end - loop_start

local interval = reaper.GetExtState("Bend", "Interval")
if (interval == "") then interval = "2" end
local bend_range = reaper.GetExtState("Bend", "PitchRange")
if (bend_range == "") then bend_range = "2" end
local toggle = reaper.GetExtState("Bend", "Toggle")
if (toggle == "") then toggle = "0" end

uok, uinput = reaper.GetUserInputs("推弦", 3, "彎音間隔,彎音範圍,0=保持 1=立即 2=反向", interval ..','.. bend_range ..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
interval, bend_range, toggle = uinput:match("(.*),(.*),(.*)")

interval, bend_range, toggle = tonumber(interval), tonumber(bend_range), tonumber(toggle)

if interval > bend_range then
  return reaper.MB("彎音間隔不能大於彎音範圍", "錯誤", 0), reaper.SN_FocusMIDIEditor()
end

if bend_range < -12 or bend_range > 12 or bend_range == 0 or toggle > 3 or toggle < 0 then
  return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("Bend", "Interval", interval, false)
reaper.SetExtState("Bend", "PitchRange", bend_range, false)
reaper.SetExtState("Bend", "Toggle", toggle, false)

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

local seg = getSegments(bend_range)

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (bend_range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
      return targets[p + (bend_range + 1)]
  end
end

local function set_cc_shape(take, bezier, shape)
  i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

if interval > 0 then
  pitch = pitchUp(interval, seg)
else
  pitch = pitchDown(interval, seg)
end

LSB = pitch & 0x7F
MSB = (pitch >> 7) + 64

reaper.Undo_BeginBlock()
if toggle == 0 then
  local p1 = loop_start + loop_len*0.25
  local p2 = loop_start + loop_len*0.75
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, 75, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 1 then
  local p1 = loop_start + loop_len*0.49
  local p2 = loop_start + loop_len*0.51
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, -50, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif toggle == 2 then
  local p1 = loop_start + loop_len*0.125
  local p2 = loop_start + loop_len*0.25
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, -70, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, -10, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
else
  return
end
reaper.Undo_EndBlock("推弦", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()