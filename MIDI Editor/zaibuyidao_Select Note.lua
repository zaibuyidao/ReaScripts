--[[
 * ReaScript Name: Select Note
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
 * v1.0 (2020-1-5)
  + Initial release
--]]

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
userOK, dialog_ret_vals = reaper.GetUserInputs("Select Note", 12, "Tick,,Velocity,,Duration,,Beat,,Key,,Channel,", "0,1919,1,127,0,65536,1,99,0,127,1,16")
if not userOK then return reaper.SN_FocusMIDIEditor() end
min_tick, max_tick, min_vel, max_vel, min_dur, max_dur, min_meas, max_meas, min_key, max_key, min_chan, max_chan = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
min_tick, max_tick, min_vel, max_vel, min_dur, max_dur, min_meas, max_meas, min_key, max_key, min_chan, max_chan = tonumber(min_tick), tonumber(max_tick), tonumber(min_vel), tonumber(max_vel), tonumber(min_dur), tonumber(max_dur), tonumber(min_meas) -1, tonumber(max_meas), tonumber(min_key), tonumber(max_key), tonumber(min_chan) -1, tonumber(max_chan) -1 -- min_meas -1: Compensation

function MEAS() -- 小节
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppq_start)
    if sel == true then
	  local retval, Bar_Start_QN, Bar_End_QN = reaper.TimeMap_QNToMeasures(0, newstart)
      if newstart >= math.floor(Bar_Start_QN) + min_meas and newstart < math.floor(Bar_Start_QN) + max_meas then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

function VEL() -- 力度
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      if vel >= min_vel and vel <= max_vel then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

function TICK() -- Tick
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    newstart = reaper.MIDI_GetProjQNFromPPQPos(take, ppq_start)
    if sel == true then
      if newstart >= math.floor(newstart) + min_tick/480 and newstart <= math.floor(newstart) + max_tick/480 then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
	end
  end
  reaper.UpdateArrange()
end

function DUR() -- 长度
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    x = ppq_end - ppq_start
    if sel == true then
      if x >= min_dur and x <= max_dur then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

function KEY() -- 音高
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      if pitch >= min_key and pitch <= max_key then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

function CHAN() -- 通道
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      if chan >= min_chan and chan <= max_chan then
        reaper.MIDI_SetNote(take, i, true, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      else
        reaper.MIDI_SetNote(take, i, false, muted, ppq_start, ppq_end, chan, pitch, vel, true)
      end
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Select Note"
reaper.Undo_BeginBlock()
TICK()
VEL()
DUR()
MEAS()
KEY()
CHAN()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()