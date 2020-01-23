--[[
 * ReaScript Name: Scale Velocity (Enhanced Version)
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
 * v1.0 (2020-01-23)
  + Initial release
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  reaper.MIDI_DisableSort(take)
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  if #index > 0 then
    local _, _, _, _, _, _, _, begin_vel = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, _, _, _, _, end_vel = reaper.MIDI_GetNote(take, index[#index])
    local cur_range = tostring(begin_vel)..','..tostring(end_vel)..','.."0"
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", cur_range)
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local vel_start, vel_end, toggle = userInputsCSV:match("(.*),(.*),(.*)")
    if not vel_start:match('[%d%.]+') or not vel_end:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    vel_start, vel_end, toggle = tonumber(vel_start), tonumber(vel_end), tonumber(toggle)
    reaper.SetExtState("ScaleVelocity", "ToggleValue", toggle, 0)
    local offset = (vel_end - vel_start) / (cnt - 1)
    local has_state = reaper.HasExtState("ScaleVelocity", "ToggleValue")
    if has_state == true then
      state = reaper.GetExtState("ScaleVelocity", "ToggleValue")
    end
    for i = 1, #index do
      local _, _, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      local x = math.floor(0.5 + vel*(vel_start/100))
      local y = math.floor(0.5 + vel_start)
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      if y > 127 then y = 127 elseif y < 1 then y = 1 end
      if state == "1" then
        reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
        vel_start = vel_start + offset
      else
        reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, y, false)
        vel_start = vel_start + offset
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