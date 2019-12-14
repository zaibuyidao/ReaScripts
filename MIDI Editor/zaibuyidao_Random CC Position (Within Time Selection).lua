--[[
 * ReaScript Name: Random CC Position (Within Time Selection)
 * Instructions: Open a MIDI take in MIDI Editor. Set Time Selection, Run.
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  time_start, time_end = reaper.GetSet_LoopTimeRange2( 0, false, false, 0, 0, 0)
  local loop_start = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_start))
  local loop_end = math.floor(0.5 + reaper.MIDI_GetPPQPosFromProjTime(take, time_end))
  local loop_len = loop_end - loop_start - 1
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end

  if #index > 1 then
    for i = 1, #index do
      local retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
      reaper.MIDI_SetCC(take, index[i], sel, muted, loop_start+math.random(loop_len), chanmsg, chan, msg2, msg3, true)
    end
  end
  reaper.UpdateArrange()
end

script_title = "Random CC Position"
reaper.Undo_BeginBlock()
reaper.MIDIEditor_LastFocused_OnCommand(40747, 0) -- Edit: Select all CC events in time selection (in last clicked CC lane)
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
