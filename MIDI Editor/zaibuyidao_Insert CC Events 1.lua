--[[
 * ReaScript Name: Insert CC Events 1
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-19)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local cur_pos = reaper.GetCursorPositionEx(0)
  local ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos)
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  
  local msg3 = reaper.GetExtState("InsertCCEvents1", "Value")
  local msg2 = reaper.GetExtState("InsertCCEvents1", "CC_Num")
  if (msg3 == "") then msg3 = "100" end
  if (msg2 == "") then msg2 = "11" end

  local user_ok, user_input_csv = reaper.GetUserInputs("Insert CC Events 1", 2, "Value,CC Number", msg3..','..msg2)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  msg3, msg2 = user_input_csv:match("(.*),(.*)")
  msg3, msg2 = tonumber(msg3), tonumber(msg2)

  reaper.SetExtState("InsertCCEvents1", "Value", msg3, false)
  reaper.SetExtState("InsertCCEvents1", "CC_Num", msg2, false)

  if #index > 0 then
    for i = 1,  #index do
      local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, msg2, msg3)
      end
    end
  else
    reaper.MIDI_InsertCC(take, true, false, ppq_pos, 0xB0, 0, msg2, msg3)
  end
end
reaper.Undo_BeginBlock()
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert CC Events 1", -1)
reaper.SN_FocusMIDIEditor()