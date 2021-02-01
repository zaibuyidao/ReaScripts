--[[
 * ReaScript Name: 事件過濾 - 選擇音符
 * Version: 1.0
 * Author: 再補一刀
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

local min_key = reaper.GetExtState("SelectNote", "MinKey")
if (min_key == "") then min_key = "0" end
local max_key = reaper.GetExtState("SelectNote", "MaxKey")
if (max_key == "") then max_key = "127" end
local min_vel = reaper.GetExtState("SelectNote", "MinVel")
if (min_vel == "") then min_vel = "1" end
local max_vel = reaper.GetExtState("SelectNote", "MaxVel")
if (max_vel == "") then max_vel = "127" end
local min_dur = reaper.GetExtState("SelectNote", "MinDur")
if (min_dur == "") then min_dur = "0" end
local max_dur = reaper.GetExtState("SelectNote", "MaxDur")
if (max_dur == "") then max_dur = "65535" end
local min_chan = reaper.GetExtState("SelectNote", "MinChan")
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectNote", "MaxChan")
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectNote", "MinMeas")
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectNote", "MaxMeas")
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectNote", "MinTick")
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectNote", "MaxTick")
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectNote", "Reset")
if (reset == "") then reset = "0" end

user_ok, dialog_ret_vals = reaper.GetUserInputs("選擇音符", 13, "音高,,力度,,時值,,通道,,拍子,,嘀嗒,,輸入1以恢復默認設置,", min_key ..','.. max_key ..','.. min_vel ..','.. max_vel ..','.. min_dur ..','.. max_dur ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_key) or not tonumber(max_key) or not tonumber(min_vel) or not tonumber(max_vel) or not tonumber(min_dur) or not tonumber(max_dur) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tonumber(reset) then return reaper.SN_FocusMIDIEditor() end
min_key, max_key, min_vel, max_vel, min_dur, max_dur, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_key), tonumber(max_key), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tonumber(reset)

reaper.SetExtState("SelectNote", "MinKey", min_key, false)
reaper.SetExtState("SelectNote", "MaxKey", max_key, false)
reaper.SetExtState("SelectNote", "MinVel", min_vel, false)
reaper.SetExtState("SelectNote", "MaxVel", max_vel, false)
reaper.SetExtState("SelectNote", "MinDur", min_dur, false)
reaper.SetExtState("SelectNote", "MaxDur", max_dur, false)
reaper.SetExtState("SelectNote", "MinChan", min_chan, false)
reaper.SetExtState("SelectNote", "MaxChan", max_chan, false)
reaper.SetExtState("SelectNote", "MinMeas", min_meas, false)
reaper.SetExtState("SelectNote", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectNote", "MinTick", min_tick, false)
reaper.SetExtState("SelectNote", "MaxTick", max_tick, false)
-- reaper.SetExtState("SelectNote", "Reset", reset, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

function main()
  for i = 0,  notecnt - 1 do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick
    local duration = endppqpos - startppqpos
    reaper.MIDI_DisableSort(take)
    if reset == 0 then
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
    elseif reset == 1 then
      reaper.SetExtState("SelectNote", "MinKey", "0", false)
      reaper.SetExtState("SelectNote", "MaxKey", "127", false)
      reaper.SetExtState("SelectNote", "MinVel", "1", false)
      reaper.SetExtState("SelectNote", "MaxVel", "127", false)
      reaper.SetExtState("SelectNote", "MinDur", "0", false)
      reaper.SetExtState("SelectNote", "MaxDur", "65535", false)
      reaper.SetExtState("SelectNote", "MinChan", "1", false)
      reaper.SetExtState("SelectNote", "MaxChan", "16", false)
      reaper.SetExtState("SelectNote", "MinMeas", "1", false)
      reaper.SetExtState("SelectNote", "MaxMeas", "99", false)
      reaper.SetExtState("SelectNote", "MinTick", "0", false)
      reaper.SetExtState("SelectNote", "MaxTick", "1919", false)
      reaper.SetExtState("SelectNote", "Reset", "0", false)
    end
    i = i + 1
  end
  reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("選擇音符", 0)
reaper.SN_FocusMIDIEditor()