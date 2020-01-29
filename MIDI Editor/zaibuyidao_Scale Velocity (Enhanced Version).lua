--[[
 * ReaScript Name: Scale Velocity (Enhanced Version)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2020-01-29)
  # Bug fix
 * v1.1 (2020-01-27)
  # Solved the Line problem
 * v1.0 (2020-01-23)
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
  if #index > 0 then
    local _, _, _, begin_ppqpos, _, _, _, begin_vel = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, end_vel = reaper.MIDI_GetNote(take, index[#index])
    local cur_range = tostring(begin_vel)..','..tostring(end_vel)..','.."0"
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", cur_range)
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local vel_start, vel_end, toggle = userInputsCSV:match("(%d*),(%d*),(%d*)")
    if not vel_start:match('[%d%.]+') or not vel_end:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    vel_start, vel_end, toggle = tonumber(vel_start), tonumber(vel_end), tonumber(toggle)
    reaper.SetExtState("ScaleVelocity", "ToggleValue", toggle, 0)
    local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
    local vel_offset = (vel_end - vel_start) / (cnt - 1)
    local has_state = reaper.HasExtState("ScaleVelocity", "ToggleValue")
    if has_state == true then
      state = reaper.GetExtState("ScaleVelocity", "ToggleValue")
    end
    reaper.MIDI_DisableSort(take)
    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      if state == "1" then
        local x = math.floor(0.5 + vel*(vel_start/100))
        if x > 127 then x = 127 elseif x < 1 then x = 1 end
        reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
        vel_start = vel_start + vel_offset
      else
        if end_ppqpos ~= begin_ppqpos then
          local new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
          local y = math.floor(0.5 + new_vel)
          if y > 127 then y = 127 elseif y < 1 then y = 1 end
          reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, y, false)
        else
          reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, vel_start, false)
        end
      end
    end
    reaper.UpdateArrange()
    reaper.MIDI_Sort(take)
  else
    reaper.MB("Please select one or more notes","Error",0)
  end
end

script_title = "Scale Velocity (Enhanced Version)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
reaper.defer(function () end)