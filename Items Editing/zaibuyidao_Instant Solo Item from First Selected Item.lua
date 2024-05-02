-- @description Instant Solo Item from First Selected Item
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Intelligent SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

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

local function TableMax(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn < v then mn = v end
    end
    return mn
end

local function TableMin(t)
    local mn = nil
    for k, v in pairs(t) do
        if (mn == nil) then mn = v end
        if mn > v then mn = v end
    end
    return mn
end

local function UnselAllTrack()
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
    end
end

local function SaveSelectedItems(t)
    for i = 0, reaper.CountSelectedMediaItems(0)-1 do
        t[i+1] = reaper.GetSelectedMediaItem(0, i)
    end
end

local function RestoreSelectedItems(t)
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
    for _, item in ipairs(t) do
        reaper.SetMediaItemSelected(item, true)
    end
end

local function SaveSelectedTracks(t)
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        t[i+1] = reaper.GetSelectedTrack(0, i)
    end
end

local function RestoreSelectedTracks(t)
    UnselAllTrack()
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
end

function table.serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
      lua = lua .. obj
    elseif t == "boolean" then
      lua = lua .. tostring(obj)
    elseif t == "string" then
      lua = lua .. string.format("%q", obj)
    elseif t == "table" then
      lua = lua .. "{\n"
    for k, v in pairs(obj) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
    end
    local metatable = getmetatable(obj)
    if metatable ~= nil and type(metatable.__index) == "table" then
      for k, v in pairs(metatable.__index) do
        lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
      end
    end
    lua = lua .. "}"
    elseif t == "nil" then
      return nil
    else
      error("can not serialize a " .. t .. " type.")
    end
    return lua
end

function table.unserialize(lua)
    local t = type(lua)
    if t == "nil" or lua == "" then
      return nil
    elseif t == "number" or t == "string" or t == "boolean" then
      lua = tostring(lua)
    else
      error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = load(lua)
    if func == nil then return nil end
    return func()
end

function getSavedData(key1, key2)
    return table.unserialize(reaper.GetExtState(key1, key2))
end

function SaveMutedItems(t)
    for i = 0, reaper.CountMediaItems(0) - 1 do
        local item = reaper.GetMediaItem(0, i)
        t[#t+1] = {GUID = reaper.BR_GetMediaItemGUID(item), mute = reaper.GetMediaItemInfo_Value(item, "B_MUTE") }
    end
    reaper.SetExtState("InstantSoloItemfromFirstSelectedItem", "MutedItemRestores", table.serialize(t), false)
end

function RestoreMutedItems(t)
    t = getSavedData("InstantSoloItemfromFirstSelectedItem", "MutedItemRestores")
    for i = 1, #t do
        local item = reaper.BR_GetMediaItemByGUID(0, t[i].GUID)
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", t[i].mute)
    end
end

function SaveSoloTracks(t)
    for i = 1, reaper.CountTracks(0) do 
      local tr= reaper.GetTrack(0, i-1)
      t[#t+1] = { GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") }
    end
    reaper.SetExtState("InstantSoloItemfromFirstSelectedItem", "SoloTrackRestores", table.serialize(t), false)
end

function RestoreSoloTracks(t)
    t = getSavedData("InstantSoloItemfromFirstSelectedItem", "SoloTrackRestores")
    for i = 1, #t do
        local src_tr = reaper.BR_GetMediaTrackByGUID(0, t[i].GUID)
        reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", t[i].solo)
    end
end

item_restores = {}

function set_item_mute(item, value)
    local orig = reaper.GetMediaItemInfo_Value(item, "B_MUTE")
    if (value == orig) then return end
    reaper.SetMediaItemInfo_Value(item, "B_MUTE", value)
    table.insert(item_restores, function ()
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", orig)
    end)
end

function NoUndoPoint() end

reaper.PreventUIRefresh(1)

local cur_pos = reaper.GetCursorPosition()
local count_sel_items = reaper.CountSelectedMediaItems(0)

isPlay = reaper.GetPlayState()
init_muted_items = {}
init_Solo_Tracks = {}

-- init_sel_items = {}
-- init_sel_tracks = {}
-- SaveSelectedItems(init_sel_items)
-- SaveSelectedTracks(init_sel_tracks)

isPlay = reaper.GetPlayState()
snap_t = {}

if count_sel_items > 0 then 
    for i = 0, count_sel_items-1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local snap = item_pos + item_snap
        snap_t[#snap_t + 1] = snap
    end
    snap_pos = TableMin(snap_t)
end

if isPlay == 0 then
    SaveMutedItems(init_muted_items)
    SaveSoloTracks(init_Solo_Tracks)

    local screen_x, screen_y = reaper.GetMousePosition()
    local item_ret, take = reaper.GetItemFromPoint(screen_x, screen_y, true)
    local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

    snap_t = {}
    if count_sel_items > 0 then
        for i = 0, count_sel_items-1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local snap = item_pos + item_snap
            snap_t[#snap_t + 1] = snap
        end
        snap_pos = TableMin(snap_t)
    end

    if item_ret then
        take = reaper.GetActiveTake(item_ret)
        -- take_tarck = reaper.GetMediaItemTake_Track(take)
        -- check_track = reaper.GetMediaTrackInfo_Value(take_tarck, 'I_SELECTED')
        -- take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        item_snap = reaper.GetMediaItemInfo_Value(item_ret, "D_SNAPOFFSET")
        item_pos = reaper.GetMediaItemInfo_Value(item_ret, "D_POSITION")
        snap = item_pos + item_snap
    end

    init_sel_items = {}
    SaveSelectedItems(init_sel_items) -- 保存選中的item
    --init_sel_tracks = {}
    --SaveSelectedTracks(init_sel_tracks)
    init_solo_tracks = {}
    SaveSoloTracks(init_solo_tracks) -- 保存選中的軌道

    if count_sel_items == 0 then -- 沒有item被選中
        if item_ret then
            reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
            local track = reaper.GetMediaItem_Track(item_ret) -- 獲取鼠標下item對應的軌道
            reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2) -- 激活軌道的SOLO按鈕
            local item_num = reaper.CountTrackMediaItems(track) -- 計算item的總數

            for i = 0, item_num-1 do
                local item = reaper.GetTrackMediaItem(track, i) -- 獲取軌道下的所有item
                set_item_mute(item, 1) -- 設置為靜音
            end
            if reaper.GetMediaItemInfo_Value(item_ret, "B_MUTE") == 1 then
                set_item_mute(item_ret, 0) -- 設置為非靜音
            end
            reaper.SetEditCurPos(snap, 0, 0)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        else
            if track_ret then
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            end
            reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
            reaper.Main_OnCommand(1007, 0) -- Transport: Play
        end
    else -- 如果選中item大於0
        reaper.Main_OnCommand(40340, 0) -- Track: Unsolo all tracks
        local selected_track = {} -- 选中的轨道

        for m = 0, count_sel_items - 1  do
            local item = reaper.GetSelectedMediaItem(0, m)
            local track = reaper.GetMediaItem_Track(item)
            if (not selected_track[track]) then
                selected_track[track] = true
            end
        end
        for track, _ in pairs(selected_track) do
            --reaper.SetTrackSelected(track, true) -- 將軌道設置為選中
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
        reaper.SetEditCurPos(snap_pos, 0, 0)
        reaper.Main_OnCommand(1007, 0) -- Transport: Play
    end
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    RestoreMutedItems(init_muted_items)
    RestoreSoloTracks(init_Solo_Tracks)
end

reaper.SetEditCurPos(cur_pos, 0, 0)
--RestoreSelectedItems(init_sel_items)
--RestoreSelectedTracks(init_sel_tracks)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.defer(NoUndoPoint)