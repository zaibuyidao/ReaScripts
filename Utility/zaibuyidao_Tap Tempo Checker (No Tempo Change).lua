-- @description Tap Tempo Checker (No Tempo Change)
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension
--   Repeatedly run this action to tap tempo.
--   It does NOT change project tempo, playrate, or tempo markers.
--   Bind it to a shortcut key and tap repeatedly.

local SECTION = "TapTempoCheck_NoTempoChange"
local KEY     = "taps"

local MAX_TAPS     = 8    -- 保留最近 8 次点击（滚动平均）
local RESET_AFTER  = 4.0  -- 超过多少秒没点，自动重置
local MIN_INTERVAL = 0.12 -- 小于 120ms 的误触发忽略

function split_csv(s)
  local t = {}
  for v in string.gmatch(s or "", "[^,]+") do
    local n = tonumber(v)
    if n then t[#t + 1] = n end
  end
  return t
end

function join_csv(t)
  local out = {}
  for i = 1, #t do
    out[i] = tostring(t[i])
  end
  return table.concat(out, ",")
end

function show_msg(msg)
  local x, y = reaper.GetMousePosition()
  reaper.TrackCtl_SetToolTip(msg, x + 12, y + 18, true)
  reaper.ShowConsoleMsg("!SHOW:" .. msg .. "\n")
end

local now  = reaper.time_precise()
local taps = split_csv(reaper.GetExtState(SECTION, KEY))

if #taps > 0 then
  local dt = now - taps[#taps]

  if dt > RESET_AFTER then
    taps = {} -- 停太久，自动开始新一轮
  elseif dt < MIN_INTERVAL then
    show_msg("Tap ignored (" .. string.format("%.0f ms", dt * 1000) .. ")")
    reaper.defer(function() end) -- 防止生成 undo 点
    return
  end
end

taps[#taps + 1] = now

while #taps > MAX_TAPS do
  table.remove(taps, 1)
end

reaper.SetExtState(SECTION, KEY, join_csv(taps), false)

if #taps < 2 then
  show_msg("Tap 1 - continue tapping to calculate BPM")
  reaper.defer(function() end)
  return
end

local sum = 0.0
local count = 0
local last_interval = taps[#taps] - taps[#taps - 1]

for i = 2, #taps do
  local interval = taps[i] - taps[i - 1]
  sum = sum + interval
  count = count + 1
end

local avg_interval = sum / count
local avg_bpm  = 60.0 / avg_interval
local last_bpm = 60.0 / last_interval

local msg = string.format(
  "BPM %.2f | Last %.2f | %d taps",
  avg_bpm,
  last_bpm,
  #taps
)

show_msg(msg)

reaper.defer(function() end) -- 防止生成 undo 点