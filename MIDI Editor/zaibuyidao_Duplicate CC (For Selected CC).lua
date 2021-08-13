--[[
 * ReaScript Name: Duplicate CC (For Selected CC)
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-6-12)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
  local cc_new = reaper.GetExtState("DuplicateCCForSelectedCC", "CC_New")
  if (cc_new == "") then cc_new = "11" end
  local user_ok, user_input_CSV = reaper.GetUserInputs('Duplicate CC (For Selected CC)', 1, 'Target CC', cc_new)
  cc_new = user_input_CSV:match("(.*)")
  if not user_ok or not tonumber(cc_new) then return reaper.SN_FocusMIDIEditor() end
  cc_new = tonumber(cc_new)
  if cc_new > 127 or cc_new < 0 then
    return
    reaper.MB("Please enter a value from 0 through 127", "Error", 0),
    reaper.SN_FocusMIDIEditor()
  end
  reaper.SetExtState("DuplicateCCForSelectedCC", "CC_New", cc_new, false)
  reaper.MIDI_DisableSort(take)
  for i = 1, ccevtcnt do
    local _, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, ppqpos, chanmsg, chan, cc_new, msg3)
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Duplicate CC (For Selected CC)", -1)
reaper.SN_FocusMIDIEditor()
