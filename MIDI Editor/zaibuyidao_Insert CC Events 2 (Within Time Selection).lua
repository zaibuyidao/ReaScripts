--[[
 * ReaScript Name: Insert CC Events 2 (Within Time Selection)
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
local loop_range = math.floor(loop_end - loop_start)
if loop_range == 0 then return reaper.MB("Please set the time selection range first.", "Error", 0), reaper.SN_FocusMIDIEditor()  end

local msg2 = reaper.GetExtState("InsertCCEvents2TimeSel", "Msg2")
if (msg2 == "") then msg2 = "11" end
local msg3 = reaper.GetExtState("InsertCCEvents2TimeSel", "Msg3")
if (msg3 == "") then msg3 = "100" end
local msg4 = reaper.GetExtState("InsertCCEvents2TimeSel", "Msg4")
if (msg4 == "") then msg4 = "0" end

local user_ok, user_input_csv = reaper.GetUserInputs("Insert CC Events 2", 3, "CC Number,1,2", msg2 ..','.. msg3 ..','.. msg4)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
msg2, msg3, msg4 = user_input_csv:match("(.*),(.*),(.*)")
if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("InsertCCEvents2TimeSel", "Msg2", msg2, false)
reaper.SetExtState("InsertCCEvents2TimeSel", "Msg3", msg3, false)
reaper.SetExtState("InsertCCEvents2TimeSel", "Msg4", msg4, false)

msg2, msg3, msg4 = tonumber(msg2), tonumber(msg3), tonumber(msg4)

reaper.MIDI_InsertCC(take, selected, muted, loop_start, 0xB0, chan, msg2, msg3)
reaper.MIDI_InsertCC(take, selected, muted, loop_end, 0xB0, chan, msg2, msg4)
reaper.Undo_EndBlock("Insert CC Events 2 (Within Time Selection)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()