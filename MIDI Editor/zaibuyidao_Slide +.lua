--[[
 * ReaScript Name: Slide +
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

local j = 10

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

function Notes()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      reaper.MIDI_SetNote(take, i, sel, muted, ppq_start+j, ppq_end+j, chan, pitch, vel, true)
    end
    i=i+1
  end
end

function CCs()
  for i = 0,  ccs-1 do
    retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq+j, chanmsgIn, chanIn, msg2In, msg3In, true)
    end
    i=i+1
  end
end

script_title = "Slide +"
reaper.Undo_BeginBlock()
Notes()
CCs()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
