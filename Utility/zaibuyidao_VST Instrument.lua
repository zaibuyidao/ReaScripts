--[[
 * ReaScript Name: VST Instrument
 * Version: 1.1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * provides: [main=main,midi_editor] .
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2020-9-29)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function main()
  reaper.Undo_BeginBlock()
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    track = reaper.GetSelectedTrack(0, i)
    parent_track = reaper.GetParentTrack(track)
    vsti = reaper.TrackFX_GetInstrument(track)
    if vsti ~= -1 then
      for i = 0, reaper.TrackFX_GetCount(track) - 1 do
        float_window = reaper.TrackFX_GetFloatingWindow(track, i)
        if float_window == nil then
          reaper.TrackFX_Show(track, i, 3)
        else
          reaper.TrackFX_Show(track, i, 2)
        end
      end
    else
      if parent_track ~= nil then
        vsti_parent_track = reaper.TrackFX_GetInstrument(parent_track)
        float_parent_window = reaper.TrackFX_GetFloatingWindow(parent_track, vsti_parent_track)
        if float_parent_window == nil then
          reaper.TrackFX_Show(parent_track, vsti_parent_track, 3)
        else
          reaper.TrackFX_Show(parent_track, vsti_parent_track, 2)
        end
        if vsti_parent_track == -1 then
          reaper.Main_OnCommandEx(40271, 0, 0)
        end
      else
        if vsti == -1 then
          reaper.Main_OnCommandEx(40271, 0, 0)
        end
      end
    end
  end
  reaper.Undo_EndBlock("VST Instrument", -1)
end
main()
