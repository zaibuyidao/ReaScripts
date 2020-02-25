--[[
 * ReaScript Name: Insert Random CC Events (For Selected Notes)
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
 * v1.0 (2019-2-24)
  + Initial release
--]]

selected = true
muted = false
chan = 0

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  item = reaper.GetMediaItemTake_Item(take)
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  local retval, userInputsCSV = reaper.GetUserInputs("Insert Random CC Events", 2, "CC Number,Range", "10,127")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local msg2, msg3 = userInputsCSV:match("(.*),(.*)")
  msg2, msg3 = tonumber(msg2), tonumber(msg3)

  for i = 0,  notes-1 do
    retval, selected, muted, ppq, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, msg2, math.random(msg3))
      reaper.UpdateItemInProject(item)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Insert Random CC Events (For Selected Notes)"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()