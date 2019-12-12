--[[
 * ReaScript Name: Slide Out
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

time_start, time_end = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0)

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
local loop_len = loop_end - loop_start

userOK, get_value = reaper.GetUserInputs("Slide Out", 1, "Pitch Range", "0")
if not userOK then return end

local average_len = math.floor((loop_len-20)/math.abs(get_value))
local next_start = loop_start

if tonumber(get_value) > 12 or tonumber(get_value) < -12 then
  return reaper.SN_FocusMIDIEditor()
end

if tonumber(get_value) < 0 then
  for i = -1,get_value, -1 do
    next_start = next_start + average_len

    tbl={}
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

    local get_input = tostring(i)
    local value = tonumber(tbl[get_input])
    value = value + 8192
    local lsb = value & 0x7f
    local msb = value >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, false, false, next_start, 224, 0, lsb, msb)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_start, 224, 0, 0, 64)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
else
  for i = 1,get_value do
    next_start = next_start + average_len

    tbl={}
    tbl["0"]="0"
    tbl["1"]="683"
    tbl["2"]="1366"
    tbl["3"]="2049"
    tbl["4"]="2732"
    tbl["5"]="3415"
    tbl["6"]="4098"
    tbl["7"]="4781"
    tbl["8"]="5464"
    tbl["9"]="6147"
    tbl["10"]="6830"
    tbl["11"]="7513"
    tbl["12"]="8191"

    local get_input = tostring(i)
    local value = tonumber(tbl[get_input])
    value = value + 8192
    local lsb = value & 0x7f
    local msb = value >> 7 & 0x7f
    reaper.MIDI_InsertCC(take, false, false, next_start, 224, 0, lsb, msb)
  end
  reaper.MIDI_InsertCC(take, false, false, loop_start, 224, 0, 0, 64)
  reaper.MIDI_InsertCC(take, false, false, loop_end, 224, 0, 0, 64)
end

-- reaper.SetEditCurPos( time_start, 0, 0 )
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
