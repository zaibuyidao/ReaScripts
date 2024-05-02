-- @description Instant Solo Track from Edit Cursor
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

local language = getSystemLanguage()

local function UnselectAllTracks() -- 反選所有軌道
    local first_track = reaper.GetTrack(0, 0)
    if first_track ~= nil then
        reaper.SetOnlyTrackSelected(first_track)
        reaper.SetTrackSelected(first_track, false)
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

local function SaveSoloTracks(t) -- 保存Solo的軌道
    for i = 1, reaper.CountTracks(0) do
        local tr= reaper.GetTrack(0, i-1)
        t[#t+1] = { GUID = reaper.GetTrackGUID(tr), solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") }
    end
    reaper.SetExtState("InstantSoloTrackfromEditCursor", "SoloTrackRestores", table.serialize(t), false)
end

local function RestoreSoloTracks(t) -- 恢復Solo的軌道状态
    t = getSavedData("InstantSoloTrackfromEditCursor", "SoloTrackRestores")
    for i = 1, #t do
        local src_tr = reaper.BR_GetMediaTrackByGUID(0, t[i].GUID)
        reaper.SetMediaTrackInfo_Value(src_tr, "I_SOLO", t[i].solo)
    end
end

function NoUndoPoint() end
reaper.PreventUIRefresh(1)

cur_pos = reaper.GetCursorPosition()
count_sel_items = reaper.CountSelectedMediaItems(0)
count_sel_track = reaper.CountSelectedTracks(0)
isPlay = reaper.GetPlayState()

init_solo_tracks = {}

if isPlay == 0 then
    SaveSoloTracks(init_solo_tracks) -- 保存選中的軌道
    local screen_x, screen_y = reaper.GetMousePosition()
    local track_ret, info_out = reaper.GetTrackFromPoint(screen_x, screen_y)

    if count_sel_track <= 1 then
        if track_ret then
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            if count_sel_items == 0 then
                --reaper.SetTrackSelected(track_ret, true)
                reaper.SetMediaTrackInfo_Value(track_ret, 'I_SOLO', 2)
            else
                local selected_track = {} -- 選中的軌道
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
                end
            end
        end
    elseif count_sel_track > 1 then
        if track_ret then
            reaper.Main_OnCommand(40340,0) -- Track: Unsolo all tracks
            for i = 0, count_sel_track-1 do
                local track = reaper.GetSelectedTrack(0, i)
                --reaper.SetTrackSelected(track, true) -- 將軌道設置為選中
                reaper.SetMediaTrackInfo_Value(track, 'I_SOLO', 2)
            end
        end
    end
    -- reaper.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    reaper.SetEditCurPos(cur_pos, 0, 0)
    reaper.Main_OnCommand(1007, 0) -- Transport: Play
end

if isPlay == 1 then
    reaper.Main_OnCommand(1016, 0) -- Transport: Stop
    RestoreSoloTracks(init_solo_tracks) -- 恢復Solo的軌道狀態
end

reaper.SetEditCurPos(cur_pos, 0, 0)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

reaper.defer(NoUndoPoint)