--[[
 * ReaScript Name: 重命名軌道
 * Version: 1.1
 * Author: 再補一刀, Yanick
 * Reference: https://forum.cockos.com/showthread.php?t=243582 (僅中文化並做適當調整)
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-20)
  + Initial release
--]]

count_sel_tracks = reaper.CountSelectedTracks(0)
if count_sel_tracks == 0 then return end

local j = 1
while j <= count_sel_tracks do
    local select_track = reaper.GetSelectedTrack(0, j - 1)
    local _, track_name = reaper.GetSetMediaTrackInfo_String(select_track, 'P_NAME', 0, false)
    retval, user_input_csv = reaper.GetUserInputs('重命名 '.. count_sel_tracks .. ' 條軌道中的第 '.. j .. ' 軌 - "ESC"後退', 1, '設置第 ' .. j .. ' 條軌道名:,extrawidth=150', track_name)
    user_input_csv = tostring(user_input_csv)
    if retval then
        if string.upper(user_input_csv) == 'ESC' then
            return
        else
            reaper.Undo_BeginBlock()
            reaper.GetSetMediaTrackInfo_String(select_track, 'P_NAME', user_input_csv, true)
            reaper.Undo_EndBlock( '為 ' .. count_sel_tracks .. ' 條選定軌道的第 ' .. j .. ' 軌設置名稱 ' .. '"' .. user_input_csv .. '"' , -1)
            j = j + 1
        end
    elseif not retval then
        if j == 1 then
            return
        else
            j = j - 1
        end
    end
end
