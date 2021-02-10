--[[
 * ReaScript Name: 技法映射 - 音符轉PC
 * Version: 1.0
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-29)
  + Initial release
--]]

function Msg(param)
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  if cnt == 0 then return reaper.SN_FocusMIDIEditor() end

  local MSB, LSB = {}

  local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
  local string_pos, ticks, table_events, offset, flags, msg = 1, 0, {}
  local pack, unpack = string.pack, string.unpack
  while string_pos < #midi_string do
    offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
    if flags&1 ==1 and #msg >= 3 and msg:byte(1)>>4 == 8 and msg:byte(3) ~= -1 then
      MSB[#MSB+1] = msg:byte(3)
    end
  end

  reaper.MIDI_DisableSort(take)

  for i = 1, #index do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, index[i])
    if selected == true then
      -- if vel == 96 then
      --   LSB = 0
      --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1]) -- CC#00
      --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
      --   reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
      -- else
        LSB = vel
        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 0, MSB[1]) -- CC#00
        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xB0, chan, 32, LSB) -- CC#32
        reaper.MIDI_InsertCC(take, true, muted, startppqpos, 0xC0, chan, pitch, 0) -- Program Change
      -- end
      flag = true
    end
  end

  reaper.MIDI_Sort(take)

  i = reaper.MIDI_EnumSelNotes(take, -1)
  while i > -1 do
    reaper.MIDI_DeleteNote(take, i)
    i = reaper.MIDI_EnumSelNotes(take, -1)
  end
end

local script_title = "音符轉PC"
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
