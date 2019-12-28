--[[
 * ReaScript Name: Select Note (By Duration)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
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
 * v1.1 (2019-12-29)
  + Increase Beat options
 * v1.0 (2019-12-27)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Note (By Duration)", 4, "Min Duration,Max Duration,Min Beat,Max Beat", "0,65536,1,99")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_dur, max_dur, min_meas, max_meas = dialog_ret_vals:match("(.*),(.*),(.*),(.*)")
min_dur, max_dur, min_meas, max_meas = tonumber(min_dur), tonumber(max_dur), tonumber(min_meas) -1, tonumber(max_meas) -- min_meas -1: Compensation
if min_dur > 65536 or max_dur > 65536 or min_dur < 0 or max_dur < 0 then return reaper.MB("Please enter a value from 0 through 65536", "Duration Error", 0), reaper.SN_FocusMIDIEditor() end
if min_meas > 99 or max_meas > 99 or min_meas < 0 or max_meas < 0 then return reaper.MB("Please enter a value from 1 through 99", "Beat Error", 0), reaper.SN_FocusMIDIEditor() end

function MEAS()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppq_start)
    if sel == true then
	  local retval, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, newstart) -- retval每小节
      if newstart >= math.floor(Bar_Start_QN) + min_meas and newstart < math.floor(Bar_Start_QN) + max_meas then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

function DUR()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    x = ppq_end - ppq_start
    if sel == true then
      if x >= min_dur and x <= max_dur then -- 定义长度范围
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Note (By Duration)"
reaper.Undo_BeginBlock()
DUR()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()