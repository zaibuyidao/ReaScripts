--[[
 * ReaScript Name: Select Control
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Events. Run.
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
_, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
user_ok, dialog_ret_vals = reaper.GetUserInputs("Select Control", 10, "Number,,Value,,Channel,,Beat,,Tick,", "0,127,0,127,1,16,1,99,0,1919")
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick = tonumber(min_num), tonumber(max_num), tonumber(min_val), tonumber(max_val), tonumber(min_chan) -1, tonumber(max_chan) -1, tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_tick), tonumber(max_tick)

function main()
  reaper.MIDI_DisableSort(take)
  for i = 0, ccevtcnt - 1 do
    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, ppqpos)
    local start_tick = ppqpos - start_meas
    local tick = start_tick % midi_tick

    if selected == true then
      if not (msg2 >= min_num and msg2 <= max_num) then -- Number
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (msg3 >= min_val and msg3 <= max_val) then -- Value
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (chan >= min_chan and chan <= max_chan) then -- Channel
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then -- Beat
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
      if not (tick >= min_tick and tick <= max_tick) then -- Tick
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    i = i + 1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Select Control"
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()