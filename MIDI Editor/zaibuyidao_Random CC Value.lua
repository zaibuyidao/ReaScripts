--[[
 * ReaScript Name: Random CC Value
 * Version: 2.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
--]]

local diff = 127

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
  reaper.MIDI_DisableSort(take)
  for i = 0,  ccevtcnt-1 do
    retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if selected == true then
      reaper.MIDI_SetCC(take, i, nil, nil, nil, nil, nil, nil, math.random(diff), false)
    end
    i=i+1
  end
  reaper.UpdateArrange()
  reaper.MIDI_Sort(take)
end

script_title = "Random CC Value"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, 0)