--[[
 * ReaScript Name: Select Wheel
 * Instructions: Open a MIDI take in MIDI Editor. Select Pitch Bend. Run.
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
 * v1.1 (2020-1-19)
  # Fix bug
 * v1.0 (2020-1-12)
  + Initial release
--]]

chanmsg = 224

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Wheel", 8, "Wheel,,Tick,,Beat,,Channel,", "-8192,8191,0,1919,1,99,1,16")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_val, max_val, min_tick, max_tick, min_meas, max_meas, min_chan, max_chan = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_val, max_val, min_tick, max_tick, min_meas, max_meas, min_chan, max_chan = tonumber(min_val), tonumber(max_val), tonumber(min_tick), tonumber(max_tick), tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_chan) -1, tonumber(max_chan) -1

function Main()
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccs-1 do
    local retval, selected, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    local newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, ppqpos)
    local start_tick = ppqpos - start_meas
    local tick = start_tick % midi_tick
    local pitchbend = (MSB-64)*128+LSB
    if selected == true then
      if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then
        reaper.MIDI_SetCC(take, i, false, _, _, _, _, _, _, false)
      end
      if not (tick >= min_tick and tick <= max_tick) then
        reaper.MIDI_SetCC(take, i, false, _, _, _, _, _, _, false)
      end
      if not (pitchbend >= min_val and pitchbend <= max_val) then
        reaper.MIDI_SetCC(take, i, false, _, _, _, _, _, _, false)
      end
      if not (chan >= min_chan and chan <= max_chan) then
        reaper.MIDI_SetCC(take, i, false, _, _, _, _, _, _, false)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Select Wheel"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()