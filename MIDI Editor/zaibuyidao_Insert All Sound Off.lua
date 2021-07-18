--[[
 * ReaScript Name: Insert All Sound Off
 * Version: 1.1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.1 (2020-2-16)
  # Default selected is false
 * v1.0 (2019-12-19)
  + Initial release
--]]

selected = false
muted = false
msg2 = 120
msg3 = 0

function Main()
	reaper.Undo_BeginBlock()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local pos = reaper.GetCursorPositionEx()
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    reaper.MIDI_InsertCC(take, selected, muted, ppq - 10, 0xB0, 0, msg2, msg3)
    reaper.Undo_EndBlock("Insert All Sound Off", -1)
    reaper.UpdateArrange()
end


Main()
reaper.SN_FocusMIDIEditor()