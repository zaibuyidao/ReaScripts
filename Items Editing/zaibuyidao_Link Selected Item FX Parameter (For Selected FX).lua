--[[
 * ReaScript Name: Link Selected Item FX Parameter (For Selected FX)
 * Version: 1.0.1
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

  local item_idx = last_touched_track_number >> 16
  local track_idx = last_touched_track_number & 0xffff

  local last_touched_item_from_track
  local last_touched_item
  if track_idx > 0 then
    last_touched_item_from_track =  reaper.GetTrack(0, track_idx - 1)
    last_touched_item = reaper.GetTrackMediaItem(last_touched_item_from_track, item_idx - 1)
  end

  -- Link item
  if last_touched_item ~= nil then
    if not reaper.IsMediaItemSelected(last_touched_item) then return reaper.defer(main) end

    local last_touched_take = reaper.GetActiveTake(last_touched_item)
    local _, last_touched_fx_name = reaper.TakeFX_GetFXName(last_touched_take, last_touched_fx_number, '')
    local item_num_params = reaper.TakeFX_GetNumParams(last_touched_take, last_touched_fx_number)

    local items_count = reaper.CountSelectedMediaItems(0)
    local last_touched_param_val = reaper.TakeFX_GetParam(last_touched_take, last_touched_fx_number, last_touched_param_number)

    -- 對所有選中的item遍歷
    for selected_item_idx = 0, items_count - 1 do
      local selected_item = reaper.GetSelectedMediaItem(0, selected_item_idx)
      local selected_take = reaper.GetActiveTake(selected_item)
      
      local selected_fx_number = reaper.CF_EnumSelectedFX(reaper.CF_GetTakeFXChain(selected_take), -1)
      local _, selected_fx_name = reaper.TakeFX_GetFXName(selected_take, selected_fx_number, '')
      local selected_val = reaper.TakeFX_GetParam(selected_take, selected_fx_number, last_touched_param_number)
      if selected_fx_name == last_touched_fx_name and selected_val ~= last_touched_param_val then
        for params_idx = 0, reaper.TakeFX_GetNumParams(last_touched_take, last_touched_fx_number) - 1 do
          local val, _, _ = reaper.TakeFX_GetParam(last_touched_take, last_touched_fx_number, params_idx)
          reaper.TakeFX_SetParam(selected_take, selected_fx_number, params_idx, val)
        end
      end
    end

    reaper.TakeFX_SetParam(
      last_touched_take, last_touched_fx_number, last_touched_param_number, 
      reaper.TakeFX_GetParam(last_touched_take, last_touched_fx_number, last_touched_param_number)
    )

  end

  reaper.defer(main)
  reaper.PreventUIRefresh(-1)
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