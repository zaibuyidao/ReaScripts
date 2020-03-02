--[[
 * ReaScript Name: Connect Events
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Event, Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-3)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
local ccnt, cidx = 0, {}
local cval = reaper.MIDI_EnumSelCC(take, -1)
while cval ~= -1 do
    ccnt = ccnt + 1
    cidx[ccnt] = cval
    cval = reaper.MIDI_EnumSelCC(take, cval)
end
local _, _, _, cc_start_pos, _, _, _, _ = reaper.MIDI_GetCC(take, cidx[1])
local _, _, _, cc_end_pos, _, _, _, _ = reaper.MIDI_GetCC(take, cidx[#cidx])
local cc_len = math.floor(cc_end_pos - cc_start_pos)
local retval, userInputsCSV = reaper.GetUserInputs("Connect Events", 1, "Tick", "10")
if not retval then return reaper.SN_FocusMIDIEditor() end
local tick = userInputsCSV:match("(.*)")
interval = cc_len / tick
function GetCC(take, cc)
    return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end
function main()
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
reaper.Undo_BeginBlock()
selected = true
if #cidx == 2 then
    main()
end
reaper.Undo_EndBlock("Connect Events", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
