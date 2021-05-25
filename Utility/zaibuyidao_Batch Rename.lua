--[[
 * ReaScript Name: Batch Rename
 * Version: 1.2
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2021-5-26)
  + 刪除無效代碼.
 * v1.1 (2021-5-25)
  + 修復排序Bug, 增加文件夾(父級)鍵.
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

function DightNum(num) -- 計算數字的位數
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

function AddZeroFrontNum(dest_dight, num) -- 在整數數字前面加0
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

local show_msg = reaper.GetExtState("BatchRename", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名"
    text = "$trackname -- 軌道名稱\n$takename -- 片段名稱\n$foldername -- 文件夾名稱\n$tracknum -- 軌道編號\n$inctrackorder -- 軌道順序\n$inctimeorder -- 時間順序\n$GUID -- Take guid\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRename", "ShowMsg", show_msg, true)
    end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local rn, d, a, z, pos, ins, del, f, r = '', '2', '0', '0', '0', '', '0', '', ''
local retval, retvals_csv = reaper.GetUserInputs("Batch Rename", 9, "Rename 重命名,Digits 位數,From Beginning 從左起,From End 從右起 (負數),At Position 位置,To Insert 插入,Remove 移除,Find What 查找,Replace With 替換,extrawidth=200", tostring(rn)..','..tostring(d)..','..tostring(a)..','..tostring(z)..','..tostring(pos)..','..tostring(ins)..','..tostring(del)..','..tostring(f)..','..tostring(r))
if not retval then return end
local rename, digits, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

begin_str = begin_str + 1
end_str = end_str - 1
digits = tonumber(digits)

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
    
    take_name_tb = {} -- 將take名稱存入表
    for o = 1, item_num_order - 1 do
        local item = sel_item_track[o]
        local take = reaper.GetActiveTake(item)
        local take_name = reaper.GetTakeName(take)
        take_name_tb[#take_name_tb + 1] = take_name
    end

    for k = 1, item_num_order - 1 do -- 每條軌道分別計算take num 1234 / 1234 
        local item = sel_item_track[k]
        local take = reaper.GetActiveTake(item)
        local take_guid = reaper.BR_GetMediaItemTakeGUID(take)

        if rename ~= '' then
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', rename, true)
        end

        take_name = reaper.GetTakeName(take)

        -- local check_s = string.gsub(rename, "%$", "") -- 检查 %$
        local check_k = string.gsub(rename, "%b[]", "") -- 检查 []
        if check_s ~= rename then flag = true else flag = false end
        -- local isTrue = reaper.SetMediaItemInfo_Value(item, "IP_ITEMNUMBER", item_num_new[k])

        if flag then
            new_order = math.abs(item_num_new[k] - (item_num_new[k] + k))
            new_order = math.floor(new_order)
            local check_inctrackorder = string.gsub(rename, "%$inctrackorder", "inctrackorder")
            if check_inctrackorder ~= rename then
                take_name = string.gsub(check_inctrackorder, 'inctrackorder', AddZeroFrontNum(digits, new_order))
            end

            local check_takename = string.gsub(take_name, "%$takename", "takename")
            if check_takename ~= take_name then
                take_name = string.gsub(check_takename, 'takename', take_name_tb[k])
                k = k + 1
            end

            local check_trackname = string.gsub(take_name, "%$trackname", "trackname")
            if check_trackname ~= take_name then
                take_name = string.gsub(check_trackname, 'trackname', track_name)
            end

            local check_tracknum = string.gsub(take_name, "%$tracknum", "tracknum")
            if check_tracknum ~= take_name then
                take_name = string.gsub(check_tracknum, 'tracknum', track_num)
            end

            local check_guid = string.gsub(take_name, "%$GUID", "GUID")
            if check_guid ~= take_name then
                take_name = string.gsub(check_guid, 'GUID', take_guid)
            end

            local check_foldername = string.gsub(take_name, "%$foldername", "foldername")
            if check_foldername ~= take_name then
                take_name = string.gsub(check_foldername, 'foldername', parent_buf)
            end
        end

        take_name = string.sub(take_name, begin_str, end_str)
        take_name = string.sub(take_name, 1, position) .. insert .. string.sub(take_name, position+1+delete)
        take_name = string.gsub(take_name, find, replace)
        -- take_name = (take_name):gsub(("."):rep(4),'%1'..'*'):sub(1, -2) -- 按指定間隔插入

        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
end

for z = 0, count_sel_items - 1 do  -- 獲取上面的takename，對take排序進行補償
    local diff = z + 1
    local item = reaper.GetSelectedMediaItem(0, z)
    local take = reaper.GetActiveTake(item)
    local take_name = reaper.GetTakeName(take)

    local check_ss = string.gsub(take_name, "%$", "") -- 检查 %$
    if check_ss ~= take_name then flag_1 = true else flag_1 = false end
    
    if flag_1 then
        local check_inctimeorder = string.gsub(take_name, "%$inctimeorder", "inctimeorder")
        if check_inctimeorder ~= take_name then
            take_name = string.gsub(check_inctimeorder, 'inctimeorder', AddZeroFrontNum(digits, diff))
        end
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
end

reaper.Undo_EndBlock('Batch Rename', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()