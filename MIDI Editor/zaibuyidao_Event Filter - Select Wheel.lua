--[[
 * ReaScript Name: Event Filter - Select Wheel
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
 * v1.0 (2020-1-12)
  + Initial release
--]]

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
_, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)

local min_val = reaper.GetExtState("SelectWheel", "MinVal")
if (min_val == "") then min_val = "-8192" end
local max_val = reaper.GetExtState("SelectWheel", "MaxVal")
if (max_val == "") then max_val = "8191" end
local min_chan = reaper.GetExtState("SelectWheel", "MinChan")
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectWheel", "MaxChan")
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectWheel", "MinMeas")
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectWheel", "MaxMeas")
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectWheel", "MinTick")
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectWheel", "MaxTick")
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectWheel", "Reset")
if (reset == "") then reset = "0" end

user_ok, dialog_ret_vals = reaper.GetUserInputs("Select Wheel", 9, "Wheel,,Channel,,Beat,,Tick,,Enter 1 to restore default settings,", min_val ..','.. max_val ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_val) or not tonumber(max_val) or not tonumber(min_chan) or not tonumber(max_chan) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tonumber(reset) then return reaper.SN_FocusMIDIEditor() end
min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_val), tonumber(max_val), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tonumber(reset)

reaper.SetExtState("SelectWheel", "MinVal", min_val, false)
reaper.SetExtState("SelectWheel", "MaxVal", max_val, false)
reaper.SetExtState("SelectWheel", "MinChan", min_chan, false)
reaper.SetExtState("SelectWheel", "MaxChan", max_chan, false)
reaper.SetExtState("SelectWheel", "MinMeas", min_meas, false)
reaper.SetExtState("SelectWheel", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectWheel", "MinTick", min_tick, false)
reaper.SetExtState("SelectWheel", "MaxTick", max_tick, false)
-- reaper.SetExtState("SelectWheel", "Reset", reset, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

function Main()
  for i = 0,  ccevtcnt-1 do
    local retval, selected, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    local newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, ppqpos)
    local start_tick = ppqpos - start_meas
    local tick = start_tick % midi_tick
    local pitchbend = (MSB-64)*128+LSB
    reaper.MIDI_DisableSort(take)
    if reset == 0 then
      if selected == true then
        if not (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick) then
          reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
        end
        if not (tick >= min_tick and tick <= max_tick) then
          reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
        end
        if not (pitchbend >= min_val and pitchbend <= max_val) then
          reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
        end
        if not (chan >= min_chan and chan <= max_chan) then
          reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
        end
      end
    elseif reset == 1 then
      reaper.SetExtState("SelectWheel", "MinVal", "-8192", false)
      reaper.SetExtState("SelectWheel", "MaxVal", "8191", false)
      reaper.SetExtState("SelectWheel", "MinChan", "1", false)
      reaper.SetExtState("SelectWheel", "MaxChan", "16", false)
      reaper.SetExtState("SelectWheel", "MinMeas", "1", false)
      reaper.SetExtState("SelectWheel", "MaxMeas", "99", false)
      reaper.SetExtState("SelectWheel", "MinTick", "0", false)
      reaper.SetExtState("SelectWheel", "MaxTick", "1919", false)
      reaper.SetExtState("SelectWheel", "Reset", "0", false)
    end
    i=i+1
  end
  reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select Wheel", 0)
reaper.SN_FocusMIDIEditor()