--[[
 * ReaScript Name: 律動量化
 * Version: 1.6.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

  local fudu = reaper.GetExtState("GrooveQuantize", "Amount")
  if (fudu == "") then fudu = "3" end

  local user_ok, user_input_csv = reaper.GetUserInputs("律動量化", 1, "量", fudu)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  fudu = user_input_csv:match("(.*)")
  if not tonumber(fudu) then return reaper.SN_FocusMIDIEditor() end
  fudu = tonumber(fudu)
  reaper.SetExtState("GrooveQuantize", "Amount", fudu, false)

  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  for i = 0,  notecnt-1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    if selected == true then
      if tick == 0 then
        local x = vel - 1 + math.random(fudu + 1)
        if x > 127 then x = 127 end
        if x < 1 then x = 1 end
        reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, nil, x, false)
      elseif tick == midi_tick/2 then
        local y = vel - 1 - fudu + math.random(fudu + 1)
        if y > 127 then y = 127 end
        if y < 1 then y = 1 end
        reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, nil, y, false)
      else
        vel = vel - fudu*2
        local z = vel - 1 + math.random(fudu*2 + 1)
        if z > 127 then z = 127 end
        if z < 1 then z = 1 end
        reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, nil, z, false)
      end
    end
    i=i+1
  end
  reaper.Undo_EndBlock("Groove Quantize", -1)
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

Main()
reaper.SN_FocusMIDIEditor()