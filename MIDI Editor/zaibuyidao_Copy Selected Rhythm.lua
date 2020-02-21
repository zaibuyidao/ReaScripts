--[[
 * ReaScript Name: Copy Selected Rhythm
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
 * v1.0 (2020-2-21)
  + Initial release
--]]

function CopySelectedRhythm()
  local midieditor = reaper.MIDIEditor_GetActive()
  if not midieditor then return end
  local take = reaper.MIDIEditor_GetTake(midieditor)
  if not take or not reaper.TakeIsMIDI(take) then return end
  local _, notecnt = reaper.MIDI_CountEvts(take)    
  local t = {}
  local str = ""
  for i = 1, notecnt do
    _, sel, _, s, e, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
    local meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, s)
    local sppq = s - meas
    local eppq = e - meas
   if sel == true then str = str..'\n '..math.floor(sppq)..' '..math.floor(eppq) end
  end
  reaper.SetExtState('CopySelectedRhythm', 'buf', str, false)
end

title = "Copy Selected Rhythm"
reaper.Undo_BeginBlock()
CopySelectedRhythm()
reaper.Undo_EndBlock(title, 0)