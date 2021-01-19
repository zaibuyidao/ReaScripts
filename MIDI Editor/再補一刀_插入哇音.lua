--[[
 * ReaScript Name: 插入哇音
 * Version: 1.5
 * Author: 再補一刀
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

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())

local cc_num = reaper.GetExtState("InsertWah", "CCNum")
if (cc_num == "") then cc_num = "74" end
local cc_begin = reaper.GetExtState("InsertWah", "CCBegin")
if (cc_begin == "") then cc_begin = "32" end
local cc_end = reaper.GetExtState("InsertWah", "CCEnd")
if (cc_end == "") then cc_end = "64" end
local cishu = reaper.GetExtState("InsertWah", "Repetition")
if (cishu == "") then cishu = "8" end
local tick_01 = reaper.GetExtState("InsertWah", "Length")
if (tick_01 == "") then tick_01 = "480" end
local tick_02 = reaper.GetExtState("InsertWah", "Interval")
if (tick_02 == "") then tick_02 = "20" end

local retval, user_input_CSV = reaper.GetUserInputs("插入哇音", 6, "CC編號,1,2,重複,長度,間隔", cc_num ..','.. cc_begin ..','.. cc_end ..','.. cishu ..','.. tick_01 ..','.. tick_02)
if not retval then return reaper.SN_FocusMIDIEditor() end
cc_num, cc_begin, cc_end, cishu, tick_01, tick_02 = user_input_CSV:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(cc_num) or not tonumber(cc_begin) or not tonumber(cc_end) or not tonumber(cishu) or not tonumber(tick_01) or not tonumber(tick_02) then return reaper.SN_FocusMIDIEditor() end
cc_num, cc_begin, cc_end, cishu, tick_01, tick_02 = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(cishu), tonumber(tick_01), tonumber(tick_02)

reaper.SetExtState("InsertWah", "CCNum", cc_num, false)
reaper.SetExtState("InsertWah", "CCBegin", cc_begin, false)
reaper.SetExtState("InsertWah", "CCEnd", cc_end, false)
reaper.SetExtState("InsertWah", "Repetition", cishu, false)
reaper.SetExtState("InsertWah", "Length", tick_01, false)
reaper.SetExtState("InsertWah", "Interval", tick_02, false)

function Wah()
    local pos = reaper.GetCursorPositionEx()
    local ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
    local bolang = {cc_begin,cc_end}
    ppq = ppq - tick_01
    for i = 1, cishu do
        for i = 1, #bolang do
            ppq = ppq + tick_01
            reaper.MIDI_InsertCC(take, selected, false, ppq, 0xB0, 0, cc_num, bolang[i])
            i=i+1
        end
    end
end
function GetCC(take, cc)
    return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end
function Main()
    if take ~= nil then
        retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
        if ccs == 0 then return end
        midi_cc = {}
        for j = 0, ccs - 1 do
            cc = {}
            retval, cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3 = reaper.MIDI_GetCC(take, j)
            if not midi_cc[cc.msg2] then midi_cc[cc.msg2] = {} end
            table.insert(midi_cc[cc.msg2], cc)
        end
        cc_events = {}
        cc_events_len = 0
        for key, val in pairs(midi_cc) do
            for k = 1, #val - 1 do
                a_selected, a_muted, a_ppqpos, a_chanmsg, a_chan, a_msg2, a_msg3 = GetCC(take, val[k])
                b_selected, b_muted, b_ppqpos, b_chanmsg, b_chan, b_msg2, b_msg3 = GetCC(take, val[k + 1])
                if a_selected == true and b_selected == true then
                    time_interval = (b_ppqpos - a_ppqpos) / interval
                    for z = 1, interval - 1 do
                        cc_events_len = cc_events_len + 1
                        cc_events[cc_events_len] = {}
                        c_ppqpos = a_ppqpos + time_interval * z
                        c_msg3 = math.floor(((b_msg3 - a_msg3) / interval * z + a_msg3) + 0.5)
                        cc_events[cc_events_len].ppqpos = c_ppqpos
                        cc_events[cc_events_len].chanmsg = a_chanmsg
                        cc_events[cc_events_len].chan = a_chan
                        cc_events[cc_events_len].msg2 = a_msg2
                        cc_events[cc_events_len].msg3 = c_msg3
                    end
                end
            end
        end
        for i, cc in ipairs(cc_events) do
            reaper.MIDI_InsertCC(take, selected, false, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3)
        end
    end
end
selected = true
interval = tick_01 / tick_02
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
Wah()
Main()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("插入哇音", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
