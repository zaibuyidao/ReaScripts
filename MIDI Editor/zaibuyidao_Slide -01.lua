--[[
 * ReaScript Name: Slide -01
 * Instructions: Open a MIDI take in MIDI Editor. Select Events. Run.
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-16)
  + Initial release
--]]

local j = -1

local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

function Notes()
  for i = 0,  notes-1 do
    retval, sel, muted, ppq_start, ppq_end, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
    if sel == true then
      reaper.MIDI_SetNote(take, i, sel, muted, ppq_start+j, ppq_end+j, chan, pitch, vel, false)
    end
    i=i+1
  end
end

function CCs()
  for i = 0,  ccs-1 do
    retval, sel, muted, cc_ppq, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      reaper.MIDI_SetCC(take, i, sel, muted, cc_ppq+j, chanmsgIn, chanIn, msg2In, msg3In, false)
    end
    i=i+1
  end
end

function SYSEX()
  for i = 0,  sysex-1 do
    retval, sel, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, i)
    if sel == true then
	 reaper.MIDI_SetTextSysexEvt(take, i, sel, muted, ppqpos+j, type, msg, false) 
    end
    i=i+1
  end
end

script_title = "Slide -01"
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
Notes()
CCs()
SYSEX()
reaper.UpdateArrange()
reaper.MIDI_Sort(take)
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()