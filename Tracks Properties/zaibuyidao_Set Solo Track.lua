--[[
 * ReaScript Name: Set Solo Track
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
 * provides: [main=main,midi_editor,midi_eventlisteditor] .
--]]

--[[
 * Changelog:
 * v1.0 (2021-4-18)
  + Initial release
--]]

-- 用戶配置區 --

persist = 1 -- 下次啓動REAPER之彈窗開關：0彈窗，1不彈窗

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
toggle_solo = reaper.GetExtState("SetSoloTrack", "Number")

if (toggle_solo == "") then
  toggle_solo = 1
  retval, retvals_csv = reaper.GetUserInputs('Set Solo Track', 1, 'Track Number 軌道編號:', toggle_solo)
  if not retval then return end
  toggle_solo = retvals_csv:match("(.*)")
  if not retval or not tonumber(toggle_solo) then return end
  reaper.SetExtState("SetSoloTrack", "Number", toggle_solo, persist)
end

toggle_solo = tonumber(toggle_solo) - 1 -- 偏移SOLO軌道

function UnSoloTrack(toggle_solo)
  track = reaper.GetTrack(0, toggle_solo)
  reaper.CSurf_OnSoloChange(track, 0)
end

function SoloTrack(toggle_solo)
  local cnt_tarck = reaper.CountTracks(0)
  for i = 0, cnt_tarck - 1 do
    local track = reaper.GetTrack(0, i)
    if i == toggle_solo then
      reaper.CSurf_OnSoloChange(track, 1)
    -- else
    --   reaper.CSurf_OnSoloChange(track, 0) -- 排除SOLO軌道
    end
  end
end

cnt_tarck = reaper.CountTracks(0)
for i = 0, cnt_tarck - 1 do
  track = reaper.GetTrack(0, i)
  if i == toggle_solo then
    iSOLO = reaper.GetMediaTrackInfo_Value(track, 'I_SOLO')
    if iSOLO == 1 or iSOLO == 2 then
      flag = true
    elseif iSOLO == 0 then
      flag = false
    end
  end
end

function NoUndoPoint() end

if flag then
  UnSoloTrack(toggle_solo)
else
  SoloTrack(toggle_solo)
end

reaper.defer(NoUndoPoint)
reaper.UpdateArrange()