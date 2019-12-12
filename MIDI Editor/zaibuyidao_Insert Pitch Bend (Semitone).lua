--[[
 * ReaScript Name: Insert Pitch Bend (Semitone)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx(0)
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local retval, userinput = reaper.GetUserInputs('Insert Pitch Bend', 1, 'Semitone', '0')
if not retval then return reaper.SN_FocusMIDIEditor() end
userinput = tonumber(userinput)
if userinput > 12 or userinput < -12 then
    return reaper.MB("Please enter a value from -12 through 12", "Error", 0),
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

local value = tonumber(tbl[tostring(userinput)])
value = value + 8192
local LSB = value & 0x7f
local MSB = value >> 7 & 0x7f
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
