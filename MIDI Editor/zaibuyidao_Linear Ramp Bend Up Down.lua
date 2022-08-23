-- @description Linear Ramp Bend Up/Down
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   1. Requires SWS Extensions
--   2. Within Time Selection

step = 128
selected = true
muted = false
chan = 0

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
if take == nil then return end
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_end <= loop_start then return reaper.SN_FocusMIDIEditor() end
local loop_len = loop_end - loop_start
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)

local bend_start = reaper.GetExtState("Bend", "Start")
if (bend_start == "") then bend_start = "0" end
local bend_end = reaper.GetExtState("Bend", "End")
if (bend_end == "") then bend_end = "1408" end

local uok, uinput = reaper.GetUserInputs("Linear Ramp Bend Up/Down", 2, "Start,End", bend_start..','..bend_end)
if not uok then return reaper.SN_FocusMIDIEditor() end
bend_start, bend_end = uinput:match("(.*),(.*)")
if not tonumber(bend_start) or not tonumber(bend_end) then return reaper.SN_FocusMIDIEditor() end
bend_start, bend_end = tonumber(bend_start), tonumber(bend_end)

reaper.SetExtState("Bend", "Start", bend_start, false)
reaper.SetExtState("Bend", "End", bend_end, false)

if bend_start < -8192 or bend_start > 8191 or bend_end < -8192 or bend_end > 8191 then
  return reaper.MB("Please enter a value from -8192 through 8191", "Error", 0), reaper.SN_FocusMIDIEditor()
end

local t = {}
if bend_start < bend_end then
  for j = bend_start - 1, bend_end, step do
    j = j + 1
    table.insert(t, j)
  end
end

if bend_start > bend_end then
  for y = bend_end - 1, bend_start, step do
    y = y + 1
    table.insert(t, y)
    table.sort(t,function(bend_start,bend_end) return bend_start > bend_end end)
  end
end

reaper.Undo_BeginBlock()
for k, v in pairs(t) do
  local value = v + 8192
  local LSB = value & 0x7f
  local MSB = value >> 7 & 0x7f
  local interval = math.floor(loop_len/#t)
  reaper.MIDI_InsertCC(take, selected, muted, loop_start+(k-1)*(interval*0.40), 224, chan, LSB, MSB)
  local interval = math.floor(loop_len/-#t)
  reaper.MIDI_InsertCC(take, selected, muted, loop_end+(k-1)*(interval*0.40), 224, chan, LSB, MSB)
end
reaper.Undo_EndBlock("Linear Ramp Bend Up/Down", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()