-- @description Slide In
-- @version 1.4.3
-- @author zaibuyidao
-- @changelog Optimised pitch bend
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
if loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end

local pitch = reaper.GetExtState("SlideIn", "Pitch")
if (pitch == "") then pitch = "-7" end
local range = reaper.GetExtState("SlideIn", "Range")
if (range == "") then range = "12" end
local bezier = reaper.GetExtState("SlideIn", "Bezier")
if (bezier == "") then bezier = "20" end
local toggle = reaper.GetExtState("SlideIn", "Toggle")
if (toggle == "") then toggle = "2" end

uok, uinput = reaper.GetUserInputs("Slide In", 4, "Pitch interval 彎音間隔,Pitch Range 彎音範圍,Bezier 貝塞爾 (-100,100),0=SMO 1=LIN 2=FRE 3=REV", pitch ..','.. range ..','.. bezier ..','.. toggle)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, range, bezier, toggle = uinput:match("(.*),(.*),(.*),(.*)")

if not tonumber(pitch) or not tonumber(range) or not tonumber(bezier) or not tonumber(toggle) or tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 or tonumber(bezier) < -100 or tonumber(bezier) > 100 or tonumber(toggle) > 3 then
  return reaper.SN_FocusMIDIEditor()
end

pitch, range, bezier, toggle = tonumber(pitch), tonumber(range),tonumber(bezier), tonumber(toggle)

reaper.SetExtState("SlideIn", "Pitch", pitch, false)
reaper.SetExtState("SlideIn", "Range", range, false)
reaper.SetExtState("SlideIn", "Bezier", bezier, false)
reaper.SetExtState("SlideIn", "Toggle", toggle, false)

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

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
    return targets[p + (range + 1)]
  end
end

local function set_cc_shape(take, bezier, shape)
  local i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

reaper.Undo_BeginBlock()
if toggle == 0 then
  local seg = getSegments(range)
  if pitch > 0 then
    pitchbend = pitchUp(pitch, seg)
  else
    pitchbend = pitchDown(pitch, seg)
  end

  LSB = pitchbend & 0x7F
  MSB = (pitchbend >> 7) + 64
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, LSB, MSB)
  set_cc_shape(take, bezier, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64) -- 在LOOP结尾插入弯音值归零
elseif toggle == 1 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchDown(math.abs(pitch)-i, seg)
    else
      pitchbend = pitchUp(i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + (loop_end-loop_start) * (i/(math.abs(pitch))), 224, 0, LSB, MSB)
  end
elseif toggle == 2 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchDown(math.abs(pitch)-i, seg)
    else
      pitchbend = pitchUp(i-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_start + (loop_end-loop_start) * ((i+i)/(math.abs(pitch)+i)), 224, 0, LSB, MSB)
  end
elseif toggle == 3 then
  for i = 0, math.abs(pitch) do
    local seg = getSegments(range)
    if pitch > 0 then
      pitchbend = pitchUp((i-math.abs(pitch))+math.abs(pitch), seg)
    else
      pitchbend = pitchDown((math.abs(pitch)-i)-math.abs(pitch), seg)
    end

    LSB = pitchbend & 0x7F
    MSB = (pitchbend >> 7) + 64
    reaper.MIDI_InsertCC(take, false, false, loop_end + (loop_end-loop_start) * ((i+i)/-(math.abs(pitch)+i)), 224, 0, LSB, MSB)
  end
end
reaper.Undo_EndBlock("Slide In", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()