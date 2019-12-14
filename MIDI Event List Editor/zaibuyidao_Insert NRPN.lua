--[[
 * ReaScript Name: Insert NRPN
 * Instructions: Open a MIDI take in MIDI Event List Editor. Select Event, Run.
 * Version: 1.21
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

interval = 10 -- 间隔10Tick
cc_first = 98
cc_second = 6
selected = false
muted = false

local retval, userInputsCSV = reaper.GetUserInputs("Insert NRPN", 2, "LSB,MSB", "0,64")
if not retval then return reaper.SN_FocusMIDIEditor() end
local LSB, MSB = userInputsCSV:match("(.*),(.*)")
LSB, MSB = tonumber(LSB), tonumber(MSB)

function NonRegParm()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx(0)
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    local msg2 = {cc_first, cc_second}
    local msg3 = {LSB, MSB}
    for i = 1, #msg3 do
        ppq = ppq + interval
        reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, 0, msg2[i], msg3[i])
        i=i+1
    end
end

reaper.Undo_BeginBlock()
selected = true
NonRegParm()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert NRPN", -1)
reaper.SN_FocusMIDIEditor()
