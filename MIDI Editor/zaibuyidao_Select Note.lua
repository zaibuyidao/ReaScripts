--[[
 * ReaScript Name: Select Note
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: select Note.lua (dangguidan)
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2020-2-15)
  # Add midi ticks per beat
 * v1.1 (2020-1-19)
  # Fix bug
 * v1.0 (2020-1-5)
  + Initial release
--]]

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Note", 12, "Tick,,Velocity,,Duration,,Beat,,Key,,Channel,", "0,1919,1,127,0,65535,1,99,0,127,1,16")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_tick, max_tick, min_vel, max_vel, min_dur, max_dur, min_meas, max_meas, min_key, max_key, min_chan, max_chan = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_tick, max_tick, min_vel, max_vel, min_dur, max_dur, min_meas, max_meas, min_key, max_key, min_chan, max_chan = tonumber(min_tick), tonumber(max_tick), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_key), tonumber(max_key), tonumber(min_chan) -1, tonumber(max_chan) -1

function Main()
  reaper.MIDI_DisableSort(take)
  for i = 0,  notes-1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    local duration = endppqpos - startppqpos
    if selected == true then
      if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
      if not (vel >= min_vel and vel <= max_vel) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
      if not (tick >= min_tick and tick <= max_tick) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
      if not (duration >= min_dur and duration <= max_dur) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
      if not (pitch >= min_key and pitch <= max_key) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
      if not (chan >= min_chan and chan <= max_chan) then
        reaper.MIDI_SetNote(take, i, false, _, _, _, _, _, _, false)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Select Note"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()