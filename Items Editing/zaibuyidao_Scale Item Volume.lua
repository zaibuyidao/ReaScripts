--[[
 * ReaScript Name: Scale Item Volume
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
 * v1.0 (2021-5-22)
  + Initial release
--]]

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local count_item = reaper.CountSelectedMediaItems(0)
if count_item == 0 then return end

local item_t, pos = {}, {}
for i = 0, count_item - 1 do
    item_t[i] = reaper.GetSelectedMediaItem(0, i)
    pos[i] = reaper.GetMediaItemInfo_Value(item_t[i], "D_POSITION")
end

local log10 = function(x) return math.log(x, 10) end
local a = 20*log10(reaper.GetMediaItemInfo_Value(item_t[0], 'D_VOL'))
local z = 20*log10(reaper.GetMediaItemInfo_Value(item_t[#item_t], 'D_VOL'))
local n = reaper.GetExtState("ScaleItemVolume", "Toggle")
if (n == "") then n = "0" end
local cur_range = tostring(a)..','..tostring(z)..','..tostring(n)
local retval, userInputsCSV = reaper.GetUserInputs("Scale Item Volume", 3, "Begin dB,End dB,Toggle (0=Absolute 1=Relative),extrawidth=60", cur_range)
if not retval then return end
local begin_db, end_db, toggle = userInputsCSV:match("(.*),(.*),(.*)")
n = toggle
reaper.SetExtState("ScaleItemVolume", "Toggle", n, false)
local offset_0 = (end_db - begin_db) / (pos[#pos] - pos[0])
local offset_1 = (end_db - begin_db) / count_item

for i = 0, count_item - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_vol = reaper.GetMediaItemInfo_Value(item, 'D_VOL')
    local item_db = 20*log10(item_vol)
    if toggle == '0' then
        local new_db = (item_pos - pos[0]) * offset_0 + begin_db
        local delta_db = new_db - item_db
        reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
    elseif toggle == '1' then
        local delta_db = begin_db - item_db
        reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
        begin_db = offset_1 + begin_db
        if i == count_item - 1 then -- 補償最後一個數
            delta_db = end_db - item_db
            reaper.SetMediaItemInfo_Value(item, 'D_VOL', item_vol*10^(0.05*delta_db))
        end
    end
end

reaper.Undo_EndBlock('Scale Item Volume', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()