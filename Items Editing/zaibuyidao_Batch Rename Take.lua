--[[
 * ReaScript Name: Batch Rename Take
 * Version: 1.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
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
    UnselectAllTracks()
    for _, track in ipairs(t) do
        reaper.SetTrackSelected(track, true)
    end
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

function chsize(char)
    if not char then
        return 0
    elseif char > 240 then
        return 4
    elseif char > 225 then
        return 3
    elseif char > 192 then
        return 2
    else
        return 1
    end
end
  
function utf8len(str)
    local len = 0
    local currentIndex = 1
    while currentIndex <= #str do
        local char = string.byte(str,currentIndex)
        currentIndex = currentIndex + chsize(char)
        len = len + 1
    end
    return len
end
  
function utf8sub(str,startChar,endChars)
    local startIndex = 1
    startChar = startChar + 1
    while startChar > 1 do
        local char = string.byte(str,startIndex)
        startIndex = startIndex + chsize(char)
        startChar = startChar - 1
    end
    local currentIndex = startChar
    newChars = utf8len(str) - endChars
    while newChars > 0 and currentIndex <= #str do
        local char = string.byte(str,currentIndex)
        currentIndex = currentIndex + chsize(char)
        newChars = newChars - 1
    end
    return str:sub(startIndex,currentIndex - 1)
end
  
function utf8sub2(str,startChar,endChars)
    local startIndex = 1
    startChar = startChar + 1
    while startChar > 1 do
        local char = string.byte(str,startIndex)
        startIndex = startIndex + chsize(char)
        startChar = startChar - 1
    end
    local currentIndex = startChar
    while tonumber(endChars) > 0 and currentIndex <= #str do
        local char = string.byte(str,currentIndex)
        currentIndex = currentIndex + chsize(char)
        endChars = endChars - 1
    end
    return str:sub(startIndex,currentIndex - 1)
end
  
function utf8sub_del(str,startChar)
    local startIndex = 1
    startChar = startChar + 1
    while startChar > 1 do
        local char = string.byte(str,startIndex)
        startIndex = startIndex + chsize(char)
        startChar = startChar - 1
    end
    return str:sub(startIndex)
end

local show_msg = reaper.GetExtState("BatchRenameTake", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名片段"
    text = "$trackname -- 軌道名稱\n$takename -- 片段名稱\n$foldername -- 文件夾名稱\n$tracknum -- 軌道編號\n$GUID -- Take guid\nv=001 -- Track order 軌道順序\nvt=001 -- Timeline order 時間順序\na=a -- Letter track order 字母軌道順序\nat=a -- Letter timeline order 字母時間順序\n"
    text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("BatchRenameTake", "ShowMsg", show_msg, true)
    end
end

init_sel_items = {}
init_sel_tracks = {}

SaveSelectedItems(init_sel_items)
SaveSelectedTracks(init_sel_tracks)

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local rn, a, z, pos, ins, del, f, r = '', '0', '0', '0', '', '0', '', ''
local retval, retvals_csv = reaper.GetUserInputs("Batch Rename Take", 8, "Rename 重命名,From beginning 截取開頭,From end 截取結尾,At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", tostring(rn)..','..tostring(a)..','..tostring(z)..','..tostring(pos)..','..tostring(ins)..','..tostring(del)..','..tostring(f)..','..tostring(r))
if not retval then return end
local rename, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

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

    for k = 1, item_num_order - 1 do -- 每條軌道分別計算take num
        local item = sel_item_track[k]
        local take = reaper.GetActiveTake(item)
        local take_guid = reaper.BR_GetMediaItemTakeGUID(take)

        take_name = reaper.GetTakeName(take)

        if rename ~= '' then
            take_name = rename
            --take_name = take_name:gsub("%$inctrackorder", AddZeroFrontNum(2, math.floor(new_order)))
            take_name = take_name:gsub("%$takename", take_name_tb[k])
            take_name = take_name:gsub('%$trackname', track_name)
            take_name = take_name:gsub('%$tracknum', track_num)
            take_name = take_name:gsub('%$GUID', take_guid)
            take_name = take_name:gsub('%$foldername', parent_buf)

            if string.match(take_name, "v=[%d+]*") ~= nil then -- 長度3
                local nbr = string.match(take_name, "v=[%d+]*")
                nbr = string.sub(nbr, 3) -- 截取3
                if tonumber(nbr) then
                    new_order = math.abs(item_num_new[k] - (item_num_new[k] + k))
                    new_order = new_order + nbr - 1
                    take_name = take_name:gsub("v="..nbr, function ()
                        nbr = AddZeroFrontNum(string.len(nbr), math.floor(new_order))
                        return tostring(nbr)
                    end)
                end
            end
    
            if string.match(take_name, "a=[A-Za-z]*") ~= nil then -- 長度3
                local xyz = string.match(take_name, "a=[A-Za-z]*")
                local xyz_len = string.len(xyz)
                local xyz_pos = string.sub(xyz, 3, 3) -- 截取3
            
                -- if xyz_len == 3 then
                    if string.find(xyz_pos,"(%u)") == 1 then
                        letter = string.upper(xyz_pos) -- 大寫
                        alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                    else
                        letter = string.lower(xyz_pos) -- 小寫
                        alphabet = 'abcdefghijklmnopqrstuvwxyz'
                    end
            
                    local letter_byte = string.char(letter:byte())
                    local letter_idx = alphabet:find(letter)
                    letter_idx = (letter_idx % #alphabet) + (k-1)
                    letter_idx = letter_idx % #alphabet
                    if letter_idx == 0 then letter_idx = #alphabet end
                    letter_byte = alphabet:sub(letter_idx, letter_idx)
              
                    take_name = take_name:gsub("a=" .. xyz_pos, letter_byte)
                -- end
            end
        end

        take_name = utf8sub(take_name,begin_str,end_str)
        take_name = utf8sub2(take_name,0,position)..insert..utf8sub_del(take_name,position+delete)
        take_name = string.gsub(take_name, find, replace)

        if insert ~= '' then
            --take_name = take_name:gsub("%$inctrackorder", AddZeroFrontNum(2, math.floor(new_order)))
            take_name = take_name:gsub("%$takename", take_name_tb[k])
            take_name = take_name:gsub('%$trackname', track_name)
            take_name = take_name:gsub('%$tracknum', track_num)
            take_name = take_name:gsub('%$GUID', take_guid)
            take_name = take_name:gsub('%$foldername', parent_buf)

            if string.match(take_name, "v=[%d+]*") ~= nil then -- 長度3
                local nbr = string.match(take_name, "v=[%d+]*")
                nbr = string.sub(nbr, 3) -- 截取3
                if tonumber(nbr) then
                    new_order = math.abs(item_num_new[k] - (item_num_new[k] + k))
                    new_order = new_order + nbr - 1
                    take_name = take_name:gsub("v="..nbr, function ()
                        nbr = AddZeroFrontNum(string.len(nbr), math.floor(new_order))
                        return tostring(nbr)
                    end)
                end
            end
    
            if string.match(take_name, "a=[A-Za-z]*") ~= nil then -- 長度3
                local xyz = string.match(take_name, "a=[A-Za-z]*")
                local xyz_len = string.len(xyz)
                local xyz_pos = string.sub(xyz, 3, 3) -- 截取3
            
                -- if xyz_len == 3 then
                    if string.find(xyz_pos,"(%u)") == 1 then
                        letter = string.upper(xyz_pos) -- 大寫
                        alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                    else
                        letter = string.lower(xyz_pos) -- 小寫
                        alphabet = 'abcdefghijklmnopqrstuvwxyz'
                    end
            
                    local letter_byte = string.char(letter:byte())
                    local letter_idx = alphabet:find(letter)
                    letter_idx = (letter_idx % #alphabet) + (k-1)
                    letter_idx = letter_idx % #alphabet
                    if letter_idx == 0 then letter_idx = #alphabet end
                    letter_byte = alphabet:sub(letter_idx, letter_idx)
              
                    take_name = take_name:gsub("a=" .. xyz_pos, letter_byte)
                -- end
            end
        end

        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
    end
end

for z = 0, count_sel_items - 1 do  -- 獲取上面的takename，對take排序進行補償
    local diff = z + 1
    local item = reaper.GetSelectedMediaItem(0, z)
    local take = reaper.GetActiveTake(item)
    local take_name = reaper.GetTakeName(take)

    if string.match(take_name, "vt=[%d+]*") ~= nil then -- 長度4
        local nbr = string.match(take_name, "vt=[%d+]*")
        nbr = string.sub(nbr, 4) -- 截取4
        if tonumber(nbr) then
            take_name = take_name:gsub("vt="..nbr, function ()
                nbr = AddZeroFrontNum(string.len(nbr), math.floor(diff+(nbr-1)))
                return tostring(nbr)
            end)
        end
    end

    if string.match(take_name, "at=[A-Za-z]*") ~= nil then -- 長度4
        local xyz = string.match(take_name, "at=[A-Za-z]*")
        local xyz_len = string.len(xyz)
        local xyz_pos = string.sub(xyz, 4, 4) -- 截取4

        -- if xyz_len == 4 then
            if string.find(xyz_pos,"(%u)") == 1 then
                letter = string.upper(xyz_pos) -- 大寫
                alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            else
                letter = string.lower(xyz_pos) -- 小寫
                alphabet = 'abcdefghijklmnopqrstuvwxyz'
            end
    
            local letter_byte = string.char(letter:byte())
            local letter_idx = alphabet:find(letter)
            letter_idx = (letter_idx % #alphabet) + z
            letter_idx = letter_idx % #alphabet
            if letter_idx == 0 then letter_idx = #alphabet end
            letter_byte = alphabet:sub(letter_idx, letter_idx)
            take_name = take_name:gsub("at=" .. xyz_pos, letter_byte)
        -- end
    end

    --take_name = take_name:gsub("%$inctimeorder", AddZeroFrontNum(2, math.floor(diff)))
    reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', take_name, true)
end

reaper.Undo_EndBlock('Batch Rename Take', -1)
RestoreSelectedItems(init_sel_items)
RestoreSelectedTracks(init_sel_tracks)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()