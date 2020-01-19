--[[
 * ReaScript Name: Random CC Value
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Event. Run.
 * Version: 2.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v2.1 (2020-1-20)
  # Improve processing speed
 * v2.0 (2019-1-5)
  + Version update
 * v1.0 (2019-12-12)
  + Initial release
--]]

local diff = 127

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      local x = math.random(diff)
      reaper.MIDI_SetCC(take, i, _, _, _, _, _, _, x, false)
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
