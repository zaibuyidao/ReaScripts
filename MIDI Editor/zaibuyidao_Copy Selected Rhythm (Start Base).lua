--[[
 * ReaScript Name: Copy Selected Rhythm (Start Base)
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

function CopySelectedRhythm()
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
  local t = {}
  local str = ""
  local _, _, _, b, _, _, _, _ = reaper.MIDI_GetNote(take, index[1]) -- 以第一个音符的起始位置作为复制节奏的起点
  for i = 1, #index do
    _, _, _, s, e, _, _, v = reaper.MIDI_GetNote(take, index[i])
    local sppq = s - b
    local eppq = e - b
    str = str..'\n '..math.floor(sppq)..' '..math.floor(eppq)..' '..math.floor(v)
  end
  reaper.SetExtState('CopySelectedRhythm', 'buf', str, false)
end
reaper.Undo_BeginBlock()
CopySelectedRhythm()
reaper.Undo_EndBlock("Copy Selected Rhythm (Start Base)", 0)