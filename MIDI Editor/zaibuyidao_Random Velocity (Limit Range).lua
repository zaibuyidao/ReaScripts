--[[
 * ReaScript Name: Random Velocity (Limit Range)
 * Version: 1.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  _, notecnt, _, _ = reaper.MIDI_CountEvts(take)

  local min_val = reaper.GetExtState("RandVeloLimit", "Min")
  if (min_val == "") then min_val = "1" end
  local max_val = reaper.GetExtState("RandVeloLimit", "Max")
  if (max_val == "") then max_val = "127" end

  user_ok, user_input_csv = reaper.GetUserInputs("Random Velocity", 2, "Min Value,Max Value", min_val ..','.. max_val)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  min_val, max_val = user_input_csv:match("(.*),(.*)")
  if not tonumber(min_val) or not tonumber(max_val) then return reaper.SN_FocusMIDIEditor() end
  min_val, max_val = tonumber(min_val), tonumber(max_val)

  reaper.SetExtState("RandVeloLimit", "Min", min_val, false)
  reaper.SetExtState("RandVeloLimit", "Max", max_val, false)

  if min_val > 127 then
    min_val = 127
  elseif
    min_val < 1 then
    min_val = 1
  elseif
    max_val > 127 then
    max_val = 127
  elseif
    max_val < 1 then
    max_val = 1
  elseif
  min_val > max_val then
    local t = max_val
    max_val = min_val
    min_val = t
  end

  if min_val == max_val then 
    return reaper.MB("Random interval is empty, please re-enter", "Error", 0),
           reaper.SN_FocusMIDIEditor()
  end

  local diff = max_val - min_val
  reaper.MIDI_DisableSort(take)
  for i = 0,  notecnt-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      vel = tonumber(min_val + math.random(diff))
      reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, endppqpos, chan, pitch, vel, false)
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Random Velocity (Limit Range)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
