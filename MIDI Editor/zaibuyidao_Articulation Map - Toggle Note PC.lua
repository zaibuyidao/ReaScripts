--[[
 * ReaScript Name: Articulation Map - Toggle Note PC
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-26)
  + Initial release
--]]

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end

local note_cnt, note_idx = 0, {}
local note_val = reaper.MIDI_EnumSelNotes(take, -1)
while note_val ~= -1 do
    note_cnt = note_cnt + 1
    note_idx[note_cnt] = note_val
    note_val = reaper.MIDI_EnumSelNotes(take, note_val)
end

local ccs_cnt, ccs_idx = 0, {}
local ccs_val = reaper.MIDI_EnumSelCC(take, -1)
while ccs_val ~= -1 do
    ccs_cnt = ccs_cnt + 1
    ccs_idx[ccs_cnt] = ccs_val
    ccs_val = reaper.MIDI_EnumSelCC(take, ccs_val)
end

function NoteToPC()
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

    reaper.PreventUIRefresh(1)
    reaper.MIDI_DisableSort(take)
  
    for i = 1, #note_idx do
        retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, note_idx[i])
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
  
    i = reaper.MIDI_EnumSelNotes(take, -1)
    while i > -1 do
        reaper.MIDI_DeleteNote(take, i)
        i = reaper.MIDI_EnumSelNotes(take, -1)
    end

    reaper.MIDI_Sort(take)
    reaper.PreventUIRefresh(-1)
end

function PCToNote()
    local bank_msb = {}

    reaper.PreventUIRefresh(1)
    reaper.MIDI_DisableSort(take)

    for i = 1, #ccs_idx do
        retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, ccs_idx[i])
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
if #note_idx > 0 and #ccs_idx == 0 then
    NoteToPC()
elseif #ccs_idx > 0 and #note_idx ==0 then
    PCToNote()
end
reaper.Undo_EndBlock("Toggle Note PC", -1)
reaper.UpdateArrange()
