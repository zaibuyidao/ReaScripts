--[[
 * ReaScript Name: Articulation Map - Program Change To Note
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
  
  reaper.MIDI_DisableSort(take)

  for i = 1, #index do
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
    if chanmsg == 176 and msg2 == 0 then -- CC#0
      bank_msb_num = msg3
      bank_msb[#bank_msb+1] = bank_msb_num
    end
    if chanmsg == 176 and msg2 == 32 then -- CC#32
      vel = msg3
      if vel == 0 then vel = 96 end
    end
    if chanmsg == 192 then --Program Change
      pitch = msg2
      reaper.MIDI_InsertNote(take, true, muted, ppqpos, ppqpos+120, chan, pitch, vel, false)
    end
  end

  reaper.MIDI_Sort(take)

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
end

local script_title = "Program Change To Note"
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
