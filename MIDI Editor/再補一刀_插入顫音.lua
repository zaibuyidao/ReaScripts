--[[
 * ReaScript Name: 插入顫音
 * Version: 1.0
 * Author: 再補一刀
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

local cc_num = reaper.GetExtState("InsertCCEvents2", "CC_Num")
local cc_begin = reaper.GetExtState("InsertCCEvents2", "CC_Begin")
local cc_end = reaper.GetExtState("InsertCCEvents2", "CC_End")
local cishu = reaper.GetExtState("InsertCCEvents2", "Cishu")
local tick = reaper.GetExtState("InsertCCEvents2", "Tick")

if (cc_num == "") then cc_num = "11" end
if (cc_begin == "") then cc_begin = "100" end
if (cc_end == "") then cc_end = "70" end
if (cishu == "") then cishu = "1" end
if (tick == "") then tick = "120" end

local user_ok, user_input_csv = reaper.GetUserInputs("插入顫音", 5, "CC編號,1,2,重複,間隔", cc_num..','..cc_begin..','.. cc_end..','..cishu..','.. tick)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
cc_num, cc_begin, cc_end, cishu, tick = user_input_csv:match("(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(cc_begin) or not tonumber(cc_end) or not tonumber(cishu) or not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("InsertCCEvents2", "CC_Num", cc_num, false)
reaper.SetExtState("InsertCCEvents2", "CC_Begin", cc_begin, false)
reaper.SetExtState("InsertCCEvents2", "CC_End", cc_end, false)
reaper.SetExtState("InsertCCEvents2", "Cishu", cishu, false)
reaper.SetExtState("InsertCCEvents2", "Tick", tick, false)

cc_num, cc_begin, cc_end, cishu, tick = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu)*8, tonumber(tick)

function Main()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local cuspos = reaper.GetCursorPositionEx(0)
    local ppqpos = reaper.MIDI_GetPPQPosFromProjTime(take, cuspos)
    local bolang = {cc_begin,cc_end}
    ppqpos = ppqpos - tick
    for i = 1, cishu do
        for i = 1, #bolang do
            ppqpos = ppqpos + tick
            reaper.MIDI_InsertCC(take, selected, false, ppqpos, 0xB0, chan, cc_num, bolang[i])
            i=i+1
        end
    end
end

reaper.Undo_BeginBlock()
selected = true
chan = 0
Main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("插入顫音", -1)
reaper.SN_FocusMIDIEditor()