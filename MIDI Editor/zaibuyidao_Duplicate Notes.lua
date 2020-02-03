--[[
 * ReaScript Name: Duplicate Notes
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
 * v1.0 (2020-2-3)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
title = "Duplicate Notes"
reaper.Undo_BeginBlock()
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
end

if cnt == 0 then return reaper.MB("Please select one or more notes","Error",0), reaper.SN_FocusMIDIEditor() end

function table_max(t)
  local mn=nil
  for k, v in pairs(t) do
    if(mn==nil) then
      mn=v
    end
    if mn < v then
      mn = v
    end
  end
  return mn
end

function table_min(t)
  local mn=nil
  for k, v in pairs(t) do
    if(mn==nil) then
      mn=v
    end
    if mn > v then
      mn = v
    end
  end
  return mn
end

local start_ppq = {}
local end_ppq = {}

for i = 1, #index do
  _, sel, _, start_ppq[i], end_ppq[i], _, _, _ = reaper.MIDI_GetNote(take, index[i])
  if sel == true then
  end
end

local len = table_max(end_ppq) - table_min(start_ppq)
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
reaper.MIDI_DisableSort(take)

for i = 0,  notes-1 do
  local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  local start_meas = table_min(start_ppq)
  local start_tick = startppqpos - start_meas
  local tick = start_tick % table_max(end_ppq)
  if selected == true then
    if len >= 10 and len <= 60 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+60, endppqpos+60, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 60 and len <= 120 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+120, endppqpos+120, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 120 and len <= 240 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+240, endppqpos+240, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 240 and len <= 480 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+480, endppqpos+480, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 480 and len <= 960 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+960, endppqpos+960, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 960 and len <= 1920 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+1920, endppqpos+1920, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 1920 and len <= 3840 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+3840, endppqpos+3840, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 3840 and len <= 7680 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+7680, endppqpos+7680, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
    if len > 7680 and len <= 15360 then
      reaper.MIDI_InsertNote(take, true, muted, startppqpos+15360, endppqpos+15360, chan, pitch, vel, false)
      if not (tick > table_max(end_ppq)) then
        reaper.MIDI_SetNote(take, i, false, nil, nil, nil, nil, nil, nil, false)
      end
    end
  end
  i=i+1
end

reaper.UpdateArrange()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(title, -1)
reaper.defer(function() end) 