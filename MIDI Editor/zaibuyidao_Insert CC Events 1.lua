--[[
 * ReaScript Name: Insert CC Events 1
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-19)
  + Initial release
--]]

selected = false
muted = false
offset = 0

local retval, userInputsCSV = reaper.GetUserInputs("Insert CC Events 1", 2, "CC Number,Value", "11,127")
if not retval then return reaper.SN_FocusMIDIEditor() end
local msg2, msg3 = userInputsCSV:match("(.*),(.*)")
msg2, msg3 = tonumber(msg2), tonumber(msg3)

function Main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx(0)
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    ppq = ppq + offset -- 微移CC位置
    reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, 0, msg2, msg3)
end

reaper.Undo_BeginBlock()
selected = true
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert CC Events 1", -1)
reaper.SN_FocusMIDIEditor()
