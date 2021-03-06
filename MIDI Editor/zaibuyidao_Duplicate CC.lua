--[[
 * ReaScript Name: Duplicate CC
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
  local cc_num = reaper.GetExtState("DuplicateCC", "CC_Number")
  if (cc_num == "") then cc_num = "1" end
  local cc_new = reaper.GetExtState("DuplicateCC", "CC_New")
  if (cc_new == "") then cc_new = "11" end
  local user_ok, user_input = reaper.GetUserInputs('Duplicate CC', 2, 'Duplicate CC#,To CC#', cc_num ..','.. cc_new)
  cc_num, cc_new = user_input:match("(.*),(.*)")
  if not user_ok or not tonumber(cc_num) or not tonumber(cc_new) then return reaper.SN_FocusMIDIEditor() end

  cc_num, cc_new = tonumber(cc_num), tonumber(cc_new)

  if cc_num > 127 or cc_num < 0 or cc_new > 127 or cc_new < 0 then
    return
    reaper.MB("Please enter a value from 0 through 127", "Error", 0),
    reaper.SN_FocusMIDIEditor()
  end

  reaper.SetExtState("DuplicateCC", "CC_Number", cc_num, false)
  reaper.SetExtState("DuplicateCC", "CC_New", cc_new, false)

  reaper.MIDI_DisableSort(take)
  for i = 1, ccevtcnt do
    _, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
    if msg2 == cc_num then
      reaper.MIDI_InsertCC(take, selected, muted, ppqpos, chanmsg, chan, cc_new, msg3)
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Duplicate CC", -1)
reaper.SN_FocusMIDIEditor()
