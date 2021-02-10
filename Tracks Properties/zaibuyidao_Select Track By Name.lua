--[[
 * ReaScript Name: Select Track By Name
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2021-2-11)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function UnselectAllTracks() -- 反選所有軌道
    firstTrack = reaper.GetTrack(0, 0)
    if firstTrack == nil then return end
    reaper.SetOnlyTrackSelected(firstTrack)
    reaper.SetTrackSelected(firstTrack, false)
end

function deleteTrackByName(findname) -- 按軌道名刪除軌道
    for i = reaper.CountTracks()-1, 0, -1 do 
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name == findname then
            reaper.DeleteTrack(track)   
            break -- 退出循環/僅刪除一個匹配項
        end 
    end
end

reaper.Undo_BeginBlock() -- 撤銷塊開始
reaper.PreventUIRefresh(1)

local userOK, trackName = reaper.GetUserInputs("Select Track By Name", 1, "Enter name", "")
if not userOK then return end

UnselectAllTracks()

local countTracks = reaper.CountTracks(0) -- 計數所有軌道
local flagName
for i = 0, countTracks-1 do
    for j = 0, countTracks-1 do
        local track = reaper.GetTrack(0, j)
        if track ~= nil then
            reaper.SetTrackSelected(track, false)
            retval, noteName = reaper.GetTrackName(track, "")
            if retval then
                if noteName == trackName then
                    reaper.SetTrackSelected(track, true)
                end
            end
        end
    end
end

reaper.SelectAllMediaItems(0, false) -- 取消選擇所有item

for k = 0, reaper.CountSelectedTracks(0)-1 do -- 計數選中的item
    local slelTrack = reaper.GetSelectedTrack(0, k)
    local itemNum = reaper.CountTrackMediaItems(slelTrack)
    for i = 0, itemNum-1 do
        local item = reaper.GetTrackMediaItem(slelTrack, i)
        reaper.SetMediaItemSelected(item, true) -- 設置item為選中
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("Select Track By Name", 0) -- 撤銷塊結束