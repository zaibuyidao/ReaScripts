--[[
 * ReaScript Name: VST Instrument
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: MPL Show VSTis on selected track
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-29)
  + Initial release
--]]

function main()
  reaper.Undo_BeginBlock()
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    track = reaper.GetSelectedTrack(0, i)
    vsti_id = reaper.TrackFX_GetInstrument(track)
    for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
      if fx == vsti_id then
        reaper.TrackFX_Show(track, fx, 3)
      end
    end
    if vsti_id == -1 then
      reaper.Main_OnCommandEx(40271, 0, 0)
    end
  end
  reaper.Undo_EndBlock("VST Instrument", -1)
end
main()