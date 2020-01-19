--[[
 * ReaScript Name: Bank Program Select (Bank Select MSB LSB)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.3 (2020-1-20)
  + Organize the code
 * v1.0 (2019-12-12)
  + Initial release
--]]

selected = false
muted = false
chan = 0 -- Channel 1

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  item = reaper.GetMediaItemTake_Item(take)
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  local retval, userInputsCSV = reaper.GetUserInputs("Bank/Program Select", 3, "Bank MSB,Bank LSB,Program Change", "2,3,27")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local MSB, LSB, PC = userInputsCSV:match("(.*),(.*),(.*)")
  for i = 0,  notes-1 do
    retval, selected, muted, ppq, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, 0, MSB) -- CC#00
      reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, 32, LSB) -- CC#32
      reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xC0, chan, PC, 0) -- Program Change
      reaper.UpdateItemInProject(item)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Insert Bank/Program Select"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()