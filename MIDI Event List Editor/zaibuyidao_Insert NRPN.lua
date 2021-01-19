--[[
 * ReaScript Name: Insert NRPN
 * Version: 2.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

interval = 10

function NonRegParm()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local curpos = reaper.GetCursorPositionEx()
  local curppq = reaper.MIDI_GetPPQPosFromProjTime(take, curpos)

  local LSB = reaper.GetExtState("InsertNRPN", "LSB")
  local MSB = reaper.GetExtState("InsertNRPN", "MSB")
  if (LSB == "") then LSB = "0" end
  if (MSB == "") then MSB = "64" end

  local user_ok, user_input_CSV = reaper.GetUserInputs("Insert NRPN", 2, "98-NRPN,6-Data Entry", LSB .. ',' .. MSB)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  LSB, MSB = user_input_CSV:match("(.*),(.*)")
  if not tonumber(LSB) or not tonumber(MSB) then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("InsertNRPN", "LSB", LSB, false)
  reaper.SetExtState("InsertNRPN", "MSB", MSB, false)

  reaper.MIDI_SelectAll(take, false) -- 取消選擇所有MIDI內容
  reaper.MIDI_InsertCC(take, false, false, curppq + interval, 0xB0, 0, 98, LSB)
  reaper.MIDI_InsertCC(take, true, false, curppq + interval * 2, 0xB0, 0, 6, MSB)
  reaper.SetEditCurPos(reaper.MIDI_GetProjTimeFromPPQPos(take, curppq + interval * 2), true, true)
end

reaper.Undo_BeginBlock()
NonRegParm()
reaper.Undo_EndBlock("Insert NRPN", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
