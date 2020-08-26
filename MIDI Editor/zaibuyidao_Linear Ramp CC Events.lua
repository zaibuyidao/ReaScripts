--[[
 * ReaScript Name: Linear Ramp CC Events
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.6
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

function main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  if take == nil then return end

  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  
  if #index > 0 then
    cc_num = reaper.GetExtState("LinearRampCCEvents", "Number")
    min_val = reaper.GetExtState("LinearRampCCEvents", "Begin")
    max_val = reaper.GetExtState("LinearRampCCEvents", "End")
    if (cc_num == "") then cc_num = "11" end
    if (min_val == "") then min_val = "90" end
    if (max_val == "") then max_val = "127" end
    local user_ok, user_input_csv = reaper.GetUserInputs("Linear Ramp CC Events", 3, "CC number,Min value,Max value", cc_num..','..min_val..','.. max_val)
    cc_num, min_val, max_val = user_input_csv:match("(.*),(.*),(.*)")
    if not user_ok or not tonumber(cc_num) or not tonumber(min_val) or not tonumber(max_val)then return reaper.SN_FocusMIDIEditor() end
    cc_num, min_val, max_val = tonumber(cc_num), tonumber(min_val), tonumber(max_val)
    if min_val < 1 or max_val > 127 or min_val >= max_val then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("LinearRampCCEvents", "Number", cc_num, false)
    reaper.SetExtState("LinearRampCCEvents", "Begin", min_val, false)
    reaper.SetExtState("LinearRampCCEvents", "End", max_val, false)

    reaper.MIDI_DisableSort(take)
    i = reaper.MIDI_EnumSelNotes(take, -1)
    while i ~= -1 do
      note_ok, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
      diff = max_val - min_val
        if note_ok and selected then
          for k = 0, diff do
            local linear = min_val + k
            diff_01 = (tick+tick/4) / diff -- 将 1.25 拍的音符长度除于差值
            note_len = endppqpos - startppqpos
            if note_len >= tick/2 and note_len < tick then -- 如果音符大于等于 240 并且 小于 480
              reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.3, 0xB0, chan, cc_num, linear)
            end
            if note_len >= tick and note_len < tick*2 then -- 如果音符大于等于 480 并且 小于 960
              reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.55, 0xB0, chan, cc_num, linear)
            end
            if note_len == tick*2 then -- 如果音符等于 960
              reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.8, 0xB0, chan, cc_num, linear)
            end
            if note_len > tick*2 then -- 如果音符大于 960
              reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01, 0xB0, chan, cc_num, linear)
            end
          end
        end
        i = reaper.MIDI_EnumSelNotes(take, i)
    end
    reaper.MIDI_Sort(take)
  end
end

script_title = "Linear Ramp CC Events"
reaper.PreventUIRefresh(1) -- 防止UI刷新
reaper.Undo_BeginBlock() -- 撤销块开始
main() -- 执行函数
-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.Undo_EndBlock(script_title, 0) -- 撤销块结束
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器