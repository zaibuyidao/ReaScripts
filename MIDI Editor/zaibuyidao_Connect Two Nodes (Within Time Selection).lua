--[[
 * ReaScript Name: Connect Two Nodes (Within Time Selection)
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-3-5)
  + Initial release
--]]

function GetCC(take, cc)
  return cc.selected, cc.muted, cc.ppqpos, cc.chanmsg, cc.chan, cc.msg2, cc.msg3
end

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local time_start, time_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, 0)
  local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
  local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
  local ccs_cnt, ccs_idx = 0, {}
  local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
  while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
  end

  local cc_len = math.floor(loop_end - loop_start)

  local msg2 = reaper.GetExtState("ConnectTwoNodes", "Msg2")
  if (msg2 == "") then msg2 = "11" end
  local msg3 = reaper.GetExtState("ConnectTwoNodes", "Msg3")
  if (msg3 == "") then msg3 = "100" end
  local msg4 = reaper.GetExtState("ConnectTwoNodes", "Msg4")
  if (msg4 == "") then msg4 = "1" end
  local tick = reaper.GetExtState("ConnectTwoNodes", "Tick")
  if (tick == "") then tick = "20" end

  if cc_len == 0 or ccs_cnt > 0 then return reaper.MB("Time selection range is not set or CC Event already exists.", "Error", 0), reaper.SN_FocusMIDIEditor() end
  local user_ok, user_input_csv = reaper.GetUserInputs("Connect Two Nodes", 4, "CC Number,First Value,Second Value,Interval", msg2 ..','.. msg3 ..','.. msg4 ..','.. tick)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  msg2, msg3, msg4, tick = user_input_csv:match("(.*),(.*),(.*),(.*)")
  if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) or not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
  msg2, msg3, msg4, tick = tonumber(msg2), tonumber(msg3), tonumber(msg4), tonumber(tick)

  reaper.SetExtState("ConnectTwoNodes", "Msg2", msg2, false)
  reaper.SetExtState("ConnectTwoNodes", "Msg3", msg3, false)
  reaper.SetExtState("ConnectTwoNodes", "Msg4", msg4, false)
  reaper.SetExtState("ConnectTwoNodes", "Tick", tick, false)

  reaper.MIDI_InsertCC(take, selected, muted, loop_start, 0xB0, chan, msg2, msg3)
  reaper.MIDI_InsertCC(take, selected, muted, loop_end, 0xB0, chan, msg2, msg4)
  local interval = cc_len / tick
  _, _, ccs, _ = reaper.MIDI_CountEvts(take)

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

selected = true
chan = 0
muted = false
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Connect Two Nodes (Within Time Selection)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()