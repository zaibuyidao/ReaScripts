--[[
 * ReaScript Name: Link Selected Track FX Parameter (For Selected FX)
 * Version: 1.0.5
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-10-25)
  + Initial release
--]]

function Msg(string)
  reaper.ShowConsoleMsg(tostring(string).."\n")
end

only_first = false -- true or false: Set to true, Link The first FX of the same name. Set to false, Link all FX of the same name.

old_last_touched_fx = {} -- 記錄上一次GetLastTouchedFX的返回結果

function printLastTouched(prefix)
  Msg(
    prefix .. ":" ..
    tostring(old_last_touched_fx.last_touched_track_number) .. " " ..
    tostring(old_last_touched_fx.last_touched_fx_number) .. " " .. 
    tostring(old_last_touched_fx.last_touched_param_number)
  )
end

function main()
  reaper.PreventUIRefresh(1)

  local retval, last_touched_track_number, last_touched_fx_number, last_touched_param_number = reaper.GetLastTouchedFX()

  -- 上一次觸碰的fx是否已經改變
  local touch_changed = last_touched_fx_number ~= old_last_touched_fx.last_touched_fx_number or
  last_touched_param_number ~= old_last_touched_fx.last_touched_param_number

  -- 更新GetLastTouchedFX結果
  if touch_changed then
    -- printLastTouched("old:")
    old_last_touched_fx = {
      last_touched_track_number = last_touched_track_number,
      last_touched_fx_number = last_touched_fx_number,
      last_touched_param_number = last_touched_param_number
    }
    -- printLastTouched("new:")
  end

  if not retval or not last_touched_track_number then
    return reaper.defer(main)
  end

  -- track 聯動
  local last_touched_track = reaper.CSurf_TrackFromID(last_touched_track_number, false)
  if last_touched_track ~= nil and reaper.IsTrackSelected(last_touched_track) then
    local _, last_touched_fx_name = reaper.TrackFX_GetFXName(last_touched_track, last_touched_fx_number, "")
    local track_num_params = reaper.TrackFX_GetNumParams(last_touched_track, last_touched_fx_number)

    local track_fx_params_idx = 0
    local track_fx_params = {}
    while track_fx_params_idx < track_num_params do
      local val, _, _ = reaper.TrackFX_GetParam(last_touched_track, last_touched_fx_number, track_fx_params_idx)
      table.insert(track_fx_params, val)
      track_fx_params_idx = track_fx_params_idx + 1
    end

    local selected_tracks = {} -- 記錄所有選中的track
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
      table.insert(selected_tracks, reaper.GetSelectedTrack(0, i))
    end
    local master_track = reaper.GetMasterTrack(0)
    if reaper.IsTrackSelected(master_track) then
      table.insert(selected_tracks, master_track)
    end
    local last_touched_param_val = reaper.TrackFX_GetParam(last_touched_track, last_touched_fx_number, last_touched_param_number)

    -- 對所有選中的track遍歷
    for i, selected_track in pairs(selected_tracks) do

      -- for j = 0, reaper.TrackFX_GetCount(selected_track) - 1 do
      --   local _, selected_fx_name = reaper.TrackFX_GetFXName(selected_track, j, '')
      --   local selected_val = reaper.TrackFX_GetParam(selected_track, j, last_touched_param_number)
      --   if selected_track ~= last_touched_track and selected_fx_name == last_touched_fx_name and selected_val ~= last_touched_param_val then
      --     if touch_changed then -- 全量更新
      --       for k, v in ipairs(track_fx_params) do
      --         reaper.TrackFX_SetParam(selected_track, j, k - 1, v)
      --       end
      --     end
      --     if only_first then break end -- 如果開啟開關, 則直接跳出循環, 不再繼續尋找剩餘的fx
      --   end
      -- end

      local selected_fx_number = reaper.TrackFX_GetChainVisible(selected_track)
      --local selected_fx_number = reaper.CF_EnumSelectedFX(reaper.CF_GetTrackFXChain(selected_track), -1)
      local _, selected_fx_name = reaper.TrackFX_GetFXName(selected_track, selected_fx_number, '')
      local selected_val = reaper.TrackFX_GetParam(selected_track, selected_fx_number, last_touched_param_number)
      if selected_track ~= last_touched_track and selected_fx_name == last_touched_fx_name and selected_val ~= last_touched_param_val then
        if touch_changed then -- 全量更新
          for k, v in ipairs(track_fx_params) do
            reaper.TrackFX_SetParam(selected_track, selected_fx_number, k - 1, v)
          end
        end
      end

    end
    reaper.TrackFX_SetParam(last_touched_track, last_touched_fx_number, 0, track_fx_params[1])
  end
  
  reaper.PreventUIRefresh(-1)
  reaper.defer(main)
end

local _, _, sectionId, cmdId = reaper.get_action_context()
if sectionId ~= -1 then
  reaper.SetToggleCommandState(sectionId, cmdId, 1)
  reaper.RefreshToolbar2(sectionId, cmdId)
  main()
  reaper.atexit(function()
    reaper.SetToggleCommandState(sectionId, cmdId, 0)
    reaper.RefreshToolbar2(sectionId, cmdId)
  end)
end