--[[
 * ReaScript Name: Bend Within Time Selection
 * Version: 1.0
 * Author: zaibuyidao
 * Author URL: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URL: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-8-3)
  + Initial release
--]]

function print(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
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
  local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
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

local pitch = reaper.GetExtState("BendWithinTimeSelection", "Pitch")
if (pitch == "") then pitch = "12" end
local mode = reaper.GetExtState("BendWithinTimeSelection", "Mode")
if (mode == "") then mode = "0" end

uok, uinput = reaper.GetUserInputs("Bend Within Time Selection", 2, "Pitch Range,0=Hold 1=Immediate 2=Reverse", pitch..','..mode)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, mode = uinput:match("(.*),(.*)")

if tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 then
  return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("BendWithinTimeSelection", "Pitch", pitch, false)
reaper.SetExtState("BendWithinTimeSelection", "Mode", mode, false)

tbl = {} -- 存储弯音值
tbl["12"]="8191"
tbl["11"]="7513"
tbl["10"]="6830"
tbl["9"]="6147"
tbl["8"]="5464"
tbl["7"]="4781"
tbl["6"]="4098"
tbl["5"]="3415"
tbl["4"]="2732"
tbl["3"]="2049"
tbl["2"]="1366"
tbl["1"]="683"
tbl["0"]="0"
tbl["-1"]="-683"
tbl["-2"]="-1366"
tbl["-3"]="-2049"
tbl["-4"]="-2732"
tbl["-5"]="-3415"
tbl["-6"]="-4098"
tbl["-7"]="-4781"
tbl["-8"]="-5464"
tbl["-9"]="-6147"
tbl["-10"]="-6830"
tbl["-11"]="-7513"
tbl["-12"]="-8192"

local function set_cc_shape(take, bezier, shape)
  i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

local pitchbend = tbl[pitch]
pitchbend = pitchbend + 8192
local LSB = pitchbend & 0x7f
local MSB = pitchbend >> 7 & 0x7f

reaper.Undo_BeginBlock()
if mode == "0" then
  local p1 = loop_start + loop_len*0.25
  local p2 = loop_start + loop_len*0.75
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, 75, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif mode == "1" then
  local p1 = loop_start + loop_len*0.49
  local p2 = loop_start + loop_len*0.51
  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, 50, 5)
  reaper.MIDI_InsertCC(take, false, false, p1, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, true, false, p2, 224, 0, LSB, MSB)
  set_cc_shape(take, -50, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
elseif mode == "2" then
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

reaper.Undo_EndBlock("Bend Within Time Selection", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()