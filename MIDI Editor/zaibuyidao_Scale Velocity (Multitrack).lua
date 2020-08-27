--[[
 * ReaScript Name: Scale Velocity (Multitrack)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-26)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  vel_start = reaper.GetExtState("ScaleVelocity", "Start")
  vel_end = reaper.GetExtState("ScaleVelocity", "End")
  toggle = reaper.GetExtState("ScaleVelocity", "Toggle")
  if (vel_start == "") then vel_start = "100" end
  if (vel_end == "") then vel_end = "100" end
  if (toggle == "") then toggle = "0" end

  local user_ok, user_input_csv = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", vel_start..','..vel_end..','.. toggle)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  vel_start, vel_end, toggle = user_input_csv:match("(%d*),(%d*),(%d*)")
  if not tonumber(vel_start) or not tonumber(vel_end) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
  if tonumber(vel_start) < 1 then vel_start = 1 elseif tonumber(vel_start) > 127 then vel_start = 127 end
  if tonumber(vel_end) < 1 then vel_end = 1 elseif tonumber(vel_end) > 127 then vel_end = 127 end
  reaper.SetExtState("ScaleVelocity", "Start", vel_start, false)
  reaper.SetExtState("ScaleVelocity", "End", vel_end, false)
  reaper.SetExtState("ScaleVelocity", "Toggle", toggle, false)

  count_sel_items = reaper.CountSelectedMediaItems(0)

  if count_sel_items > 0 then
    for i = 1, count_sel_items do
      item = reaper.GetSelectedMediaItem(0, i - 1)
      take = reaper.GetTake(item, 0)
      if not take or not reaper.TakeIsMIDI(take) then return end

      local cnt, index = 0, {}
      local val = reaper.MIDI_EnumSelNotes(take, -1)
      while val ~= - 1 do
        cnt = cnt + 1
        index[cnt] = val
        val = reaper.MIDI_EnumSelNotes(take, val)
      end

      reaper.MIDI_DisableSort(take)

      if #index > 0 then
        local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
        local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
        local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
        for i = 1, #index do
          local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
          if toggle == "1" then
            if end_ppqpos ~= begin_ppqpos then
              new_vel = vel * (((startppqpos - begin_ppqpos) * ppq_offset + vel_start) / 100)
              x = math.floor(new_vel)
            else
              x = vel_start
            end
          else
            if end_ppqpos ~= begin_ppqpos then
              new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
              x = math.floor(new_vel)
            else
              x = vel_start
            end
          end
          if x > 127 then x = 127 elseif x < 1 then x = 1 end
          reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
        end
      end
      reaper.MIDI_Sort(take)
    end
  else
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    
    local cnt, index = 0, {}
    local val = reaper.MIDI_EnumSelNotes(take, -1)
    while val ~= - 1 do
      cnt = cnt + 1
      index[cnt] = val
      val = reaper.MIDI_EnumSelNotes(take, val)
    end
  
    reaper.MIDI_DisableSort(take)
  
    if #index > 0 then
      local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
      local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
      local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
      for i = 1, #index do
        local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
        if toggle == "1" then
          if end_ppqpos ~= begin_ppqpos then
            new_vel = vel * (((startppqpos - begin_ppqpos) * ppq_offset + vel_start) / 100)
            x = math.floor(new_vel)
          else
            x = vel_start
          end
        else
          if end_ppqpos ~= begin_ppqpos then
            new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
            x = math.floor(new_vel)
          else
            x = vel_start
          end
        end
        if x > 127 then x = 127 elseif x < 1 then x = 1 end
        reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
      end
    end
    reaper.MIDI_Sort(take)
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Scale Velocity (Multitrack)", 0)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.SN_FocusMIDIEditor()