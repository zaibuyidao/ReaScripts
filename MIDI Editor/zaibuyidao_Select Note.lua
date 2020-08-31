--[[
 * ReaScript Name: Select Note
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
 * v1.0 (2020-1-5)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)
user_ok, dialog_ret_vals = reaper.GetUserInputs("Select Note", 12, "Key,,Velocity,,Duration,,Channel,,Beat,,Tick,", "0,127,1,127,0,65535,1,16,1,99,0,1919")
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan) -1, tonumber(max_chan) -1, tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_tick), tonumber(max_tick)

function main()
  reaper.MIDI_DisableSort(take)
  for i = 0,  notecnt - 1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    local duration = endppqpos - startppqpos

    if selected == true then
      if not (pitch >= min_key and pitch <= max_key) then -- Key
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (vel >= min_vel and vel <= max_vel) then -- Velocity
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (duration >= min_dur and duration <= max_dur) then -- Duration
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (chan >= min_chan and chan <= max_chan) then -- Channel
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then -- Beat
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (tick >= min_tick and tick <= max_tick) then -- Tick
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    i = i + 1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Select Note"
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()