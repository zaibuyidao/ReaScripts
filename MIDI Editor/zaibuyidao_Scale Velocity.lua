--[[
 * ReaScript Name: Scale Velocity
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.7
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showthread.php?t=225108
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.6 (2020-01-29)
  # Bug fix
 * v1.0 (2019-12-12)
  + Initial release
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
  if cnt == 0 then return reaper.MB("Please select one or more notes","Error",0), reaper.SN_FocusMIDIEditor() end
  local _, _, _, begin_ppqpos, _, _, _, begin_vel = reaper.MIDI_GetNote(take, index[1])
  local _, _, _, end_ppqpos, _, _, _, end_vel = reaper.MIDI_GetNote(take, index[#index])
  local cur_range = tostring(begin_vel)..','..tostring(end_vel)
  local retval, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 2, "Begin,End", cur_range)
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local vel_first, vel_end = userInputsCSV:match("(%d*),(%d*)")
  vel_first, vel_end = tonumber(vel_first), tonumber(vel_end)
  if vel_first > 127 or vel_end > 127 or vel_first < 1 or vel_end < 1 then return reaper.MB("Please enter a value from 1 through 127", "Error", 0), reaper.SN_FocusMIDIEditor() end
  local ppq_offset = (vel_end - vel_first) / (end_ppqpos - begin_ppqpos)
  reaper.MIDI_DisableSort(take)
  for i = 1, #index do
    local _, _, _, startppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[i])
    if end_ppqpos ~= begin_ppqpos then
      local new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_first
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, math.floor(0.5 + new_vel), false)
    else
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, vel_first, false)
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Scale Velocity"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()