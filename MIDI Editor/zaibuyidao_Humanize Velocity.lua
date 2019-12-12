--[[
 * ReaScript Name: Humanize Velocity
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  userOK, strength = reaper.GetUserInputs("Humanize Velocity", 1, "Value", "3")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  strength = tonumber(strength*2)
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
	  vel = vel - strength/2 - 1
	  local x = vel+math.random(strength+1)
      if x > 127 then x = 127 end
      if x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, i, sel, muted, ppq_start, ppq_end, chan, pitch, math.floor(x), true)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Humanize Velocity"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
