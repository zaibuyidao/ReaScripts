--[[
 * ReaScript Name: Go To Time
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

function Main()
  userOK, get_input = reaper.GetUserInputs("Go To Time", 2, "Measure,Beat", "1,1.00")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  measure, beat = get_input:match("(.*),(.*)")
  measure, beat = tonumber(measure), tonumber(beat)
  local x = measure - 1
  local z = beat - 1
  reaper.SetEditCurPos(reaper.TimeMap2_beatsToTime(0, z, x), true, true)
end
script_title = "Go To Time"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
