--[[
 * ReaScript Name: 力度人性化
 * Version: 1.5.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
  local strength = reaper.GetExtState("HumanizeVelocity", "Strength")
  if (strength == "") then strength = "3" end
  local user_ok, user_input_CSV = reaper.GetUserInputs("力度人性化", 1, "強度", strength)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  strength = user_input_CSV:match("(.*)")
  reaper.SetExtState("HumanizeVelocity", "Strength", strength, false)
  strength = tonumber(strength*2)
  reaper.MIDI_DisableSort(take)
  for i = 0,  notecnt-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
	  vel = vel - strength/2 - 1
	  local x = vel+math.random(strength+1)
      if x > 127 then x = 127 end
      if x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, i, selected, muted, startppqpos, endppqpos, chan, pitch, math.floor(x), false)
    end
    i=i+1
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("力度人性化", -1)
reaper.SN_FocusMIDIEditor()
