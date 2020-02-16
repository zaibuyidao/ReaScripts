--[[
 * ReaScript Name: Insert CC Events 1 (For Selected Notes)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 2.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v2.0 (2020-1-5)
  + Version update
 * v1.0 (2019-12-12)
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
  local retval, userInputsCSV = reaper.GetUserInputs("Insert CC Events 1", 2, "CC Number,Value", "11,127")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local msg2, msg3 = userInputsCSV:match("(.*),(.*)")
  msg2, msg3 = tonumber(msg2), tonumber(msg3)

  for i = 0,  notes-1 do
    retval, selected, muted, ppq, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, msg2, msg3)
      reaper.UpdateItemInProject(item)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Insert CC Events 1"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()