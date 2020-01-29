--[[
 * ReaScript Name: Scale Velocity (Percentages)
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
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Velocity (Percentages)", 2, "Begin,End", "100,100")
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local bfb_first, bfb_end = userInputsCSV:match("(.*),(.*)")
    bfb_first, bfb_end = tonumber(bfb_first), tonumber(bfb_end)
    local offset = (bfb_end - bfb_first) / (cnt - 1)
    for i = 1, #index do
      local _, _, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      local x = math.floor(0.5 + vel*(bfb_first/100))
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
      bfb_first = bfb_first + offset
    end
    reaper.UpdateArrange()
    reaper.MIDI_Sort(take)
  else
    reaper.MB("Please select one or more notes","Error",0)
  end
end

script_title = "Scale Velocity (Percentages)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
reaper.defer(function () end)