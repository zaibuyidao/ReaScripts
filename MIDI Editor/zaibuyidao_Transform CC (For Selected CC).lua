--[[
 * ReaScript Name: Transform CC (For Selected CC)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Event. Run.
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
 * v1.0 (2020-6-24)
  + Initial release
--]]

function Main()
  local cc_new = reaper.GetExtState("TransformCC", "CC_New")
  if (cc_new == "") then cc_new = "11" end
  local user_ok, user_input = reaper.GetUserInputs('Transform CC', 1, 'CC#', cc_new)
  cc_new = user_input:match("(.*)")
  if not user_ok or not tonumber(cc_new) then return end
  reaper.SetExtState("TransformCC", "CC_New", cc_new, false)
  cc_new = tonumber(cc_new)
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  _, notecnt, ccevtcnt, textsyxevtcnt = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 1, ccevtcnt do
    _, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
    if sel == true then
      reaper.MIDI_SetCC(take, i - 1, nil, nil, nil, nil, nil, cc_new, nil, false)
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end
script_title = "Transform CC (For Selected CC)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
