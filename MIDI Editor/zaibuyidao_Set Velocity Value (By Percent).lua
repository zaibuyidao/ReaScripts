--[[
 * ReaScript Name: Set Velocity Value (By Percent)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2019-12-15)
  + Initial release
--]]

local retval, user_input = reaper.GetUserInputs('Set Velocity Value', 1, 'By Percent', '125')
if not retval then return reaper.SN_FocusMIDIEditor() end

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  for i = 0,  notes-1 do
    retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      local x = math.floor(vel * (user_input/100))
      if x > 127 then x = 127 end
      if x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, i, sel, muted, startppqpos, endppqpos, chan, pitch, x, true)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Set Velocity Value"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
