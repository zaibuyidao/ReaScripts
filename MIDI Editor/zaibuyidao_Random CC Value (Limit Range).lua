--[[
 * ReaScript Name: Random CC Value (Limit Range)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Event. Run.
 * Version: 2.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v2.0 (2019-1-5)
  + Version update
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  userOK, dialog_ret_vals = reaper.GetUserInputs("Random CC Value", 2, "Min Value,Max Value", "1,127")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  min_val, max_val = dialog_ret_vals:match("(.*),(.*)")
  min_val, max_val = tonumber(min_val), tonumber(max_val)

  if min_val > 127 then
    min_val = 127
  elseif
    min_val < 1 then
    min_val = 1
  elseif
    max_val > 127 then
    max_val = 127
  elseif
    max_val < 1 then
    max_val = 1
  elseif
    min_val > max_val then
    local t = max_val
    max_val = min_val
    min_val = t
  end

  if min_val == max_val then 
    return reaper.MB("Random interval is empty.", "Error", 0),
           reaper.SN_FocusMIDIEditor()
  end

  local diff = max_val - min_val
  for i = 0, ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      local x = tonumber(min_val + math.random(diff))
      reaper.MIDI_SetCC(take, i, sel, mutedIn, ppqposIn, chanmsgIn, chanIn, msg2In, x, true)
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Random CC Value"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
