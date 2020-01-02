--[[
 * ReaScript Name: Insert ADR
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 1.0
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
 * v1.0 (2020-1-1)
  + Initial release
--]]

selected = false
muted = false
chan = 0 -- Channel 1

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end
item = reaper.GetMediaItemTake_Item(take)
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
local retval, userInputsCSV = reaper.GetUserInputs("Insert ADR", 4, "CC Number,1,2,3", "11,90,127,95")
if not retval then return reaper.SN_FocusMIDIEditor() end
local cc_num, val1, val2, val3 = userInputsCSV:match("(.*),(.*),(.*),(.*)")
cc_num, val1, val2, val3 = tonumber(cc_num), tonumber(val1), tonumber(val2), tonumber(val3)

function INST1()
  for i = 0,  notes-1 do
    retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if selected == true then
      local len = endppqpos - startppqpos
      if len > 120 and len <= 360  then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val1)
      elseif len > 360 and len <= 480 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val1)
      elseif len > 480 and len <= 960 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val1)
      elseif len > 960 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val1)
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
      if len > 120 and len <= 360 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+90, 0xB0, 0, cc_num, val2)
      elseif len > 360 and len <= 480 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+240, 0xB0, 0, cc_num, val2)
      elseif len > 480 and len <= 960 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+240, 0xB0, 0, cc_num, val2)
      elseif len > 960 and len <= 2880 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+480, 0xB0, 0, cc_num, val2)
      elseif len > 2880 then
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos+720, 0xB0, 0, cc_num, val2)
      elseif len <= 120 then -- 长度小于等于120的音符追加默认值设定
        reaper.MIDI_InsertCC(take, selected, muted, startppqpos, 0xB0, 0, cc_num, val2)
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
      if len > 480 and len <= 960 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos-240, 0xB0, 0, cc_num, val2)
      elseif len > 960 and len <= 2880 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos-480, 0xB0, 0, cc_num, val2)
      elseif len >  2880 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos-960, 0xB0, 0, cc_num, val2)
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
      if len > 480 and len <= 960 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos-10, 0xB0, 0, cc_num, val3)
      elseif len > 960 then
        reaper.MIDI_InsertCC(take, selected, muted, endppqpos-10, 0xB0, 0, cc_num, val3)
      end
      reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 42081)
    end
    i=i+1
  end
  reaper.MIDIEditor_LastFocused_OnCommand(40671, 0)
end

script_title = "Insert ADR"
reaper.Undo_BeginBlock()
INST1()
INST2()
INST3()
INST4()
reaper.UpdateArrange()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()