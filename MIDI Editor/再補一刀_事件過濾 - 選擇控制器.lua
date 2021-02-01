--[[
 * ReaScript Name: 事件過濾 - 選擇控制器
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
_, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)

local min_num = reaper.GetExtState("SelectControl", "MinNum")
if (min_num == "") then min_num = "0" end
local max_num = reaper.GetExtState("SelectControl", "MaxNum")
if (max_num == "") then max_num = "127" end
local min_val = reaper.GetExtState("SelectControl", "MinVal")
if (min_val == "") then min_val = "0" end
local max_val = reaper.GetExtState("SelectControl", "MaxVal")
if (max_val == "") then max_val = "127" end
local min_chan = reaper.GetExtState("SelectControl", "MinChan")
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectControl", "MaxChan")
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectControl", "MinMeas")
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectControl", "MaxMeas")
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectControl", "MinTick")
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectControl", "MaxTick")
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectControl", "Reset")
if (reset == "") then reset = "0" end

user_ok, dialog_ret_vals = reaper.GetUserInputs("選擇控制器", 11, "編號,,數值,,通道,,拍子,,嘀嗒,,輸入1以恢復默認設置,", min_num ..','.. max_num ..','.. min_val ..','.. max_val ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_num) or not tonumber(max_num) or not tonumber(min_val) or not tonumber(max_val) or not tonumber(min_chan) or not tonumber(max_chan) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tonumber(reset) then return reaper.SN_FocusMIDIEditor() end
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_num), tonumber(max_num), tonumber(min_val), tonumber(max_val), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tonumber(reset)

reaper.SetExtState("SelectControl", "MinNum", min_num, false)
reaper.SetExtState("SelectControl", "MaxNum", max_num, false)
reaper.SetExtState("SelectControl", "MinVal", min_val, false)
reaper.SetExtState("SelectControl", "MaxVal", max_val, false)
reaper.SetExtState("SelectControl", "MinChan", min_chan, false)
reaper.SetExtState("SelectControl", "MaxChan", max_chan, false)
reaper.SetExtState("SelectControl", "MinMeas", min_meas, false)
reaper.SetExtState("SelectControl", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectControl", "MinTick", min_tick, false)
reaper.SetExtState("SelectControl", "MaxTick", max_tick, false)
-- reaper.SetExtState("SelectControl", "Reset", reset, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

function main()
  for i = 0, ccevtcnt - 1 do
    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, ppqpos)
    local start_tick = ppqpos - start_meas
    local tick = start_tick % midi_tick
    reaper.MIDI_DisableSort(take)
    if reset == 0 then
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
    elseif reset == 1 then
      reaper.SetExtState("SelectControl", "MinNum", "0", false)
      reaper.SetExtState("SelectControl", "MaxNum", "127", false)
      reaper.SetExtState("SelectControl", "MinVal", "0", false)
      reaper.SetExtState("SelectControl", "MaxVal", "127", false)
      reaper.SetExtState("SelectControl", "MinChan", "1", false)
      reaper.SetExtState("SelectControl", "MaxChan", "16", false)
      reaper.SetExtState("SelectControl", "MinMeas", "1", false)
      reaper.SetExtState("SelectControl", "MaxMeas", "99", false)
      reaper.SetExtState("SelectControl", "MinTick", "0", false)
      reaper.SetExtState("SelectControl", "MaxTick", "1919", false)
      reaper.SetExtState("SelectControl", "Reset", "0", false)
    end
    i=i+1
  end
  reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("選擇控制器", 0)
reaper.SN_FocusMIDIEditor()