--[[
 * ReaScript Name: Select Top Notes In Chord (Leave Single Notes Selected)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showpost.php?p=1684673&postcount=5 (gofer)
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-2-25)
  + Initial release
--]]

function SelectTopNotes()
	local function max(t)
		local mn = nil
		for k, v in pairs(t) do
			if (mn == nil) then mn = v end
			if mn < v then mn = v end
		end
		return mn
	end

	local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
	local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
	local chord_pitch = {}
	local chord_prop = {}
	local chord_none = 0
	local time = {0.0, 0.0}

	if notecnt ~= 0 then
		sel = reaper.MIDI_EnumSelNotes(take, -1)
		while sel ~= -1 do
			local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, sel)
			local note_prop = {sel, selected, muted, startppqpos, endppqpos, chan, pitch, vel}
			if startppqpos > time[2] - 120 then
				time = {startppqpos, endppqpos}
				chord_pitch = {}
				table.insert(chord_pitch, pitch) -- chord_pitch[#chord_pitch + 1] = pitch
				chord_prop = {}
				table.insert(chord_prop, note_prop)
				if chord_none == 0 then
					chord_none = chord_none + 1
				end
			elseif startppqpos <= time[2] - 120 then
				chord_none = 0
				table.insert(chord_pitch, pitch)
				table.insert(chord_prop, note_prop)
				if endppqpos > time[2] then
					time = {time[1], endppqpos}
				end
			end
			for k = 1, #chord_prop do
				if chord_pitch[k] < max(chord_pitch) then
					reaper.MIDI_SetNote(take, chord_prop[k][1], false, chord_prop[k][3], chord_prop[k][4], chord_prop[k][5], chord_prop[k][6], chord_prop[k][7], chord_prop[k][8], true)
				end
			end
			sel = reaper.MIDI_EnumSelNotes(take, sel)
		end
		reaper.MIDI_Sort(take)
	end
end

reaper.Undo_BeginBlock()
SelectTopNotes()
reaper.Undo_EndBlock("Select Top Notes In Chord (Leave Single Notes Selected)", 0)
reaper.UpdateArrange()