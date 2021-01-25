--[[
 * ReaScript Name: 自動表情(多軌)
 * Version: 1.3.1
 * Author: 再補一刀, 當歸蛋
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
  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i ~= -1 do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      ppq_len = endppqpos[i] - startppqpos[i]
      if ppq_len > 0 and ppq_len < tick/2 then -- 大于 0 并且 小于 240
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i], 0xB0, chan, cc_number, max_val)
      end
      if ppq_len >= tick/2 and ppq_len < tick then -- 大于等于 240 并且 小于 480
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/4+tick/8+tick/48)/diff) -- 以 八分音符稍短 作为长度-190
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len >= tick and ppq_len < tick*2 then -- 大于等于 480 并且 小于960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*0.75)/diff) -- 以 八分音符附点 作为长度-360
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len == tick*2 then -- 等于 960
        for k, v in pairs(tbl) do
          local interval = math.floor(tick/diff) -- 以 四分音符 拍作为长度-480
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len > tick*2 then -- 大于 960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick*1.5)/diff) -- 以 四分音符附点 拍作为长度-720
          reaper.MIDI_InsertCC(take, selected, muted, startppqpos[i]+(k-1)*interval, 0xB0, chan, cc_number, v)
        end
      end
      if ppq_len >= tick*2 then -- 大于等于 960
        for k, v in pairs(tbl) do
          local interval = math.floor((tick/2+tick/12)/(diff-12)) -- 以 八分音符稍短 作为长度-280 并 将差值减去12
          if k >= 13 then -- 排序从第12个数开始，插入CC
            reaper.MIDI_InsertCC(take, selected, muted, endppqpos[i]-(tick/24)-(k-13)*interval, 0xB0, chan, cc_number, v) -- 尾巴减少 20 Tick
          end
        end
      end
    end
    i = reaper.MIDI_EnumSelNotes(take, i)
  end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

min_val = reaper.GetExtState("AutoExpression", "Begin")
max_val = reaper.GetExtState("AutoExpression", "End")

if (min_val == "") then min_val = "90" end
if (max_val == "") then max_val = "127" end

local user_ok, user_input_CSV = reaper.GetUserInputs("自動表情(多軌)", 2, "最小值,最大值", min_val ..','.. max_val)
min_val, max_val = user_input_CSV:match("(.*),(.*)")

if not user_ok or not tonumber(min_val) or not tonumber(max_val) then return reaper.SN_FocusMIDIEditor() end
min_val, max_val = tonumber(min_val), tonumber(max_val)

if min_val > 127 or min_val < 0 or max_val > 127 or max_val < 0  then return reaper.SN_FocusMIDIEditor() end
if min_val >= max_val then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("AutoExpression", "Begin", min_val, false)
reaper.SetExtState("AutoExpression", "End", max_val, false)

tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
diff = max_val - min_val
startppqpos = {}
endppqpos = {}

tbl = {}
for j = min_val, max_val do
  if j > 127 then j = 127 end
  if j > max_val then j = max_val end
  table.insert(tbl, j)
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

-- reaper.MIDIEditor_LastFocused_OnCommand(reaper.NamedCommandLookup("_RS7d3c_38c941e712837e405c3c662e2a39e3d03ffd5364"), 0) -- 移除冗余CCs
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("自動表情(多軌)", 0)
reaper.SN_FocusMIDIEditor()