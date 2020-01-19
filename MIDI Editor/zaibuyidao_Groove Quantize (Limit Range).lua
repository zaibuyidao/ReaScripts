--[[
 * ReaScript Name: Groove Quantize (Limit Range)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2020-1-20)
  # Improve processing speed
 * v1.0 (2019-12-12)
  + Initial release
--]]

offset = 4 -- Strength随机个数

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  userOK, dialog_ret_vals = reaper.GetUserInputs("Groove Quantize", 3, "Min Value,Max Value,Strength", "110,118,120")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  min_val, max_val, strength = dialog_ret_vals:match("(.*),(.*),(.*)")
  min_val, max_val, strength = tonumber(min_val), tonumber(max_val), tonumber(strength)

  if min_val > 127 then
    min_val = 127
  elseif
    min_val < 1 then
    min_val = 1
  elseif
    max_val > 127 then
    max_val = 127
  elseif
    max_val < 1 then
    max_val = 1
  elseif
  min_val > max_val then
    local t = max_val
    max_val = min_val
    min_val = t
  end

  if min_val == max_val or strength == strength - offset then
      return reaper.MB("Random interval is empty.", "Error", 0),
             reaper.SN_FocusMIDIEditor()
  end

  local diff = max_val - min_val
  strength = strength - 1
  reaper.MIDI_DisableSort(take)
  for i = 0,  notes-1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % 480
    if selected == true then
	  if tick == 0 then
        local x = strength+math.random(offset)
        if x > 127 then x = 127 end
        reaper.MIDI_SetNote(take, i, _, _, _, _, _, _, x, false)
      else
        local z = tonumber(min_val + math.random(diff))
        reaper.MIDI_SetNote(take, i, _, _, _, _, _, _, z, false)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Groove Quantize (Limit Range)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()