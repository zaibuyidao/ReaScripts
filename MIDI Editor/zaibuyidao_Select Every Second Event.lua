--[[
 * ReaScript Name: Select Every Second Event
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes And CC Events. Run.
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
 * v1.0 (2020-1-23)
  + Initial release
--]]

local step = 2
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local _, notes, ccs, _ = reaper.MIDI_CountEvts(take)
function Notes()
  for i = 0, notes-1, step do
    local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      if step == 2 then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    i=i+1
  end
end
function CCs()
  for i = 0, ccs-1, step do
    local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if selected == true then
      if step == 2 then
        reaper.MIDI_SetCC(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    i=i+1
  end
end
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
Notes()
CCs()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Select Every Second Event", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()