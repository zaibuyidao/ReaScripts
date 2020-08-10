--[[
 * ReaScript Name: Note To Program Change (For JSFX-Simple Expression Map)
 * Instructions: Part of [JSFX: Simple Expression Map]. Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-8-4)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local MSB = reaper.GetExtState("NoteToProgramChange", "MSB")
  if (MSB == "") then MSB = "0" end
  local LSB
  local user_ok, MSB = reaper.GetUserInputs('Confirm Group Number', 1, 'Group Number (Defaul=0)', MSB)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  reaper.SetExtState("NoteToProgramChange", "MSB", MSB, false)
  _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)

  for i = 1, notecnt do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i - 1)
    if selected == true then
      if vel == 127 then
        LSB = 127
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
      end
      if vel == 1 then
        LSB = 1
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
      end
      if vel > 1 and vel < 127 then
        LSB = 0
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 0, MSB) -- CC#00
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, false, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
      end
      flag = true
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Note To Program Change"
reaper.Undo_BeginBlock()
main()
if flag then
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40667)
end
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
