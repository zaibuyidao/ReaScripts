--[[
 * ReaScript Name: 彎音滑入
 * Version: 1.4.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
local loop_len = loop_end - loop_start

local pitch = reaper.GetExtState("SlideIn", "Pitch")
if (pitch == "") then pitch = "1" end

user_ok, pitch = reaper.GetUserInputs("彎音滑入", 1, "彎音範圍", pitch)
if not user_ok or tonumber(pitch) > 12 or tonumber(pitch) < -12 or tonumber(pitch) == 0 or loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("SlideIn", "Pitch", pitch, false)

local average_len = math.floor((loop_len)/math.abs(pitch))
local next_start = loop_start - average_len

tbl = {}
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

reaper.Undo_BeginBlock()

if tonumber(pitch) < 0 then
  for i = math.floor(pitch), -1, 1 do
    next_start = next_start + average_len

    local get_pitch = tostring(i)
    local pitchbend = tonumber(tbl[get_pitch])
    pitchbend = pitchbend + 8192
    local LSB = pitchbend & 0x7f
    local MSB = pitchbend >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, false, false, next_start, 224, 0, LSB, MSB)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
else
  for i = math.floor(pitch), 1, -1 do
    next_start = next_start + average_len

    local get_pitch = tostring(i)
    local pitchbend = tonumber(tbl[get_pitch])
    pitchbend = pitchbend + 8192
    local LSB = pitchbend & 0x7f
    local MSB = pitchbend >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, false, false, next_start, 224, 0, LSB, MSB)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
end
reaper.Undo_EndBlock("彎音滑入", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()