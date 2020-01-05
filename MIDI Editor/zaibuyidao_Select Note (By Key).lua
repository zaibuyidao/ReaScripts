--[[
 * ReaScript Name: Select Note (By Key)
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
 * v2.0 (2020-1-5)
  + Version update
 * v1.0 (2019-12-27)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Note By Key", 2, "Min,Max", "0,127")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_key, max_key = dialog_ret_vals:match("(.*),(.*)")
min_key, max_key = tonumber(min_key), tonumber(max_key)
if min_key > 127 or max_key > 127 or min_key < 0 or max_key < 0 then return reaper.MB("Please enter a value from 0 through 127", "Error", 0), reaper.SN_FocusMIDIEditor() end

function KEY()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      if pitch >= min_key and pitch <= max_key then -- 定义音高范围
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Note (By Key)"
reaper.Undo_BeginBlock()
KEY()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()