--[[
 * ReaScript Name: Program Change To Note (For JSFX-Simple Expression Map)
 * Instructions: Part of [JSFX: Simple Expression Map]. Open a MIDI take in MIDI Editor. Select Program Change Event. Run.
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

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)

  for i = 1, ccevtcnt do
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i - 1)
    if selected == true then
      if chanmsg == 176 and msg2 == 32 then
        vel = msg3
        if vel == 0 then vel = 96 end
      end
      if chanmsg == 192 then
        pitch = msg2
        reaper.MIDI_InsertNote(take, false, false, ppqpos, ppqpos+60, chan, pitch, vel, false)
      end
      flag = true
    end
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Program Change To Note"
reaper.Undo_BeginBlock()
Main()
if flag then
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40667)
end
reaper.Undo_EndBlock(script_title, 0)
reaper.SN_FocusMIDIEditor()
