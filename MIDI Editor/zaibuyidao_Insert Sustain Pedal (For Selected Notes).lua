--[[
 * ReaScript Name: Insert Sustain Pedal (For Selected Notes)
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
 * v1.0 (2020-3-24)
  + Initial release
--]]

selected = true
muted = false
chan = 0

function main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  item = reaper.GetMediaItemTake_Item(take)
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  local retval, userInputsCSV = reaper.GetUserInputs("Insert Sustain Pedal", 5, "CC Number,First Value,Second Value,First Offset,Second Offset", "64,127,0,0,-60")
  if not retval then return reaper.SN_FocusMIDIEditor() end
  local msg2, msg3, msg4, first_offset, second_offset = userInputsCSV:match("(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) or not tonumber(first_offset) or not tonumber(second_offset) then return reaper.SN_FocusMIDIEditor() end
  for i = 1,  #index do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      reaper.MIDI_InsertCC(take, selected, muted, startppqpos + first_offset, 0xB0, chan, msg2, msg3)
      if i > 1 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + second_offset, 0xB0, chan, msg2, msg4)
      end
      reaper.UpdateItemInProject(item)
    end
  end
  reaper.UpdateArrange()
end
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Insert Sustain Pedal (For Selected Notes)", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()