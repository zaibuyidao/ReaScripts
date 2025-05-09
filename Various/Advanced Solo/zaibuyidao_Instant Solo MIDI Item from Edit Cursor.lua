-- NoIndex: true
local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
    dofile(ZBYDFuncPath)
    if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
    local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
    "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
    ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
    "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
    ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

    reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

    if reaper.APIExists('ReaPack_BrowsePackages') then
        reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
    else
        local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
        "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
        "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

        reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
    end
    return
end

-- 自定义简化版的序列化函数，仅处理简单的表结构，增加 nil 值检查
local function simpleSerialize(data)
    local parts = {"{"}
    for i, v in ipairs(data) do
        local guid = v.GUID or ""  -- 确保 GUID 不为 nil，若为 nil 则用空字符串代替
        local solo = v.solo or 0   -- 确保 solo 不为 nil
        local mute = v.mute or 0   -- 确保 mute 不为 nil
        parts[#parts + 1] = string.format("{GUID=%q,solo=%d,mute=%d},", guid, solo, mute)
    end
    parts[#parts + 1] = "}"
    return table.concat(parts)
end

-- 自定义反序列化函数，解析手动序列化的字符串
local function simpleDeserialize(serializedData)
    local data = {}
    for guid, solo, mute in serializedData:gmatch("{GUID=\"(.-)\",solo=(%d+),mute=(%d+)}") do
        table.insert(data, {GUID = guid, solo = tonumber(solo), mute = tonumber(mute)})
    end
    return data
end

-- 优化的保存数据函数，使用简化版序列化
local function saveData(key1, key2, data)
    local serializedData = simpleSerialize(data)
    reaper.SetExtState(key1, key2, serializedData, false)
end

-- 通用函数：获取保存的数据并反序列化
local function getSavedData(key1, key2)
    local serializedData = reaper.GetExtState(key1, key2)
    if serializedData == "" then return nil end
    return simpleDeserialize(serializedData)  -- 使用手动反序列化方法
end

-- 构建 GUID 到 item 的查找表
local function buildItemLookup()
    local itemLookup = {}
    for i = 0, reaper.CountMediaItems(0) - 1 do
        local item = reaper.GetMediaItem(0, i)
        itemLookup[reaper.BR_GetMediaItemGUID(item)] = item
    end
    return itemLookup
end

-- 保存静音的 items
function SaveMutedItems()
    local mutedItems = {}
    for i = 0, reaper.CountMediaItems(0) - 1 do
        local item = reaper.GetMediaItem(0, i)
        mutedItems[#mutedItems + 1] = {GUID = reaper.BR_GetMediaItemGUID(item), mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE")}
    end
    saveData("InstantSoloMIDIItemfromEditCursor", "MutedItemRestores", mutedItems)
end

-- 恢复静音状态的 items
function RestoreMutedItems()
    local mutedItems = getSavedData("InstantSoloMIDIItemfromEditCursor", "MutedItemRestores")
    if not mutedItems then return end
    local itemLookup = buildItemLookup()  -- 构建查找表
    for _, itemData in ipairs(mutedItems) do
        local item = itemLookup[itemData.GUID]  -- 使用查找表快速定位 item
        if item then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", itemData.mute)
        end
    end
end

item_restores = {}

function restore_items()
    -- 恢复items的状态
    for i = #item_restores, 1, -1 do
        item_restores[i]()
    end
    item_restores = {}
end

function set_item_mute(item, value)
    -- 设置item的静音状态，并记录原始状态以便恢复
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    if (value == orig) then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
    table.insert(item_restores, function()
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", orig)
    end)
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

local count_sel_items = reaper.CountSelectedMediaItems(0) -- 计算选中的items数量
local count_tracks = reaper.CountTracks(0)
local play_state = reaper.GetPlayState() -- 1 = playing, 2 = paused, 0 = stopped
local cursor_pos = reaper.GetCursorPosition()
init_muted_items = {}

if play_state == 0 then
    SaveMutedItems(init_muted_items)

    if count_sel_items > 0 then
        for i = 0, count_tracks - 1 do
            track = reaper.GetTrack(0, i)
            count_items_track = reaper.CountTrackMediaItems(track)

            for i = 0, count_items_track - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                set_item_mute(item, 1)
                if reaper.IsMediaItemSelected(item) == true then
                    set_item_mute(item, 0)
                end
            end
        end
    end

    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    if window == "midi_editor" then
        if not inline_editor then
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1140) -- Transport: Play
        else
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    else
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
    end
end

if play_state == 1 then
    reaper.CF_Preview_StopAll()
    local window, _, _ = reaper.BR_GetMouseCursorContext()
    local _, inline_editor, _, _, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
    if window == "midi_editor" then
        if not inline_editor then
            reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 1142) -- Transport: Stop
        else
            reaper.Main_OnCommand(1016, 0) -- Transport: Stop
        end
    else
        reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    end

    RestoreMutedItems(init_muted_items)
end

reaper.SetEditCurPos(cursor_pos, 0, 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)