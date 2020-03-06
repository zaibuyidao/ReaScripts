--[[
 * ReaScript Name: Paste Selected Rhythm (Start Base)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-3-6)
  + Initial release
--]]

function PasteSelectedRhythm()
  local midieditor = reaper.MIDIEditor_GetActive()
  if not midieditor then return end
  local take = reaper.MIDIEditor_GetTake(midieditor)
  if not take or not reaper.TakeIsMIDI(take) then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  local _, _, _, b, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
  local _, notecnt = reaper.MIDI_CountEvts(take)
  str = reaper.GetExtState('CopySelectedRhythm', 'buf')
  if str == '' then return end
  t = {}
  for num in str:gmatch('[%d]+') do t[#t + 1] = tonumber(num)  end
  local t2 = {}
  for i = 1, #t-1, 3 do
    t2[#t2+1] = {sppq = t[i], eppq = t[i+1], vel = t[i+2]}
  end
  for i = 1, notecnt do
    retval, sel, m, s, e, c, p, v = reaper.MIDI_GetNote(take, i - 1)
    if sel == true then
      local meas = b
      for i = 1, #t2 do
        reaper.MIDI_InsertNote(take, false, m, meas + t2[i].sppq, meas + t2[i].eppq, c, p, t2[i].vel, true)
      end
    end
  end
  reaper.MIDIEditor_OnCommand(midieditor, 40002)
  reaper.MIDI_Sort(take)
end
reaper.Undo_BeginBlock()
PasteSelectedRhythm()
reaper.Undo_EndBlock("Paste Selected Rhythm (Start Base)", 0)