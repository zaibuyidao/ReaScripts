-- @description Insert Pitch Bend (Semitone)
-- @version 1.4.1
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

local pitch = reaper.GetExtState("InsertPitchBendSemitone", "Pitch")
if (pitch == "") then pitch = "0" end
local range = reaper.GetExtState("InsertPitchBendSemitone", "Range")
if (range == "") then range = "12" end
local uok, uinput = reaper.GetUserInputs('Insert Pitch Bend', 2, 'Semitone (0=Reset),Pitch Range', pitch ..','.. range)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, range = uinput:match("(.*),(.*)")
if not tonumber(pitch) or not tonumber(range) then return reaper.SN_FocusMIDIEditor() end
pitch, range = tonumber(pitch), tonumber(range)

if pitch > 12 or pitch < -12 then
  return reaper.MB("請輸入一個介於 -12 到 12 之間的值", "錯誤", 0), reaper.SN_FocusMIDIEditor()
end

if pitch > range then
  return reaper.MB("彎音間隔不能大於彎音範圍", "錯誤", 0), reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("InsertPitchBendSemitone", "Pitch", pitch, false)
reaper.SetExtState("InsertPitchBendSemitone", "Range", range, false)

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

reaper.Undo_BeginBlock()
local seg = getSegments(range)

if pitch > 0 then
  pitchbend = pitchUp(pitch, seg)
else
  pitchbend = pitchDown(pitch, seg)
end

LSB = pitchbend & 0x7F
MSB = (pitchbend >> 7) + 64

reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock("Insert Pitch Bend (Semitone)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()