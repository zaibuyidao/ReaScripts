--[[
 * ReaScript Name: Select Control (By Value)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Events. Run.
 * Version: 1.125
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showthread.php?t=225108
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.125 (2020-1-5)
  # Adjust the name
 * v1.0 (2020-1-1)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Control By Value", 4, "Value,,Beat,", "0,127,1,99")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_val, max_val, min_meas, max_meas = dialog_ret_vals:match("(.*),(.*),(.*),(.*)")
min_val, max_val, min_meas, max_meas = tonumber(min_val), tonumber(max_val), tonumber(min_meas) -1, tonumber(max_meas) -- min_meas -1: Compensation
if min_val > 127 or max_val > 127 or min_val < 0 or max_val < 0 then return reaper.MB("Please enter a value from 0 through 127", "Value Error", 0), reaper.SN_FocusMIDIEditor() end
if min_meas > 99 or max_meas > 99 or min_meas < 0 or max_meas < 0 then return reaper.MB("Please enter a value from 1 through 99", "Beat Error", 0), reaper.SN_FocusMIDIEditor() end

function MEAS()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppqpos)
    if sel == true then
      local retval, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, newstart)
      if newstart >= math.floor(Bar_Start_QN) + min_meas and newstart < math.floor(Bar_Start_QN) + max_meas then
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

function VAL()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      if msg3 >= min_val and msg3 <= max_val then --  定义数值范围
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Control (By Value)"
reaper.Undo_BeginBlock()
MEAS()
VAL()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()