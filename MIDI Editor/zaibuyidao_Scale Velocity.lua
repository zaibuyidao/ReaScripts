--[[
 * ReaScript Name: Scale Velocity
 * Version: 2.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-01-23)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
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
    local vel_start = reaper.GetExtState("ScaleVelocity", "Start")
    local vel_end = reaper.GetExtState("ScaleVelocity", "End")
    local toggle = reaper.GetExtState("ScaleVelocity", "Toggle")
    if (vel_start == "") then vel_start = "100" end
    if (vel_end == "") then vel_end = "100" end
    if (toggle == "") then toggle = "0" end
    
    local user_ok, user_input_csv = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", vel_start..','..vel_end..','.. toggle)
    if not user_ok then return reaper.SN_FocusMIDIEditor() end
    vel_start, vel_end, toggle = user_input_csv:match("(%d*),(%d*),(%d*)")
    if not tonumber(vel_start) or not tonumber(vel_end) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("ScaleVelocity", "Start", vel_start, false)
    reaper.SetExtState("ScaleVelocity", "End", vel_end, false)
    reaper.SetExtState("ScaleVelocity", "Toggle", toggle, false)

    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
    local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)

    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      if toggle == "1" then
        if end_ppqpos ~= begin_ppqpos then
          new_vel = vel * (((startppqpos - begin_ppqpos) * ppq_offset + vel_start) / 100)
          velocity = math.floor(new_vel)
        else
          velocity = vel_start
        end
      else
        if end_ppqpos ~= begin_ppqpos then
          new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
          velocity = math.floor(new_vel)
        else
          velocity = vel_start
        end
      end
      velocity = tonumber(velocity)
      if velocity > 127 then velocity = 127 elseif velocity < 1 then velocity = 1 end
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, velocity, false)
    end
  end

  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Scale Velocity", 0)
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
if CFNV then main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
