--[[
 * ReaScript Name: Select CC (By Number)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Events. Run.
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
 * v1.0 (2020-1-1)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select CC (By Number)", 2, "Min,Max", "0,127")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_num, max_num = dialog_ret_vals:match("(.*),(.*)")
min_num, max_num = tonumber(min_num), tonumber(max_num)
if min_num > 127 or max_num > 127 or min_num < 0 or max_num < 0 then return reaper.MB("Please enter a value from 0 through 127", "Error", 0), reaper.SN_FocusMIDIEditor() end

function NUM()
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      if msg2 >= min_num and msg2 <= max_num then  -- 定义控制器范围
        reaper.MIDI_SetCC(take, i, true, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      else
        reaper.MIDI_SetCC(take, i, false, muted, ppqpos, chanmsg, chan, msg2, msg3, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select CC (By Number)"
reaper.Undo_BeginBlock()
NUM()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()