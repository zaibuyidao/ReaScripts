--[[
 * ReaScript Name: 插入彎音
 * Version: 1.4
 * Author: 再補一刀
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

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local pos = reaper.GetCursorPositionEx()
local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
local pitch = reaper.GetExtState("InsertPitchBend", "Pitch")
if (pitch == "") then pitch = "0" end
local user_ok, user_input_csv = reaper.GetUserInputs('插入彎音', 1, '值', pitch)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
pitch = user_input_csv:match("(.*)")
if not tonumber(pitch) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("InsertPitchBend", "Pitch", pitch, false)

local value = math.floor(pitch)
if value < -8192 or value > 8191 then
    return
        reaper.MB("請輸入一個介於-8192到8191之間的值", "錯誤", 0),
        reaper.SN_FocusMIDIEditor()
end

reaper.Undo_BeginBlock()
value = value + 8192
local LSB = value & 0x7f
local MSB = value >> 7 & 0x7f
reaper.MIDI_InsertCC(take, false, false, ppq, 224, 0, LSB, MSB)
reaper.Undo_EndBlock("插入彎音", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
