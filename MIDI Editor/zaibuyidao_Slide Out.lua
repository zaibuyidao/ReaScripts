--[[
 * ReaScript Name: Slide Out
 * Version: 1.4.1
 * Author: zaibuyidao
 * Author URL: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URL: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function print(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function Open_URL(url)
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
    Open_URL("http://www.sws-extension.org/download/pre-release/")
  end
end

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
if loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end

local pitch = reaper.GetExtState("SlideOut", "Pitch")
if (pitch == "") then pitch = "-3" end
local bezier = reaper.GetExtState("SlideOut", "Bezier")
if (bezier == "") then bezier = "20" end
local mode = reaper.GetExtState("SlideOut", "Mode")
if (mode == "") then mode = "1" end

uok, uinput = reaper.GetUserInputs("Slide Out", 3, "Pitch Range 彎音範圍,Bezier 貝塞爾 (-100,100),0=Fret 有品 1=Fretless 無品", pitch..','..bezier..','..mode)
if not uok then return reaper.SN_FocusMIDIEditor() end
pitch, bezier, mode = uinput:match("(.*),(.*),(.*)")

if not tonumber(pitch) or not tonumber(bezier) or not tonumber(mode) or tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 or tonumber(bezier) < -100 or tonumber(bezier) > 100 or tonumber(mode) > 1 then
  return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("SlideOut", "Pitch", pitch, false)
reaper.SetExtState("SlideOut", "Bezier", bezier, false)
reaper.SetExtState("SlideOut", "Mode", mode, false)

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
  local i = reaper.MIDI_EnumSelCC(take, -1)
  while i ~= -1 do
    reaper.MIDI_SetCCShape(take, i, shape, bezier / 100, true)
    reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
    i = reaper.MIDI_EnumSelCC(take, i)
  end
end

reaper.Undo_BeginBlock()

if mode == "1" then
  local pitchbend = tbl[pitch]
  pitchbend = pitchbend + 8192
  local LSB = pitchbend & 0x7f
  local MSB = pitchbend >> 7 & 0x7f

  reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, 0, 64)
  set_cc_shape(take, bezier, 5)
  reaper.MIDI_InsertCC(take, false, false, loop_start+(loop_end-loop_start)*0.96, 224, 0, LSB, MSB)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)

elseif mode == "0" then
  local average_len = math.floor((loop_end-loop_start)*0.96/math.abs(pitch))
  local next_start = loop_start

  local function set_pitch(i)
    next_start = next_start + average_len

    local get_pitch = tostring(i)
    local pitchbend = tonumber(tbl[get_pitch])
    pitchbend = pitchbend + 8192
    local LSB = pitchbend & 0x7f
    local MSB = pitchbend >> 7 & 0x7f

    reaper.MIDI_InsertCC(take, true, false, next_start, 224, 0, LSB, MSB)
    set_cc_shape(take, bezier, 0)
  end

  reaper.MIDI_InsertCC(take, false, false, loop_start, 224, 0, 0, 64)
  if tonumber(pitch) < 0 then
    for i = -1, pitch, -1 do
      set_pitch(i)
    end
  else
    for i = 1, pitch do
      set_pitch(i)
    end
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)

end

reaper.Undo_EndBlock("Slide Out", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()