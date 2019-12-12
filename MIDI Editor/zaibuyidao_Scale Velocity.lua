--[[
 * ReaScript Name: Scale Velocity
 * Version: 1.0
 * Author: Edgemeal
 * 算法改进: zaibuyidao
 * Website: https://forum.cockos.com/showthread.php?t=225108
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end

  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end

  if #index > 1 then
    local _, _, _, _, _, _, _, begin_vel = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, _, _, _, _, end_vel = reaper.MIDI_GetNote(take, index[#index])
    local cur_range = tostring(begin_vel)..','..tostring(end_vel)
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 2, "Begin,End", cur_range)
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local vel_first, vel_end = userInputsCSV:match("(.*),(.*)")
    vel_first, vel_end = tonumber(vel_first), tonumber(vel_end)
    if vel_first > 127 or vel_end > 127 or vel_first < 1 or vel_end < 1 then return reaper.MB("Please enter a value from 1 through 127", "Error", 0), reaper.SN_FocusMIDIEditor() end
    local offset = (vel_end - vel_first) / (cnt - 1)
    for i = 1, #index do
      local retval, sel, muted, ppq_start, ppq_end, chan, pitch, _ = reaper.MIDI_GetNote(take, index[i])
      reaper.MIDI_SetNote(take, index[i], sel, muted, ppq_start, ppq_end, chan, pitch, math.floor(0.5 + vel_first), true)
      vel_first = vel_first + offset
    end
    reaper.UpdateArrange()
  else
    reaper.MB("Please select two or more notes","Error",0)
  end
end

script_title = "Scale Velocity"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
reaper.defer(function () end)