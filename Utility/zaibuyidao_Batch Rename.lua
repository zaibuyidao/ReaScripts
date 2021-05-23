--[[
 * ReaScript Name: Batch Rename
 * Version: 1.0
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
    text = "$trackname -- 軌道名稱\n$takename -- 片段名稱\n$tracknum -- 軌道編號\n$inctrackorder -- 軌道順序\n$inctimeorder -- 時間順序\n$GUID -- Take guid\n"
    text = text.."\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("可用鍵 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRename", "ShowMsg", show_msg, true)
    end
end

local count_sel_items = reaper.CountSelectedMediaItems(0)
reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if count_sel_items > 0 then
    local rn, d, a, z, pos, ins, del, f, r = '', '2', '0', '0', '0', '', '0', '', ''
    local retval, retvals_csv = reaper.GetUserInputs("Batch Rename", 9, "Rename 重命名,Digits 位數,From Beginning 從左起,From End 從右起(負數),At Position 位置,To Insert 插入,Remove 移除,Find What 查找,Replace With 替換,extrawidth=200", tostring(rn)..','..tostring(d)..','..tostring(a)..','..tostring(z)..','..tostring(pos)..','..tostring(ins)..','..tostring(del)..','..tostring(f)..','..tostring(r))
    if not retval then return end
    local rename, digits, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

    begin_str = begin_str + 1
    end_str = end_str - 1
    digits = tonumber(digits)
    local take_name_tb = {}

    for i = 0, count_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local take_name = reaper.GetTakeName(take)
        take_name_tb[#take_name_tb + 1] = take_name
    end

    for i = 0, count_sel_items - 1 do
        local begin_num = i + 1
        local item = reaper.GetSelectedMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local take_guid = reaper.BR_GetMediaItemTakeGUID(take)
        local track = reaper.GetMediaItem_Track(item)
        --local track = reaper.GetMediaItemTake_Track(take)
        local retval, track_name = reaper.GetTrackName(track)
        local track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
        track_num = math.floor(track_num)
        track_num = AddZeroFrontNum(2, track_num)
        local item_num = reaper.GetMediaItemInfo_Value(item, 'IP_ITEMNUMBER')
        item_num = math.floor(item_num) + 1

        local folder_depth = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERDEPTH')
        local folder_compact = reaper.GetMediaTrackInfo_Value(track, 'I_FOLDERCOMPACT')

        if rename ~= '' then
            reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', rename, true)
        end

        local take_name = reaper.GetTakeName(take)
        local check_k = string.gsub(rename, "%b[]", "") -- 检查 []
        local check_s = string.gsub(rename, "%$", "") -- 检查 %$
        if check_s ~= rename then flag = true else flag = false end

        if flag then
            local check_takename = string.gsub(rename, "%$takename", "takename")
            if check_takename ~= rename then
                i = i + 1
                take_name = string.gsub(check_takename, 'takename', take_name_tb[i])
            end

            local check_trackname = string.gsub(take_name, "%$trackname", "trackname")
            if check_trackname ~= take_name then
                take_name = string.gsub(check_trackname, 'trackname', track_name)
            end

            local check_tracknum = string.gsub(take_name, "%$tracknum", "tracknum")
            if check_tracknum ~= take_name then
                take_name = string.gsub(check_tracknum, 'tracknum', track_num)
            end

            local check_inctimeorder = string.gsub(take_name, "%$inctimeorder", "inctimeorder")
            if check_inctimeorder ~= take_name then
                take_name = string.gsub(check_inctimeorder, 'inctimeorder', AddZeroFrontNum(digits, begin_num))
            end

            local check_inctrackorder = string.gsub(take_name, "%$inctrackorder", "inctrackorder")
            if check_inctrackorder ~= take_name then
                take_name = string.gsub(check_inctrackorder, 'inctrackorder', AddZeroFrontNum(digits, item_num))
            end

            local check_guid = string.gsub(take_name, "%$GUID", "GUID")
            if check_guid ~= take_name then
                take_name = string.gsub(check_guid, 'GUID', take_guid)
            end

            -- local check_foldername = string.gsub(take_name, "%$foldername", "foldername")
            -- if check_foldername ~= take_name then
            --     take_name = string.gsub(check_foldername, 'foldername', folder_name)
            -- end
        end

        take_name = string.sub(take_name, begin_str, end_str)
        take_name = string.sub(take_name, 1, position) .. insert .. string.sub(take_name, position+1+delete)
        take_name = string.gsub(take_name, find, replace)
        -- take_name = (take_name):gsub(("."):rep(0),'%1'..'*'):sub(1, -2) -- 按指定间隔插入
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
end

reaper.Undo_EndBlock('Batch Rename', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()