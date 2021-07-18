--[[
 * ReaScript Name: 彎音滑入形狀
 * Version: 1.0.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-29)
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

local pitch = reaper.GetExtState("SlideInShape", "Pitch")
if (pitch == "") then pitch = "-1" end
local bezier = reaper.GetExtState("SlideInShape", "Bezier")
if (bezier == "") then bezier = "20" end

user_ok, user_input = reaper.GetUserInputs("彎音滑入形狀", 2, "彎音範圍,貝塞爾(-100至100)", pitch..','..bezier)
if not user_ok or loop_start == loop_end then return reaper.SN_FocusMIDIEditor() end
pitch, bezier = user_input:match("(.*),(.*)")

if tonumber(pitch) < -12 or tonumber(pitch) > 12 or tonumber(pitch) == 0 or tonumber(bezier) < -100 or tonumber(bezier) > 100 then
  return reaper.SN_FocusMIDIEditor()
end

reaper.SetExtState("SlideInShape", "Pitch", pitch, false)
reaper.SetExtState("SlideInShape", "Bezier", bezier, false)

tbl = {} --存儲彎音值
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

local pitchbend = tbl[pitch]
pitchbend = pitchbend + 8192
local LSB = pitchbend & 0x7f
local MSB = pitchbend >> 7 & 0x7f

pitch = tonumber(pitch)

reaper.MIDI_InsertCC(take, true, false, loop_start, 224, 0, LSB, MSB)

i = reaper.MIDI_EnumSelCC(take, -1)
while i ~= -1 do
  reaper.MIDI_SetCCShape(take, i, 5, bezier / 100, true)
  reaper.MIDI_SetCC(take, i, false, false, nil, nil, nil, nil, nil, true)
  i = reaper.MIDI_EnumSelCC(take, i)
end

reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64) --在LOOP結尾插入彎音值歸零

reaper.Undo_EndBlock("彎音滑入形狀", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()