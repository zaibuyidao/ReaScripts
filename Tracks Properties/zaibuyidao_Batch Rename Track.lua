--[[
 * ReaScript Name: Batch Rename Track
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-7-17)
  + Initial release
--]]

local function Msg(str)
    reaper.ShowConsoleMsg(tostring(str).."\n")
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

local show_msg = reaper.GetExtState("SetTrackName", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
    script_name = "批量重命名軌道"
    text = "$trackname -- 軌道名稱\n$foldername -- 文件夾名稱\n$tracknum -- 軌道編號\n$GUID -- Track guid\nv=001 -- Track order 軌道順序\na=a -- Letter order 字母順序\n"
    text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
    local box_ok = reaper.ShowMessageBox("Wildcards 通配符 :\n\n"..text, script_name, 4)

    if box_ok == 7 then
        show_msg = "false"
        reaper.SetExtState("SetTrackName", "ShowMsg", show_msg, true)
    end
end

count_sel_tracks = reaper.CountSelectedTracks(0)
if count_sel_tracks == 0 then return end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local rn, a, z, pos, ins, del, f, r = '', '0', '0', '0', '', '0', '', ''
local retval, retvals_csv = reaper.GetUserInputs("Batch Rename Track", 8, "Rename 重命名,From beginning 截取開頭,From end 截取結尾 (負數),At position 位置,To insert 插入,Remove 移除,Find what 查找,Replace with 替換,extrawidth=200", tostring(rn)..','..tostring(a)..','..tostring(z)..','..tostring(pos)..','..tostring(ins)..','..tostring(del)..','..tostring(f)..','..tostring(r))
if not retval then return end
local rename, begin_str, end_str, position, insert, delete, find, replace = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

begin_str = begin_str + 1
end_str = end_str - 1

track_name_tb = {} -- 將track名稱存入表
parent_track_tb = {}
for i = 0, count_sel_tracks - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', "", false)

    parent_track = reaper.GetParentTrack(track)
    track_name_tb[#track_name_tb + 1] = track_name
    parent_track_tb[#parent_track_tb + 1] = parent_track

end

for i = 0, count_sel_tracks - 1 do -- 遍歷選中軌道
    local track = reaper.GetSelectedTrack(0, i)
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', 0, false)
    parent_track = reaper.GetParentTrack(track)
    track_guid = reaper.BR_GetMediaTrackGUID(track)

    if parent_track ~= nil then
        retval, parent_buf = reaper.GetTrackName(parent_track)
    else
        parent_buf = ''
    end

    track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    track_num = math.floor(track_num)
    track_num = AddZeroFrontNum(2, track_num)

    -- Msg(string.sub("a=abcdefghij", 3, 3))
    if rename ~= '' then
        track_name = rename

        track_name = track_name:gsub("%$trackname", track_name_tb[i+1])
        track_name = track_name:gsub('%$tracknum', track_num)
        track_name = track_name:gsub('%$GUID', track_guid)
        track_name = track_name:gsub('%$foldername', parent_buf)

        if string.match(track_name, "v=[%d+]*") ~= nil then -- 長度3
            local nbr = string.match(track_name, "v=[%d+]*")
            nbr = string.sub(nbr, 3) -- 截取3
            if tonumber(nbr) then
                track_name = track_name:gsub("v="..nbr, function ()
                    nbr = AddZeroFrontNum(string.len(nbr), math.floor(nbr+i))
                    return tostring(nbr)
                end)
            end
        end
    
        if string.match(track_name, "a=[A-Za-z]*") ~= nil then -- 長度3
            local xyz = string.match(track_name, "a=[A-Za-z]*")
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
                letter_idx = (letter_idx % #alphabet) + i
                letter_idx = letter_idx % #alphabet
                if letter_idx == 0 then letter_idx = #alphabet end
                letter_byte = alphabet:sub(letter_idx, letter_idx)
    
                track_name = track_name:gsub("a=" .. xyz_pos, letter_byte)
            -- end
        end
    end

    track_name = string.sub(track_name, begin_str, end_str)
    track_name = string.sub(track_name, 1, position) .. insert .. string.sub(track_name, position+1+delete)
    track_name = string.gsub(track_name, find, replace)

    if insert ~= '' then
        track_name = track_name:gsub("%$trackname", track_name_tb[i+1])
        track_name = track_name:gsub('%$tracknum', track_num)
        track_name = track_name:gsub('%$GUID', track_guid)
        track_name = track_name:gsub('%$foldername', parent_buf)

        if string.match(track_name, "v=[%d+]*") ~= nil then -- 長度3
            local nbr = string.match(track_name, "v=[%d+]*")
            nbr = string.sub(nbr, 3) -- 截取3
            if tonumber(nbr) then
                track_name = track_name:gsub("v="..nbr, function ()
                    nbr = AddZeroFrontNum(string.len(nbr), math.floor(nbr+i))
                    return tostring(nbr)
                end)
            end
        end

        if string.match(track_name, "a=[A-Za-z]*") ~= nil then -- 長度3
            local xyz = string.match(track_name, "a=[A-Za-z]*")
            local xyz_len = string.len(xyz)
            local xyz_pos = string.sub(xyz, 3, 3) -- 截取3

            --if xyz_len == 3 then
                if string.find(xyz_pos,"(%u)") == 1 then
                    letter = string.upper(xyz_pos) -- 大寫
                    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                else
                    letter = string.lower(xyz_pos) -- 小寫
                    alphabet = 'abcdefghijklmnopqrstuvwxyz'
                end
    
                local letter_byte = string.char(letter:byte())
                local letter_idx = alphabet:find(letter)
                letter_idx = (letter_idx % #alphabet) + i
                letter_idx = letter_idx % #alphabet
                if letter_idx == 0 then letter_idx = #alphabet end
                letter_byte = alphabet:sub(letter_idx, letter_idx)
    
                track_name = track_name:gsub("a=" .. xyz_pos, letter_byte)
            --end
        end
    end

    reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', track_name, true)
end
reaper.Undo_EndBlock('Batch Rename Track', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()