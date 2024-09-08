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

function un_solo_all_tracks()
    -- 取消所有轨道的Solo状态
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 0)
    end
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

-- 构建 GUID 到 track 的查找表
local function buildTrackLookup()
    local trackLookup = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        trackLookup[reaper.GetTrackGUID(track)] = track
    end
    return trackLookup
end

-- 保存静音的 items
function SaveMutedItems()
    local mutedItems = {}
    for i = 0, reaper.CountMediaItems(0) - 1 do
        local item = reaper.GetMediaItem(0, i)
        mutedItems[#mutedItems + 1] = {GUID = reaper.BR_GetMediaItemGUID(item), mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE")}
    end
    saveData("InstantSoloItemfromMousePosition", "MutedItemRestores", mutedItems)
end

-- 恢复静音状态的 items
function RestoreMutedItems()
    local mutedItems = getSavedData("InstantSoloItemfromMousePosition", "MutedItemRestores")
    if not mutedItems then return end
    local itemLookup = buildItemLookup()  -- 构建查找表
    for _, itemData in ipairs(mutedItems) do
        local item = itemLookup[itemData.GUID]  -- 使用查找表快速定位 item
        if item then
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", itemData.mute)
        end
    end
end

-- 保存 solo 状态的 tracks
function SaveSoloTracks()
    local soloTracks = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        soloTracks[#soloTracks + 1] = {
            GUID = reaper.GetTrackGUID(track),
            solo = solo,
            mute = mute
        }
    end
    saveData("InstantSoloItemfromMousePosition", "SoloTrackRestores", soloTracks)
end

-- 恢复 solo 状态的 tracks
function RestoreSoloTracks()
    local soloTracks = getSavedData("InstantSoloItemfromMousePosition", "SoloTrackRestores")
    if not soloTracks then return end
    local trackLookup = buildTrackLookup()  -- 构建轨道查找表

    for _, trackData in ipairs(soloTracks) do
        local track = trackLookup[trackData.GUID]  -- 使用查找表快速定位 track
        if track then
            -- 恢复 Solo 状态并确保是数值
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", tonumber(trackData.solo) or 0)
            -- 恢复 Mute 状态
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", tonumber(trackData.mute) or 0)
        end
    end
end

item_restores = {}

function set_item_mute(item, value)
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    if (value == orig) then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
    table.insert(item_restores, function()
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", orig)
    end)
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

local cursor_pos = reaper.GetCursorPosition()
local count_sel_items = reaper.CountSelectedMediaItems(0)

play_state = reaper.GetPlayState()
init_muted_items = {}
init_Solo_Tracks = {}

if play_state == 0 then
    SaveMutedItems(init_muted_items)
    SaveSoloTracks(init_Solo_Tracks)

    local screen_x, screen_y = reaper.GetMousePosition()
    local item_ret, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
    local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

    if count_sel_items == 0 then
        un_solo_all_tracks()

        if item_ret then
            local track = reaper.GetMediaItem_Track(item_ret)
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
            local item_num = reaper.CountTrackMediaItems(track)

            for i = 0, item_num-1 do
                local item = reaper.GetTrackMediaItem(track, i)
                set_item_mute(item, 1)
            end
            if reaper.GetMediaItemInfo_Value(item_ret, "B_MUTE") == 1 then
                set_item_mute(item_ret, 0)
            end
        else
            if track_ret then
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            end
        end
    else
        un_solo_all_tracks()
        local selected_track = {}

        for m = 0, count_sel_items - 1  do
            local item = reaper.GetSelectedMediaItem(0, m)
            local track = reaper.GetMediaItem_Track(item)
            if (not selected_track[track]) then
                selected_track[track] = true
            end
        end
        for track, _ in pairs(selected_track) do
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
            local item_num = reaper.CountTrackMediaItems(track)

            for i = 0, item_num - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                set_item_mute(item, 1)
                if reaper.IsMediaItemSelected(item) == true then
                    set_item_mute(item, 0)
                end
            end
        end
    end
    
    reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    reaper.Main_OnCommand(1007, 0) -- Transport: Play
end

if play_state == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    RestoreMutedItems(init_muted_items)
    RestoreSoloTracks(init_Solo_Tracks)
end

reaper.SetEditCurPos(cursor_pos, 0, 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)