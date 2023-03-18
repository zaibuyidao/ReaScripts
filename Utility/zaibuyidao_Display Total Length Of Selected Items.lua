-- @description Display Total Length Of Selected Items
-- @version 1.1.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @provides
--  [main=main,mediaexplorer] .
-- @donate http://www.paypal.me/zaibuyidao
-- @about NOT Requires JS_ReaScriptAPI & SWS Extension

function print(value)
    reaper.ShowConsoleMsg(tostring(value) .. "\n")
end

function getSystemLanguage()
    local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
    local os = reaper.GetOS()
    local lang
  
    if os == "Win32" or os == "Win64" then -- Windows
        if locale == 936 then -- Simplified Chinese
            lang = "简体中文"
        elseif locale == 950 then -- Traditional Chinese
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "OSX32" or os == "OSX64" then -- macOS
        local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
        if lang == "zh-CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh-TW" then -- 繁体中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "Linux" then -- Linux
        local handle = io.popen("echo $LANG")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
        if lang == "zh_CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh_TW" then -- 繁體中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    end
  
    return lang
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 获取选中的媒体项数量
local count_selected_items = reaper.CountSelectedMediaItems(0)
if count_selected_items == 0 then return end

-- 清除控制台信息
reaper.ClearConsole()

-- 定义变量
local length_sum = 0
local position_sum = 0
local length_start = {}
local length_end = {}
local take_names = {}
local same_take_name = true

-- 定义函数，用于查找数组中的最大值和最小值
local function find_extreme_value(array, mode)
    local extreme_value = array[1]
    for i = 2, #array do
        if mode == "max" and array[i] > extreme_value then
            extreme_value = array[i]
        elseif mode == "min" and array[i] < extreme_value then
            extreme_value = array[i]
        end
    end
    return extreme_value
end

-- 遍历选中的媒体项，计算长度、位置和名称信息
for i = 1, count_selected_items do
    local item = reaper.GetSelectedMediaItem(0, i - 1)

    local take = reaper.GetActiveTake(item)
    local take_name = reaper.GetTakeName(take)
    take_names[#take_names + 1] = take_name

    length_sum = length_sum + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    position_sum = position_sum + reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    local length_item = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local position_item = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local end_item = position_item + length_item

    length_start[#length_start + 1] = position_item
    length_end[#length_end + 1] = end_item
end

-- 计算选中媒体项的位置信息
local near_start_pos = find_extreme_value(length_start, "min")
local far_end_pos = find_extreme_value(length_end, "max")
local length_total = far_end_pos - near_start_pos

-- 判断选中媒体项是否具有相同的名称
for i = 2, #take_names do
    if take_names[1] ~= take_names[i] then
        same_take_name = false
        break
    end
end

-- 输出结果

local language = getSystemLanguage()

if language == "简体中文" then
    title = "显示所选对象的总长度"
    text_take_name = "对象名称:"
    text_count_selected_items = "对象数量:"
    text_total_duration = "总时长 (h:m:s.ms):"
    text_total_length = "总长度 (h:m:s.ms):"
    text_pos = "位置 (h:m:s.ms):"
elseif language == "繁体中文" then
    title = "顯示所選對象的總長度"
    text_take_name = "對象名稱:"
    text_count_selected_items = "對象數量:"
    text_total_duration = "總時長 (h:m:s.ms):"
    text_total_length = "總長度 (h:m:s.ms):"
    text_pos = "位置 (h:m:s.ms):"
else
    title = "Display Total Length Of Selected Items"
    text_take_name = "Take name:"
    text_count_selected_items = "Number of items:"
    text_total_duration = "Total duration (h:m:s.ms):"
    text_total_length = "Total length (h:m:s.ms):"
    text_pos = "Position (h:m:s.ms):"
    text_sum_total_length = "The sum of total length (h:m:s.ms):"
end

print(text_take_name)
if same_take_name then
    print(take_names[1])
else
    print("")
end
print("")
print(text_count_selected_items)
print(count_selected_items)
print("")
print(text_total_duration)
print(reaper.format_timestr(length_total, 5))
print("")
print(text_total_length)
print(reaper.format_timestr(length_sum, 5))
print("")
print(text_pos)
print(reaper.format_timestr(near_start_pos, 5) .. ' - ' .. reaper.format_timestr(far_end_pos, 5))
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()