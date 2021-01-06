--[[
 * ReaScript Name: Interval
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-1)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local script_title = "Interval"
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
local value = reaper.GetExtState("Interval", "Value")
if (value == "") then value = "7" end
user_ok, value = reaper.GetUserInputs("Interval", 1, "Enter a semitone", value)
if not user_ok or not tonumber(value) then return reaper.SN_FocusMIDIEditor() end
value = tonumber(value)
reaper.SetExtState("Interval", "Value", value, false)

reaper.Undo_BeginBlock() -- 撤銷塊開始

local note = {}
for i = 1, notecnt do
  note[i] = {}
  note[i].ret, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel = reaper.MIDI_GetNote(take, i - 1)
end

for i = 1, notecnt do
  if note[i].sel then
    note[i].pitch = note[i].pitch + value
    if note[i].pitch < 127 and note[i].pitch > 0 then
      reaper.MIDI_InsertNote(take, note[i].sel, note[i].muted, note[i].startppqpos, note[i].endppqpos, note[i].chan, note[i].pitch, note[i].vel, false)
    end
  end
end

reaper.Undo_EndBlock(script_title, -1) -- 撤銷塊結束
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI編輯器