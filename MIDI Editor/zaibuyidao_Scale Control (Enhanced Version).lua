--[[
 * ReaScript Name: Scale Control (Enhanced Version)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Events. Run.
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
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  if #index > 0 then
    local _, _, _, _, _, _, _, begin_val = reaper.MIDI_GetCC(take, index[1])
    local _, _, _, _, _, _, _, end_val = reaper.MIDI_GetCC(take, index[#index])
    local cur_range = tostring(begin_val)..','..tostring(end_val)..','.."1"
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Control", 3, "Begin,End,0=Default 1=Percentages", cur_range)
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local val_start, val_end, toggle = userInputsCSV:match("(.*),(.*),(.*)")
    if not val_start:match('[%d%.]+') or not val_end:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    val_start, val_end, toggle = tonumber(val_start), tonumber(val_end), tonumber(toggle)
    reaper.SetExtState("ScaleControl", "ToggleValue", toggle, true)
    local offset = (val_end - val_start) / (cnt - 1)
    local has_state = reaper.HasExtState("ScaleControl", "ToggleValue")
    if has_state == true then
      state = reaper.GetExtState("ScaleControl", "ToggleValue")
    end
    for i = 1, #index do
      local _, _, _, _, _, _, _, vel = reaper.MIDI_GetCC(take, index[i])
      local x = math.floor(0.5 + vel*(val_start/100))
      local y = math.floor(0.5 + val_start)
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      if y > 127 then y = 127 elseif y < 1 then y = 1 end
      if state == "1" then
        reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
        val_start = val_start + offset
      else
        reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, y, false)
        val_start = val_start + offset
      end
    end
    reaper.UpdateArrange()
    reaper.MIDI_Sort(take)
  else
    reaper.MB("Please select one or more CC events","Error",0)
  end
end

script_title = "Scale Control (Enhanced Version)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
reaper.defer(function () end)