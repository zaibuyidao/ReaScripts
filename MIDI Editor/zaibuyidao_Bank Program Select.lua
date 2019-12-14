--[[
 * ReaScript Name: Bank Program Select
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.2
 * Author: zaibuyidao
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

selected = false
muted = false
chan = 0 -- Channel 1

function Main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  item = reaper.GetMediaItemTake_Item(take)
  local count, index = 0, {}
  local value = reaper.MIDI_EnumSelNotes(take, -1)
  while value ~= -1 do
    count = count + 1
    index[count] = value
    value = reaper.MIDI_EnumSelNotes(take, value)
  end
  if #index > 0 then
    local retval, userInputsCSV = reaper.GetUserInputs("Insert Bank/Program Select", 2, "Bank,Program Change", "259,27")
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local BANK, PC = userInputsCSV:match("(.*),(.*)")
    local MSB = math.modf(BANK / 128)
    local LSB = math.fmod(BANK, 128)
    for i = 1, #index do
      retval, selected, muted, ppq, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
        -- ppq = ppq - 0 -- 插入音色位置偏移
        reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, selected, muted, ppq, 0xC0, chan, PC, 0) -- Program Change
        reaper.UpdateItemInProject(item)
      end
  	  reaper.UpdateArrange()
	end
  else
    reaper.MB("Please select one or more notes","Error",0)
    reaper.SN_FocusMIDIEditor()
  end
end

script_title = "Insert Bank/Program Select"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
