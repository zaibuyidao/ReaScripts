--[[
 * ReaScript Name: Set Solo Track
 * Version: 1.0
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

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
toggle_solo = reaper.GetExtState("ToggleSoloTrack", "Number")
persist = 0

if (toggle_solo == "") then
  toggle_solo = 1
  retval, retvals_csv = reaper.GetUserInputs('切換獨奏軌道', 2, '軌道編號,輸入1重啟將不再提示', toggle_solo .. ',' .. persist)
  if not retval then return end
  toggle_solo, persist = retvals_csv:match("(.*),(.*)")
  if not retval or not tonumber(toggle_solo) or not tonumber(persist) then return end
  persist = tonumber(persist)
  reaper.SetExtState("ToggleSoloTrack", "Number", toggle_solo, persist)
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

if flag then
  UnSoloTrack(toggle_solo)
else
  SoloTrack(toggle_solo)
end

reaper.UpdateArrange()