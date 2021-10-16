--[[
 * ReaScript Name: Link Selected Track-Item FX Parameter
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
 * v1.0 (2021-10-16)
  + Initial release
--]]

function Msg(string)
  reaper.ShowConsoleMsg(tostring(string).."\n")
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

local last_paramnumber = -1
local last_val = -10000000
local changed = false

function main()

  local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
  if not retval or not tracknumber then
    return reaper.defer(main)
  end
  
  local items_count = reaper.CountSelectedMediaItems(0)

  local item_idx = tracknumber >> 16
  local track_idx = tracknumber & 0xffff
  local track_id =  reaper.GetTrack(0, track_idx - 1)
  local item_id = reaper.GetTrackMediaItem(track_id, item_idx - 1)

  if item_id ~= nil then

    if not reaper.IsMediaItemSelected(item_id) then
      return reaper.defer(main)
    end

    local take = reaper.GetActiveTake(item_id)
    local val, minval, maxval = reaper.TakeFX_GetParam(take, fxnumber, paramnumber)
    val = round(val, 7)
    local fxname_ret, fxname = reaper.TakeFX_GetFXName(take, fxnumber, '')
  
    local changed = paramnumber ~= last_paramnumber or last_val ~= val
    last_paramnumber = paramnumber
    last_val = val

    if not changed then
      return reaper.defer(main)
    end

    for m = 0, items_count - 1 do
      local item = reaper.GetSelectedMediaItem(0, m)
      local take = reaper.GetActiveTake(item)
  
      val = round(val, 7)
      for i = 0, reaper.TakeFX_GetCount(take) - 1 do
        local dest_fxname_ret, dest_fxname = reaper.TakeFX_GetFXName(take, i, '')
        if dest_fxname == fxname then
          reaper.TakeFX_SetParam(take, i, paramnumber, val)
        end
      end
    end

  else
 
    local track_id = reaper.CSurf_TrackFromID(tracknumber, false)
    if track_id ~= nil and reaper.IsTrackSelected(track_id) then
      local val, minvalOut, maxvalOut = reaper.TrackFX_GetParam(track_id, fxnumber, paramnumber)
      local fx_name_ret, fx_name = reaper.TrackFX_GetFXName(track_id, fxnumber, "")
      val=round(val,7)
      changed = paramnumber ~= last_paramnumber or last_val~=val
      if changed then
        last_val = val 
        last_paramnumber = paramnumber
        for i=1, reaper.CountSelectedTracks(0) do
          local tr = reaper.GetSelectedTrack(0, i-1)
          for fx_i=1, reaper.TrackFX_GetCount(tr) do
            local dest_fx_name_ret, dest_fx_name = reaper.TrackFX_GetFXName(tr, fx_i-1, "")
            if dest_fx_name == fx_name then
              reaper.TrackFX_SetParam(tr, fx_i-1, paramnumber, val)
            end
          end
        end
      end
    end
    
  end
  reaper.defer(main)
end

main()