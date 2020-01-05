--[[
 * ReaScript Name: Select Note (By Channel)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 2.0
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
 * v2.0 (2019-1-5)
  + Version update
 * v1.0 (2019-12-29)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Note By Channel", 2, "Min,Max", "1,16")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_chan, max_chan = dialog_ret_vals:match("(.*),(.*)")
min_chan, max_chan = tonumber(min_chan) -1, tonumber(max_chan) -1
if min_chan > 16 or max_chan > 16 or min_chan < 0 or max_chan < 0 then return reaper.MB("Please enter a value from 1 through 16", "Error", 0), reaper.SN_FocusMIDIEditor() end

function CHAN()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      if chan >= min_chan and chan <= max_chan then -- 定义通道范围
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Note (By Channel)"
reaper.Undo_BeginBlock()
CHAN()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()