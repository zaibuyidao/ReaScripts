--[[
 * ReaScript Name: Insert All Sound Off
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 1.0
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
msg2 = 120
msg3 = 0
offset = -10 -- 微移CC位置

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
reaper.Undo_EndBlock("Insert All Sound Off", -1)
reaper.SN_FocusMIDIEditor()
