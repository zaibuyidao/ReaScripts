--[[
 * ReaScript Name: Groove Quantize
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  userOK, fudu = reaper.GetUserInputs("Groove Quantize", 1, "Amount", "3")
  if not userOK then return reaper.SN_FocusMIDIEditor() end
  fudu = tonumber(fudu)
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
	newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppq_start)
    if sel == true then
      if newstart == math.floor(newstart) then -- 定义0位置
        local x = vel - 1 + math.random(fudu + 1)
        if x > 127 then x = 127 end
        if x < 1 then x = 1 end
        reaper.MIDI_SetNote(take, i, sel, muted, ppq_start, ppq_end, chan, pitch, math.floor(x), true)
      elseif  newstart == math.floor(newstart) + 0.5 then -- 定义240位置
        local y = vel - 1 - fudu + math.random(fudu + 1)
        if y > 127 then y = 127 end
        if y < 1 then y = 1 end
        reaper.MIDI_SetNote(take, i, sel, muted, ppq_start, ppq_end, chan, pitch, math.floor(y), true)
      else
	    vel = vel - fudu*2
	    local z = vel - 1 + math.random(fudu*2 + 1)
        if z > 127 then z = 127 end
        if z < 1 then z = 1 end
        reaper.MIDI_SetNote(take, i, sel, muted, ppq_start, ppq_end, chan, pitch, math.floor(z), true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Groove Quantize"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()