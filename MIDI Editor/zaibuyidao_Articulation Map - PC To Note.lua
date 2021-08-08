--[[
 * ReaScript Name: Articulation Map - PC To Note
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-8-4)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  if cnt == 0 then return reaper.SN_FocusMIDIEditor() end

  local bank_msb = {}
    
  reaper.PreventUIRefresh(1)
  reaper.MIDI_DisableSort(take)
  
  local notes_store = {}  -- 保存即将被插入的音符
  local cc119s = {}   -- 保存选中的cc119值

  for i = 1, #index do
      retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
      if chanmsg == 176 and msg2 == 0 then
          bank_msb_num = msg3
          bank_msb[#bank_msb+1] = bank_msb_num
      elseif chanmsg == 176 and msg2 == 32 then
          vel = msg3
          if vel == 0 then vel = 96 end
      elseif chanmsg == 176 and msg2 == 119 then
          table.insert(cc119s, { ppqpos, msg3 })
      elseif chanmsg == 192 then
          pitch = msg2
          table.insert(notes_store, {
              take, true, muted, ppqpos, ppqpos+120, chan, pitch, vel, false
          })
      end
  end

  -- 对cc119进行排序
  table.sort(cc119s, function (a,b)
      return a[1] < b[1]
  end)

  -- 遍历被保存的即将被插入的音符，根据cc119s列表来动态改变音符的结束位置
  for i,note in ipairs(notes_store) do
      -- 遍历cc119列表，查找符合条件的cc119值
      for j, c in ipairs(cc119s) do
          -- 如果当前被遍历的cc119不是最后一个，当前cc119位置等于音符起始位置 且 当前状态为开 且下一个状态为 关
          if j ~= #cc119s and (c[1] <= note[4] and c[1] >= note[4]-240) and c[2] >= 64 and c[2] <=127 and cc119s[j+1][2]>=0 and cc119s[j+1][2]<=63 then
              -- 则当前音符的结束位置为下一个cc119的位置
              note[5] = cc119s[j+1][1]
              break
          end
      end
      reaper.MIDI_InsertNote(table.unpack(note))
  end

  if bank_msb[1] == nil or vel == nil or pitch == nil then return reaper.SN_FocusMIDIEditor() end

  i = reaper.MIDI_EnumSelCC(take, -1)
  while i > -1 do
      reaper.MIDI_DeleteCC(take, i)
      i = reaper.MIDI_EnumSelCC(take, -1)
  end
  
  local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
  if not midi_ok then reaper.ShowMessageBox("Error loading MIDI", "Error", 0) return end
  local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
  local pack, unpack = string.pack, string.unpack
  while string_pos < #midi_string do
      offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
      if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
          msg = msg:sub(1,2) .. string.char(msg:byte(3) + bank_msb[1])
      end
      table_events[#table_events+1] = pack("i4Bs4", offset, flags, msg)
  end
  reaper.MIDI_SetAllEvts(take, table.concat(table_events))

  reaper.MIDI_Sort(take)
  reaper.PreventUIRefresh(-1)
end

reaper.Undo_BeginBlock()
main()
reaper.UpdateArrange()
reaper.Undo_EndBlock("PC To Note", -1)
reaper.SN_FocusMIDIEditor()
