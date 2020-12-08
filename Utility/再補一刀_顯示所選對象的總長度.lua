--[[
 * ReaScript Name: 顯示所選對象的總長度
 * Version: 1.1
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: X-Raym_Display sum of length of selected media items in the console.lua
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-4)
  + Initial release
--]]

console = true -- true/false: 在控制台中顯示調試消息

function Msg(value)
    if console then reaper.ShowConsoleMsg(tostring(value) .. "\n") end
end

function table_max(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

function table_min(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

function Main()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    reaper.ClearConsole()

    local len_sum = 0 -- 長度
    local len_pos = 0 -- 位置
    local len_start = {}
    local len_last = {}
    local same_pos = {}
    local len_end = {}
    local take_name_tb = {} -- 將take名存入表中進行比較

    if count_sel_items > 0 then
        for i = 1, count_sel_items do
            local item = reaper.GetSelectedMediaItem(0, i - 1)

            local take = reaper.GetActiveTake(item)
            local take_name = reaper.GetTakeName(take)
            take_name_tb[#take_name_tb + 1] = take_name

            len_sum = len_sum + reaper.GetMediaItemInfo_Value(item, "D_LENGTH") -- 長度
            len_pos = len_pos + reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- 位置

            local len_last_item = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") -- 每個item的長度
            local len_pos_item = reaper.GetMediaItemInfo_Value(item, "D_POSITION") -- 每個item的位置
            local len_end_item = len_pos_item + len_last_item -- 每個item的結束位置

            len_start[#len_start + 1] = len_pos_item
            len_last[#len_last + 1] = len_last_item
            len_end[#len_end + 1] = len_end_item
        end

        far_start_pos = table_max(len_start) -- 最遠的開始位置
        near_start_pos = table_min(len_start) -- 最近的開始位置
        far_end_pos = table_max(len_end) -- 最遠的結束位置

        local len_total = far_end_pos - near_start_pos -- 總長度

        flag_nil = {}

        for i = 1, #take_name_tb do
            if (take_name_tb[1] == take_name_tb[i]) then
                flag = 1
            else
                flag = 0
                flag_nil[#flag_nil + 1] = flag
            end
        end

        if count_sel_items > 1 then
            if flag_nil[1] == 0 then
                Msg("對象名稱:")
                Msg("")
                Msg("")
            else
                Msg("對象名稱:")
                Msg(take_name_tb[1])
                Msg("")
            end
        else
            Msg("對象名稱:")
            Msg(take_name_tb[1])
            Msg("")
        end

        Msg("所選對象數量:")
        Msg(count_sel_items)
        Msg("")

        Msg("總長度(h:m:s.ms)")
        Msg(reaper.format_timestr(len_total, 5))
        Msg("")

        Msg("位置(h:m:s.ms)")
        Msg(reaper.format_timestr(near_start_pos, 5) .. ' - ' .. reaper.format_timestr(far_end_pos, 5))
        -- Msg("")

        -- Msg("總長度之和(h:m:s.ms)")
        -- Msg(reaper.format_timestr(len_sum, 5))
        -- Msg("")

        -- Msg("平均長度 (h:m:s.ms)")
        -- Msg(reaper.format_timestr(len_sum / count_sel_items, 5))
        -- Msg("")
    end
end

reaper.defer(Main)
