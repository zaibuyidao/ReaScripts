--[[
 * ReaScript Name: Insert CC Events 1-2 (For Selected Notes)
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
 * v1.0 (2019-2-28)
  + Initial release
--]]

selected = true
function main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  item = reaper.GetMediaItemTake_Item(take)
  _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
  local ok, userInputsCSV = reaper.GetUserInputs("Insert CC Events 1-2", 3, "CC Number,1,2", "10,1,127")
  if not ok then return reaper.SN_FocusMIDIEditor() end
  local msg2, msg3, msg4 = userInputsCSV:match("(.*),(.*),(.*)")
  msg2, msg3, msg4 = tonumber(msg2), tonumber(msg3), tonumber(msg4)
  local flag = true
  for i = 0, notecnt-1 do
    local retval, selected, muted, startpos, endpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      if flag == true then
        reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg3)
        flag = false
      else
        reaper.MIDI_InsertCC(take, selected, muted, startpos, 0xB0, chan, msg2, msg4)
        flag = true
      end
      reaper.UpdateItemInProject(item)
    end
    i=i+1
  end
end
script_title = "Insert CC Events 1-2 (For Selected Notes)"
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock(script_title, 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()