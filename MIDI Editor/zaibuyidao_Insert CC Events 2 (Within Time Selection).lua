--[[
 * ReaScript Name: Insert CC Events 2 (Within Time Selection)
 * Instructions: Open a MIDI take in MIDI Editor. Set Time Selection, Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-5)
  + Initial release
--]]

selected = true
chan = 0
muted = false
reaper.Undo_BeginBlock()
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
local cc_len = math.floor(loop_end - loop_start)
if cc_len == 0 then return reaper.MB("Please set the time selection range first.", "Error", 0), reaper.SN_FocusMIDIEditor()  end
local userOK, userInputsCSV = reaper.GetUserInputs("Insert CC Events 2", 3, "CC Number,First Value,Second Value", "11,100,0")
if not userOK then return reaper.SN_FocusMIDIEditor() end
local msg2, msg3, msg4 = userInputsCSV:match("(.*),(.*),(.*)")
msg2, msg3, msg4, tick = tonumber(msg2), tonumber(msg3), tonumber(msg4), tonumber(tick)
reaper.MIDI_InsertCC(take, selected, muted, loop_start, 0xB0, chan, msg2, msg3)
reaper.MIDI_InsertCC(take, selected, muted, loop_end, 0xB0, chan, msg2, msg4)
reaper.Undo_EndBlock("Insert CC Events 2 (Within Time Selection)", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()