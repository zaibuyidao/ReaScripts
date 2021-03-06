--[[
 * ReaScript Name: Event Value -01
 * Version: 1.1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-1-27)
  + Initial release
--]]

local j = -1

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

function NOTES()
  for i = 0,  notes-1 do
    _, sel, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      local x = vel+j
      if x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, i, nil, nil, nil, nil, nil, nil, x, false)
    end
    i=i+1
  end
end

function CCS()
  for i = 0,  ccs-1 do
    _, sel, _, _, _, _, _, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      local y = msg3+j
      if y < 0 then y = 0 end
      reaper.MIDI_SetCC(take, i, sel, nil, nil, nil, nil, nil, y, false)
    end
    i=i+1
  end
end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
NOTES()
CCS()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Event Value -01", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()