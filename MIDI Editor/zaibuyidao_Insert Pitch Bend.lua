--[[
 * ReaScript Name: Insert Pitch Bend
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 1.2
 * Author: zaibuyidao
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
local retval, userinput = reaper.GetUserInputs('Insert Pitch Bend', 1, 'Value', '0')
if not retval then return reaper.SN_FocusMIDIEditor() end

local value = math.floor(userinput)
if value < -8192 or value > 8191 then
    return
        reaper.MB("Please enter a value from -8192 through 8191", "Error", 0),
        reaper.SN_FocusMIDIEditor()
end

value = value + 8192
local LSB = value & 0x7f
local MSB = value >> 7 & 0x7f
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
