--[[
 * ReaScript Name: Auto Expression Arc (Multitrack)
 * Version: 1.0
 * Author: zaibuyidao, dangguidan
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-27)
  + Initial release
--]]

-- USER AREA
-- Settings that the user can customize.

cc_number = 11

-- End of USER AREA

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function autoExp()
  tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    note_ok, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    diff = max_val - min_val
    if note_ok and selected then
      for k = 0, diff do
        local linear = min_val + k
        local fast_end = min_val + k - 1
        diff_01 = (tick+tick/4) / diff -- 将 1.25 拍的音符长度除于差值
        diff_02 = k*k / diff -- 减弱CC差值
        note_len = endppqpos - startppqpos
        if note_len >= tick/2 and note_len < tick then -- 如果音符大于等于 240 并且 小于 480
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.3, 0xB0, chan, cc_number, linear)
        end
        if note_len >= tick and note_len < tick*2 then -- 如果音符大于等于 480 并且 小于 960
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.55, 0xB0, chan, cc_number, linear)
        end
        if note_len == tick*2 then -- 如果音符等于 960
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01*0.8, 0xB0, chan, cc_number, linear)
          reaper.MIDI_InsertCC(take, selected, muted, endppqpos-tick/24-diff_01*diff_02*0.3, 0xB0, chan, cc_number, fast_end)
        end
        if note_len > tick*2 then -- 如果音符大于 960
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos+k*diff_01, 0xB0, chan, cc_number, linear)
          reaper.MIDI_InsertCC(take, selected, muted, endppqpos-tick/24-diff_01*diff_02*0.4, 0xB0, chan, cc_number, fast_end)
        end
        if note_len > 0 and note_len < tick/2 then -- 如果音符大于 0 并且 小于 240
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, chan, cc_number, max_val)
        end
      end
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

function main()
  min_val = reaper.GetExtState("AutoExpressionArc", "Begin")
  if (min_val == "") then min_val = "90" end
  max_val = reaper.GetExtState("AutoExpressionArc", "End")
  if (max_val == "") then max_val = "127" end
  local user_ok, user_input_csv = reaper.GetUserInputs("Auto expression Arc (multitrack)", 2, "Min value,Max value", min_val ..','.. max_val)
  min_val, max_val = user_input_csv:match("(.*),(.*)")
  if not user_ok or not tonumber(min_val) or not tonumber(max_val) then return reaper.SN_FocusMIDIEditor() end
  min_val, max_val = tonumber(min_val), tonumber(max_val)
  if min_val < 0 or min_val > 127 or max_val < 0 or max_val > 127 or min_val >= max_val then return reaper.SN_FocusMIDIEditor() end
  reaper.SetExtState("AutoExpressionArc", "Begin", min_val, false)
  reaper.SetExtState("AutoExpressionArc", "End", max_val, false)

  count_sel_items = reaper.CountSelectedMediaItems(0)

  if count_sel_items > 0 then
    for i = 1, count_sel_items do
      item = reaper.GetSelectedMediaItem(0, i - 1)
      take = reaper.GetTake(item, 0)
      if not take or not reaper.TakeIsMIDI(take) then return end
      reaper.MIDI_DisableSort(take)
      autoExp()
      reaper.MIDI_Sort(take)
    end
  else
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    reaper.MIDI_DisableSort(take)
    autoExp()
    reaper.MIDI_Sort(take)
  end
end

reaper.Undo_BeginBlock() -- 撤销块开始
reaper.PreventUIRefresh(1) -- 防止UI刷新
main() -- 执行函数
-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.Undo_EndBlock("Auto Expression Arc (Multitrack)", 0) -- 撤销块结束
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器