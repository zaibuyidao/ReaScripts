--[[
 * ReaScript Name: Set Take Name
 * Version: 1.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-5-23)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
end

function UnselectAllTracks()
    first_track = reaper.GetTrack(0, 0)
    reaper.SetOnlyTrackSelected(first_track)
    reaper.SetTrackSelected(first_track, false)
end

function DightNum(num)
    if math.floor(num) ~= num or num < 0 then
        return -1
    elseif 0 == num then
        return 1
    else
        local tmp_dight = 0
        while num > 0 do
            num = math.floor(num/10)
            tmp_dight = tmp_dight + 1
        end
        return tmp_dight 
    end
end

function AddZeroFrontNum(dest_dight, num)
    local num_dight = DightNum(num)
    if -1 == num_dight then 
        return -1 
    elseif num_dight >= dest_dight then
        return tostring(num)
    else
        local str_e = ""
        for var =1, dest_dight - num_dight do
            str_e = str_e .. "0"
        end
        return str_e .. tostring(num)
    end
end

local show_msg = reaper.GetExtState("SetTakeName", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "設置片段名稱"
    text = "$trackname -- 軌道名稱\n$foldername -- 文件夾名稱\n$tracknum -- 軌道編號\n$inctrackorder -- 軌道順序\n$inctimeorder -- 時間順序\n$GUID -- Take guid\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("SetTakeName", "ShowMsg", show_msg, true)
    end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local rename = reaper.GetExtState("SetTakeName", "Name")
if (rename == "") then rename = "Take_$inctrackorder" end
local order = reaper.GetExtState("SetTakeName", "Order")
if (order == "") then order = "1" end

local retval, retvals_csv = reaper.GetUserInputs("Set Take Name", 2, "Take name 片段名,Order 順序,extrawidth=200", rename..','..order)
if not retval or not tonumber(order) then return end
rename, order = retvals_csv:match("(.*),(.*)")

reaper.SetExtState("SetTakeName", "Name", rename, false)
reaper.SetExtState("SetTakeName", "Order", order, false)

order = tonumber(order - 1)

UnselectAllTracks()

for m = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, m)
    local track = reaper.GetMediaItem_Track(item)
    reaper.SetTrackSelected(track, true)
end

count_sel_track = reaper.CountSelectedTracks(0)

for i = 0, count_sel_track - 1 do -- 遍歷選中軌道
    track = reaper.GetSelectedTrack(0, i)
    count_track_items = reaper.CountTrackMediaItems(track)
    _, track_name = reaper.GetTrackName(track)
    parent_track = reaper.GetParentTrack(track)
    if parent_track ~= nil then
    retval, parent_buf = reaper.GetTrackName(parent_track)
    else
        parent_buf = ''
    end

    track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    track_num = math.floor(track_num)
    track_num = AddZeroFrontNum(2, track_num)

    sel_item_track = {}
    item_num_new = {}
    item_num_order = 1 
    
    for j = 0, count_track_items - 1  do -- 對選中的take重新排序
        item = reaper.GetTrackMediaItem(track, j)
        if reaper.IsMediaItemSelected(item) == true then
            sel_item_track[item_num_order] = item
            item_num_new[item_num_order] = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
            item_num_order = item_num_order + 1
        end
    end
    
    for k = 1, item_num_order - 1 do -- 每條軌道分別計算take num 1234.. / 1234..
        local item = sel_item_track[k]
        local take = reaper.GetActiveTake(item)
        local take_guid = reaper.BR_GetMediaItemTakeGUID(take)

        if rename ~= '' then
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', rename, true)
        end

        new_order = math.abs(item_num_new[k] - (item_num_new[k] + k))
        new_order = new_order + order
        take_name = rename:gsub("%$inctrackorder", AddZeroFrontNum(2, math.floor(new_order)))
        take_name = take_name:gsub('%$trackname', track_name)
        take_name = take_name:gsub('%$tracknum', track_num)
        take_name = take_name:gsub('%$GUID', take_guid)
        take_name = take_name:gsub('%$foldername', parent_buf)

        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
end

for z = 0, count_sel_items - 1 do  -- 獲取上面的takename，對take排序進行補償
    local diff = z + 1 + order
    local item = reaper.GetSelectedMediaItem(0, z)
    local take = reaper.GetActiveTake(item)
    local take_name = reaper.GetTakeName(take)

    take_name = take_name:gsub("%$inctimeorder", AddZeroFrontNum(2, math.floor(diff)))
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
end

reaper.Undo_EndBlock('Set Take Name', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()