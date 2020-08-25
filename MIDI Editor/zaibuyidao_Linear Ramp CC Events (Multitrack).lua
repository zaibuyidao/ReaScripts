--[[
 * ReaScript Name: Linear Ramp CC Events (Multitrack)
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
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
 * v1.0 (2020-8-26)
  + Initial release
--]]

function LRCE()
  tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
  cnt, index = 0, {}
  val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  
  if #index > 0 then
    if cc_begin >= cc_end then return reaper.SN_FocusMIDIEditor() end
    local ppq = {} -- 音符开头位置
    local ppq_end = {} -- 音符尾巴位置
    local tbl = {} -- 存储CC值
  
    for j = cc_begin - 1, cc_end, step do
      j = j + 1
      if j > 127 then j = 127 end
      if j > cc_end then j = cc_end end
      table.insert(tbl, j) -- 将计算得到的CC值存入tbl表
    end
  
    for i = 1, #index do
      retval, selected, muted, ppq[i], ppq_end[i], chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
      if selected == true then
        ppq_len = ppq_end[i] - ppq[i]
        if ppq_len >= tick / 2 and ppq_len < tick then
          for k,v in pairs(tbl) do
            reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*5, 0xB0, chan, cc_num, v)
          end
        end
        if ppq_len >= tick and ppq_len < tick * 2 then
            for k,v in pairs(tbl) do
              reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*8, 0xB0, chan, cc_num, v)
            end
        end
        if ppq_len >= tick * 2 then
          for k,v in pairs(tbl) do
            reaper.MIDI_InsertCC(take, selected, muted, ppq[i]+(k-1)*10, 0xB0, chan, cc_num, v)
          end
        end
      end
    end
  end
end

function main()
  cc_num = reaper.GetExtState("LinearRampCCEvents", "Number")
  cc_begin = reaper.GetExtState("LinearRampCCEvents", "Begin")
  cc_end = reaper.GetExtState("LinearRampCCEvents", "End")
  step = reaper.GetExtState("LinearRampCCEvents", "Step")
  if (cc_num == "") then cc_num = "11" end
  if (cc_begin == "") then cc_begin = "90" end
  if (cc_end == "") then cc_end = "127" end
  if (step == "") then step = "1" end
  local user_ok, user_input_csv = reaper.GetUserInputs("Linear Ramp CC Events", 4, "CC Number,Min Volume,Max Volume,Step", cc_num..','..cc_begin..','.. cc_end..','..step)
  cc_num, cc_begin, cc_end, step = user_input_csv:match("(.*),(.*),(.*),(.*)")
  if not user_ok or not tonumber(cc_num) or not tonumber(cc_begin) or not tonumber(cc_end) or not tonumber(step) then return reaper.SN_FocusMIDIEditor() end
  cc_num, cc_begin, cc_end, step = tonumber(cc_num), tonumber(cc_begin), tonumber(cc_end), tonumber(step)
  reaper.SetExtState("LinearRampCCEvents", "Number", cc_num, false)
  reaper.SetExtState("LinearRampCCEvents", "Begin", cc_begin, false)
  reaper.SetExtState("LinearRampCCEvents", "End", cc_end, false)
  reaper.SetExtState("LinearRampCCEvents", "Step", step, false)

  count_sel_items = reaper.CountSelectedMediaItems(0)

  if count_sel_items > 0 then
    for i = 1, count_sel_items do
      item = reaper.GetSelectedMediaItem(0, i - 1)
      take = reaper.GetTake(item, 0)
      if not take or not reaper.TakeIsMIDI(take) then return end
      reaper.MIDI_DisableSort(take)
      LRCE()
      reaper.MIDI_Sort(take)
    end
  else
      take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
      if not take or not reaper.TakeIsMIDI(take) then return end
      reaper.MIDI_DisableSort(take)
      LRCE()
      reaper.MIDI_Sort(take)
    end
end

script_title = "Linear Ramp CC Events (Multitrack)"
reaper.PreventUIRefresh(1) -- 防止UI刷新
reaper.Undo_BeginBlock() -- 撤销块开始
main() -- 执行函数
-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.Undo_EndBlock(script_title, 0) -- 撤销块结束
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI编辑器