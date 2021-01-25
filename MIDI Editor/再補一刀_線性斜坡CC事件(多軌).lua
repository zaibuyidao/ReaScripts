--[[
 * ReaScript Name: 線性斜坡CC事件(多軌)
 * Version: 1.7
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

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function autoExp()
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      ppq_len = endppqpos[i] - startppqpos[i]
      if ppq_len > 0 and ppq_len < tick/2 then -- 大於 0 並且 小於 240
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_num, cc_end)
      end
      if ppq_len >= tick/2 and ppq_len < tick then -- 大於等於 240 並且 小於 480
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/4+tick/8+tick/48)/diff) -- 以 八分音符(稍短) 作為長度-190
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len >= tick and ppq_len < tick*2 then -- 大於等於 480 並且 小於960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*0.75)/diff) -- 以 八分音符附點 作為長度-360
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len == tick*2 then -- 等於 960
        for k, v in pairs(tbl) do
          local interval = math.floor(tick/diff) -- 以 四分音符 拍作為長度-480
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
      if ppq_len > tick*2 then -- 大於 960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*1.5)/diff) -- 以 四分音符附點 拍作為長度-720
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_num, v)
        end
      end
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

reaper.Undo_BeginBlock() -- 撤銷塊開始
reaper.PreventUIRefresh(1) -- 防止UI刷新

cc_begin = reaper.GetExtState("LinearRampCCEvents", "Begin")
if (cc_begin == "") then cc_begin = "90" end
cc_end = reaper.GetExtState("LinearRampCCEvents", "End")
if (cc_end == "") then cc_end = "127" end
cc_num = reaper.GetExtState("LinearRampCCEvents", "Number")
if (cc_num == "") then cc_num = "11" end
step = reaper.GetExtState("LinearRampCCEvents", "Step")
if (step == "") then step = "1" end

local user_ok, user_input_csv = reaper.GetUserInputs("線性斜坡CC事件(多軌)", 4, "最小值,最大值,CC編號,步長", cc_begin ..','.. cc_end ..',' .. cc_num ..','.. step)
cc_begin, cc_end, cc_num, step = user_input_csv:match("(.*),(.*),(.*),(.*)")
if not user_ok or not tonumber(cc_begin) or not tonumber(cc_end) or not tonumber(cc_num) or not tonumber(step) then return reaper.SN_FocusMIDIEditor() end
cc_begin, cc_end, cc_num, step = tonumber(cc_begin), tonumber(cc_end), tonumber(cc_num), tonumber(step)
if cc_begin > 127 or cc_begin < 0 or cc_end > 127 or cc_end < 0  then return reaper.SN_FocusMIDIEditor() end
if cc_begin >= cc_end then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("LinearRampCCEvents", "Number", cc_num, false)
reaper.SetExtState("LinearRampCCEvents", "Begin", cc_begin, false)
reaper.SetExtState("LinearRampCCEvents", "End", cc_end, false)
reaper.SetExtState("LinearRampCCEvents", "Step", step, false)

tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
diff = cc_end - cc_begin
startppqpos = {} -- 音符開頭位置
endppqpos = {} -- 音符結束位置

tbl = {} -- 存儲CC值
for j = cc_begin, cc_end, step do
  if j > 127 then j = 127 end
  if j > cc_end then j = cc_end end
  table.insert(tbl, j) -- 將計算得到的CC值存入tbl表
end

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

-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗餘CCs
reaper.PreventUIRefresh(-1) -- 恢复UI刷新
reaper.UpdateArrange() -- 更新排列
reaper.Undo_EndBlock("線性斜坡CC事件(多軌)", 0) -- 撤銷塊結束
reaper.SN_FocusMIDIEditor() -- 聚焦MIDI編輯器