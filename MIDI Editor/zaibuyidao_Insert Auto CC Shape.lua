--[[
 * ReaScript Name: Insert Auto CC Shape
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showthread.php?t=225108
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.1 (2020-2-15)
  # Add midi ticks per beat
 * v1.0 (2020-1-1)
  + Initial release
--]]

selected = false
muted = false
chan = 0 -- Channel 1

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local item = reaper.GetMediaItemTake_Item(take)
local _, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
local retval, userInputsCSV = reaper.GetUserInputs("Insert Auto CC Shape", 4, "CC Number,1,2,3", "11,90,127,95")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cc_num, val_01, val_02, val_03 = userInputsCSV:match("(.*),(.*),(.*),(.*)")
cc_num, val_01, val_02, val_03 = tonumber(cc_num), tonumber(val_01), tonumber(val_02), tonumber(val_03)

function INST1()
  for i = 0,  notes-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > (tick / 4) and len <= ((tick / 4) + (tick / 2))  then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val_01)
      elseif len > ((tick / 4) + (tick / 2)) and len <= tick then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val_01)
      elseif len > tick and len <= tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val_01)
      elseif len > tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val_01)
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42083)
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0)
end

function INST2()
  for i = 0,  notes-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > (tick / 4) and len <= ((tick / 4) + (tick / 2)) then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick / 16) * 3, 0xB0, 0, cc_num, val_02) -- 90
      elseif len > ((tick / 4) + (tick / 2)) and len <= tick then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick / 2), 0xB0, 0, cc_num, val_02) -- 240
      elseif len > tick and len <= tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + tick, 0xB0, 0, cc_num, val_02) -- 480
      elseif len > tick * 2 and len <= tick * 6 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + tick, 0xB0, 0, cc_num, val_02) -- 480
      elseif len > tick * 6 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos + (tick + (tick / 2)), 0xB0, 0, cc_num, val_02) -- 720
      elseif len <= (tick / 4) then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val_02)
      end
        reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081)
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0)
end

function INST3()
  for i = 0,  notes-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > tick and len <= tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick / 2, 0xB0, 0, cc_num, val_02) -- 240
      elseif len > tick * 2 and len <= tick * 6 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick, 0xB0, 0, cc_num, val_02) -- 480
      elseif len >  tick * 6 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - tick * 2, 0xB0, 0, cc_num, val_02) -- 960
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42084)
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0)
end

function INST4()
  for i = 0,  notes-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > tick and len <= tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - ((tick / 16) / 3), 0xB0, 0, cc_num, val_03) -- 10
      elseif len > tick * 2 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos - ((tick / 16) / 3), 0xB0, 0, cc_num, val_03) -- 10
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081)
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0)
end

script_title = "Insert Auto CC Shape"
reaper.Undo_BeginBlock()
INST1()
INST2()
INST3()
INST4()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()