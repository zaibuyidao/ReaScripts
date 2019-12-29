--[[
 * ReaScript Name: Insert Sustain Pedal
 * Instructions: Open a MIDI take in MIDI Editor. Position Edit Cursor, Run.
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
 * v1.3 (2019-12-30)
  + Updated algorithm to accurately generate CC event in measuers
  + 更新算法以在小节中准确生成CC事件
 * v1.0 (2019-12-12)
  + Initial release
--]]

local retval, userInputsCSV = reaper.GetUserInputs("Insert Sustain Pedal", 1, "Repetition", "99")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cishu = userInputsCSV:match("(.*)")
cishu = tonumber(cishu)

function HoldPedalOn()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  for i = 1, cishu do
    local pos = reaper.GetCursorPositionEx(0) -- 获得光标位置
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos) -- 获得PPQ值
    local newstart =  reaper.MIDI_GetProjQNFromPPQPos(take, ppq) -- 获得QN值
    local Meas, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, newstart)
    local new_Start_QN = reaper.MIDI_GetPPQPosFromProjQN( take, Bar_Start_QN )
	local new_End_QN = reaper.MIDI_GetPPQPosFromProjQN( take, Bar_End_QN )
    reaper.MIDI_InsertCC(take, selected, false, new_Start_QN+110, 0xB0, 0, 64, 127) -- 踩下
    reaper.MIDI_InsertCC(take, selected, false, new_End_QN-10, 0xB0, 0, 64, 0) -- 释放
	reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40451)
    i=i+1
  end
end

reaper.Undo_BeginBlock()
selected = true
HoldPedalOn()
reaper.UpdateArrange()
reaper.Undo_EndBlock("Insert Sustain Pedal", -1)
reaper.SN_FocusMIDIEditor()
