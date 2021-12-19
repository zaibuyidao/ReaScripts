--[[
 * ReaScript Name: Solo Track Play From Edit Cursor Position
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-9-20)
  + Initial release
--]]

function print(string) reaper.ShowConsoleMsg(tostring(string)..'\n') end

function print(param)
    if type(param) == "table" then
        table.print(param)
        return
    end
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
  end
  function table.print(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
end

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
    reaper.SetExtState("SoloTrackPlayEditCursorPosition", "SoloTrackRestores", table.serialize(t), false)
end

local function RestoreSoloTracks(t) -- 恢復Solo的軌道状态
    t = getSavedData("SoloTrackPlayEditCursorPosition", "SoloTrackRestores")
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