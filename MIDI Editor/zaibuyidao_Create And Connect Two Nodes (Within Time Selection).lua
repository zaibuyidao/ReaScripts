--[[
 * ReaScript Name: Create And Connect Two Nodes (Within Time Selection)
 * Instructions: Open a MIDI take in MIDI Editor. Set Time Selection, Run.
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
  local cc_len = math.floor(loop_end - loop_start)
  if cc_len <= 0 then return reaper.MB("Please set the time selection range first.", "Error", 0), reaper.SN_FocusMIDIEditor()  end
  local userOk, userInputsCSV = reaper.GetUserInputs("Create And Connect Two Nodes", 4, "CC Number,First Value,Second Value,Tick", "11,100,1,20")
  if not userOk then return reaper.SN_FocusMIDIEditor() end
  local msg2, msg3, msg4, tick = userInputsCSV:match("(.*),(.*),(.*),(.*)")
  msg2, msg3, msg4, tick = tonumber(msg2), tonumber(msg3), tonumber(msg4), tonumber(tick)
  if not tonumber(msg2) or not tonumber(msg3) or not tonumber(msg4) or not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
  reaper.MIDI_InsertCC(take, selected, muted, loop_start, 0xB0, chan, msg2, msg3)
  reaper.MIDI_InsertCC(take, selected, muted, loop_end, 0xB0, chan, msg2, msg4)
  local interval = cc_len / tick
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
selected = true
chan = 0
muted = false
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create And Connect Two Nodes", 0)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()