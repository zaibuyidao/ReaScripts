--[[
 * ReaScript Name: Random Velocity
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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

local diff = 127

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      vel = tonumber(math.random(diff))
      reaper.MIDI_SetNote(take, i, sel, muted, ppq_start, ppq_end, chan, pitch, vel, true)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Random Velocity"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
