--[[
 * ReaScript Name: Select Wheel
 * Instructions: Open a MIDI take in MIDI Editor. Select Pitch Bend. Run.
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

chanmsg = 224

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Wheel", 8, "Wheel,,Tick,,Beat,,Channel,", "-8192,8191,0,1919,1,99,1,16")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_val, max_val, min_tick, max_tick, min_meas, max_meas, min_chan, max_chan = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_val, max_val, min_tick, max_tick, min_meas, max_meas, min_chan, max_chan = tonumber(min_val), tonumber(max_val), tonumber(min_tick), tonumber(max_tick), tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_chan) -1, tonumber(max_chan) -1 -- min_meas -1: Compensation

function MEAS()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos)
    if sel == true then
      local retval, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, newstart)
      if newstart >= math.floor(Bar_Start_QN) + min_meas and newstart < math.floor(Bar_Start_QN) + max_meas then --  定义小节范围
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

function TICK()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos)
    if sel == true then
      if newstart >= math.floor(newstart) + min_tick/480 and newstart <= math.floor(newstart) + max_tick/480 then --  定义Tick范围
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      end
    end
  end
  reaper.UpdateArrange()
end

function VAL()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    if sel == true then
      local pitchbend = (MSB-64)*128+LSB
        if pitchbend >= min_val and pitchbend <= max_val then --  定义数值范围
          reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
        else
          reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
        end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

function CHAN()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, i)
    if sel == true then
      if chan >= min_chan and chan <= max_chan then -- 定义通道范围
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, LSB, MSB, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Wheel"
reaper.Undo_BeginBlock()
MEAS()
TICK()
VAL()
CHAN()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()