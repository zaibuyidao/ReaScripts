--[[
 * ReaScript Name: Event Value +10
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes or CC Events. Run.
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
 * v1.0 (2020-2-4)
  + Initial release
--]]

local j = 10

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

function NOTES()
  for i = 0,  notes-1 do
    _, sel, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      local x = vel+j
      if x > 127 then x = 127 end
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
      if y > 127 then y = 127 end
      reaper.MIDI_SetCC(take, i, nil, nil, nil, nil, nil, nil, y, false)
    end
    i=i+1
  end
end

script_title = "Event Value +10"
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
NOTES()
CCS()
reaper.UpdateArrange()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()