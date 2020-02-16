--[[
 * ReaScript Name: Set CC Value (Percentages)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Event. Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-19)
  + Initial release
--]]

local retval, user_input = reaper.GetUserInputs('Set CC Value', 1, 'Percentages', '125')
if not retval then return reaper.SN_FocusMIDIEditor() end

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      local x = math.floor(msg3 * (user_input/100))
      if x > 127 then x = 127 end
      if x < 1 then x = 1 end
      reaper.MIDI_SetCC(take, i, sel, mutedIn, ppqposIn, chanmsgIn, chanIn, msg2In, x, false)
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Set CC Value (Percentages)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
