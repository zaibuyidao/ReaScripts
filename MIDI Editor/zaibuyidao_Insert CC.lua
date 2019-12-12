--[[
 * ReaScript Name: Insert CC
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

selected = false
muted = false

local retval, userInputsCSV = reaper.GetUserInputs("Insert CC", 3, "CC Number,Value,Offset", "120,0,-10")
if not retval then return reaper.SN_FocusMIDIEditor() end
local msg2, msg3, offset = userInputsCSV:match("(.*),(.*),(.*)")
msg2, msg3, offset = tonumber(msg2), tonumber(msg3), tonumber(offset)

function Main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx(0)
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    ppq = ppq + offset
    reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, 0, msg2, msg3)
end

reaper.Undo_BeginBlock()
selected = true
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert CC", -1)
reaper.SN_FocusMIDIEditor()
