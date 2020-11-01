--[[
 * ReaScript Name: Add Semitones
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-1)
  + Initial release
--]]

function Msg(value)
	if console then
		reaper.ShowConsoleMsg(tostring(value) .. "\n")
	end
end

--if console then reaper.ClearConsole() end

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
_, notecnt, _, _ = reaper.MIDI_CountEvts(take)

offset = reaper.GetExtState("AddSemitones", "Semitones")
if (offset == "") then offset = "7" end
user_ok, offset = reaper.GetUserInputs("Add Semitones", 1, "Use 12 to add 1 octave", offset)
offset = tonumber(offset)
reaper.SetExtState("AddSemitones", "Semitones", offset, false)

local note = {}

for i = 1, notecnt do
    note[i] = {}
    note[i].ret, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel = reaper.MIDI_GetNote(take, i - 1)
end

for i = 1, notecnt do
  if note[i].sel then
    note[i].pitch = note[i].pitch + offset
    if note[i].pitch < 127 and note[i].pitch > 0 then
      reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel, false)
    end
  end
end