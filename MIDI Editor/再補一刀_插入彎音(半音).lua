--[[
 * ReaScript Name: 插入彎音(半音)
 * Version: 1.4
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local pitch = reaper.GetExtState("InsertPitchBendSemitone", "Pitch")
if (pitch == "") then pitch = "0" end
local user_ok, user_input_csv = reaper.GetUserInputs('插入彎音', 1, '半音', pitch)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
pitch = user_input_csv:match("(.*)")
if not tonumber(pitch) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("InsertPitchBendSemitone", "Pitch", pitch, false)

pitch = tonumber(pitch)
if pitch > 12 or pitch < -12 then
    return reaper.MB("請輸入一個介於-12到12之間的值", "錯誤", 0),
           reaper.SN_FocusMIDIEditor()
end

tbl = {}
tbl["12"] = "8191"
tbl["11"] = "7513"
tbl["10"] = "6830"
tbl["9"] = "6147"
tbl["8"] = "5464"
tbl["7"] = "4781"
tbl["6"] = "4098"
tbl["5"] = "3415"
tbl["4"] = "2732"
tbl["3"] = "2049"
tbl["2"] = "1366"
tbl["1"] = "683"
tbl["0"] = "0"
tbl["-1"] = "-683"
tbl["-2"] = "-1366"
tbl["-3"] = "-2049"
tbl["-4"] = "-2732"
tbl["-5"] = "-3415"
tbl["-6"] = "-4098"
tbl["-7"] = "-4781"
tbl["-8"] = "-5464"
tbl["-9"] = "-6147"
tbl["-10"] = "-6830"
tbl["-11"] = "-7513"
tbl["-12"] = "-8192"

reaper.Undo_BeginBlock()
local value = tonumber(tbl[tostring(pitch)])
value = value + 8192
local LSB = value & 0x7f
local MSB = value >> 7 & 0x7f
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock("插入彎音(半音)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
