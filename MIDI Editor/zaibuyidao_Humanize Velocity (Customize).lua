-- @description Humanize Velocity (Customize)
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

-- USER AREA
-- Settings that the user can customize.

strength = 3

-- End of USER AREA

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ")
      end
    reaper.ShowConsoleMsg("\n")
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local _, noteCount, _, _ = reaper.MIDI_CountEvts(take)
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
for i = 0,  noteCount - 1 do
    local _, isSelected, muted, startppqpos, endppqpos, chan, pitch, velocity = reaper.MIDI_GetNote(take, i)
    if isSelected then
        local velocityChange = math.random(-strength, strength)
        local newVelocity = velocity + velocityChange
        if newVelocity > 127 then newVelocity = 127 end
        if newVelocity < 1 then newVelocity = 1 end
        reaper.MIDI_SetNote(take, i, isSelected, muted, startppqpos, endppqpos, chan, pitch, math.floor(newVelocity), false)
    end
end
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Humanize Velocity", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()