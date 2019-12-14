--[[
 * ReaScript Name: Insert Sustain Pedal
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
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

interval = 1920 -- 重复间隔. 480tick下每小节1920, 960tick下每小节3840.
selected = false

local retval, userInputsCSV = reaper.GetUserInputs("Insert Sustain Pedal", 6, "CC Number,On:0-63,Off:64-127,Repetition,First Offset,Second Offset", "64,127,0,10,110,-10")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cc_num, cc_begin, cc_end, cishu, first_offset, second_offset = userInputsCSV:match("(.*),(.*),(.*),(.*),(.*),(.*)")
cc_num, cc_begin, cc_end, cishu, first_offset, second_offset = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu), tonumber(first_offset), tonumber(second_offset)

function HoldPedalOn()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local pos = reaper.GetCursorPositionEx(0)
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  ppq = ppq - interval + first_offset -- 踩下偏移
  for i = 1, cishu do
    ppq = ppq + interval
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, cc_begin)
    i=i+1
  end
end

function HoldPedalOff()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local pos = reaper.GetCursorPositionEx(0)
  local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  ppq = ppq + second_offset -- 释放偏移
  for i = 1, cishu do
    ppq = ppq + interval
    reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, cc_end)
    i=i+1
  end
end

reaper.Undo_BeginBlock()
HoldPedalOn()
HoldPedalOff()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert Sustain Pedal", -1)
reaper.SN_FocusMIDIEditor()
