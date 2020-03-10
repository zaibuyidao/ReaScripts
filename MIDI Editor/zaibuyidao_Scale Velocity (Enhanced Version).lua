--[[
 * ReaScript Name: Scale Velocity (Enhanced Version)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.4
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
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    local vel_start = reaper.GetExtState("ScaleVelocityEV", "Start")
    local vel_end = reaper.GetExtState("ScaleVelocityEV", "End")
    local vel_toggle = reaper.GetExtState("ScaleVelocityEV", "Toggle")
    if (vel_start == "") then vel_start = "100" end
    if (vel_end == "") then vel_end = "100" end
    if (vel_toggle == "") then vel_toggle = "0" end
    local userOK, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", vel_start..','..vel_end..','.. vel_toggle)
    if not userOK then return reaper.SN_FocusMIDIEditor() end
    vel_start, vel_end, vel_toggle = userInputsCSV:match("(%d*),(%d*),(%d*)")
    if not vel_start:match('[%d%.]+') or not vel_end:match('[%d%.]+') or not vel_toggle:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("ScaleVelocityEV", "Start", vel_start, false)
    reaper.SetExtState("ScaleVelocityEV", "End", vel_end, false)
    reaper.SetExtState("ScaleVelocityEV", "Toggle", vel_toggle, false)
    reaper.SetExtState("ScaleVelocityEV", "ToggleValue", vel_toggle, 0)
    local has_state = reaper.HasExtState("ScaleVelocityEV", "ToggleValue")
    if has_state == true then
      state = reaper.GetExtState("ScaleVelocityEV", "ToggleValue")
    end
    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
    local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
    local vel_offset = (vel_end - vel_start) / (cnt - 1)
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
  else
    reaper.MB("Please select one or more notes","Error",0)
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Scale Velocity (Enhanced Version)", 0)
end
function CheckForNewVersion(new_version)
    local app_version = reaper.GetAppVersion()
    app_version = tonumber(app_version:match('[%d%.]+'))
    if new_version > app_version then
      reaper.MB('Update REAPER to newer version '..'('..new_version..' or newer)', '', 0)
      return
    else
      return true
    end
end
local CFNV = CheckForNewVersion(6.03)
if CFNV then Main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()