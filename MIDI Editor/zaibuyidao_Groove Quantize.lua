--[[
 * ReaScript Name: Groove Quantize
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.4 (2020-2-15)
  # Add midi ticks per beat
 * v1.3 (2020-1-20)
  # Improve processing speed
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  userOK, fudu = reaper.GetUserInputs("Groove Quantize", 1, "Amount", "3")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  fudu = tonumber(fudu)
  reaper.MIDI_DisableSort(take)
  for i = 0,  notes-1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    if selected == true then
      if tick == 0 then
        local x = vel - 1 + math.random(fudu + 1)
        if x > 127 then x = 127 end
        if x < 1 then x = 1 end
        reaper.MIDI_SetNote(take, i, _, _, _, _, _, _, x, false)
      elseif tick == 240 then
        local y = vel - 1 - fudu + math.random(fudu + 1)
        if y > 127 then y = 127 end
        if y < 1 then y = 1 end
        reaper.MIDI_SetNote(take, i, _, _, _, _, _, _, y, false)
      else
	    vel = vel - fudu*2
	    local z = vel - 1 + math.random(fudu*2 + 1)
        if z > 127 then z = 127 end
        if z < 1 then z = 1 end
        reaper.MIDI_SetNote(take, i, _, _, _, _, _, _, z, false)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Groove Quantize"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()