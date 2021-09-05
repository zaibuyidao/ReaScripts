--[[
 * ReaScript Name: Strum Rebuilding
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
 * v1.0 (2021-9-5)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) --全局take值
if not take or not reaper.TakeIsMIDI(take) then return end

function table.sortByKey(tab,key,ascend)
    if ascend==nil then ascend=true end
    table.sort(tab,function(a,b)
        if ascend then return a[key]<b[key] end
        return a[key]>b[key]
    end)
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

function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter == "") then return false end
    local pos, arr = 0, {}
    for st, sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

function getNote(sel) --根据传入的sel索引值，返回指定位置的含有音符信息的表
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
    return {
        ["retval"]=retval,
        ["selected"]=selected,
        ["muted"]=muted,
        ["startPos"]=startPos,
        ["endPos"]=endPos,
        ["channel"]=channel,
        ["pitch"]=pitch,
        ["vel"]=vel,
        ["sel"]=sel
    }
end
function setNote(note,sel,arg) --传入一个音符信息表已经索引值，对指定索引位置的音符信息进行修改
    reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end
function selNoteIterator() --迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end
function getMutiInput(title,num,lables,defaults)
    title=title or "Title"
    lables=lables or "Lable:"
    local userOK, getValue = reaper.GetUserInputs(title, num, lables, defaults)
    if userOK then return string.split(getValue,",") end
end

function table.check(value) -- 检查变量是否为table
    if type(value) ~= "table" then
        value={}
    end
    return value
end
function table.nums(t) -- 获取table元素个数
    local count = 0
    local t = table.check( t )
    for k, v in pairs( t ) do
        count = count + 1
    end
    return count
end
function table.addIncrese(tab,key1,key2,val) -- 返回一个表，该表包含了每个被选中的音符起始位置应该增加的长度信息，并使用pitch+startPos进行查询
    local increse=0
    local info={}
    for index,value in ipairs(tab) do
        info[ value[key1] ..",".. value[key2] ]=increse
        increse=increse+val
    end
    return info
end
function noteIterator() -- 迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end

local tick = reaper.GetExtState("StrumRebuilding", "Tick")
if (tick == "") then tick = "3" end
local rangeR = reaper.GetExtState("StrumRebuilding", "TangeR")
if (rangeR == "") then rangeR = "10" end

local inputs= getMutiInput("Strum Rebuilding",2,"New tick 嘀嗒數,Range tick 嘀嗒範圍",tick..','..rangeR) --获取用户输入
if not inputs then return end
local tick=tonumber(inputs[1]) -- 间隔值
local rangeL=0 --起始范围
local rangeR=tonumber(inputs[2]) --结束范围

if (not tick) or (not rangeR) or (rangeR<0) then return end --判断用户输入是否合法

reaper.SetExtState("StrumRebuilding", "Tick", tick, false)
reaper.SetExtState("StrumRebuilding", "TangeR", rangeR, false)

local noteGroups={} --音符组,以第一个插入的音符起始位置作为索引
local groupData={} --音符组的索引对应的最近一次插入的音符的起始位置，即 最近一次插入的音符起始位置=groupData[音符组索引]
local flag --用以标记当前音符是否已经插入到音符组中
local diff --差值
local lastIndex --上一个插入音符的索引

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)

for note in selNoteIterator() do
    flag=false
    for index,notes in pairs(noteGroups) do
        diff=math.abs(note.startPos-groupData[index]) --计算差值
        if diff <= rangeR and diff >= rangeL and index==lastIndex then --判断差值是否符合
            table.insert(noteGroups[index],note)
            groupData[index]=note.startPos
            flag=true --如果符合则插入音符组，并标记flag
            break
        end
    end
    if flag then goto continue end --如果flag被标记，那么音符已经插入过，直接处理下一个音符
    noteGroups[note.startPos]={} --以当前音符起始位置作为索引，创建以此为索引的新表，并插入音符到该表中
    groupData[note.startPos]=note.startPos
    lastIndex=note.startPos
    table.insert(noteGroups[note.startPos],note)
    ::continue::
end

--将扫弦音符的起始位置复位
for index,notes in pairs(noteGroups) do
    if #notes==1 then goto continue end

    if notes[1].startPos==notes[2].startPos then --如果存在起始位置相同的音符，那么则按照音高排序
        table.sortByKey(notes,"pitch",true)
    else
        table.sortByKey(notes,"startPos",true) --否则按照起始位置进行排序
    end

    for i=1,#notes do
        notes[i].startPos=notes[1].startPos
        -- notes[i].endPos=notes[i].endPos
        setNote(notes[i],notes[i].sel) --将改变音高后的note重新设置
    end

    ::continue::

end

--重新扫弦
local infoGroup={}
for startPos,notes in pairs(noteGroups) do -- 遍历noteGroups表，notes
    if #notes <= 1 then goto continue end -- 如果该分组含有音符数量不大于1则不处理
    if tonumber(tick) > 0 then
        table.sortByKey(notes,"pitch",true)
        table.insert(infoGroup,table.addIncrese(notes,"pitch","startPos",tick))
    else
        table.sortByKey(notes,"pitch",false)
        table.insert(infoGroup,table.addIncrese(notes,"pitch","startPos",math.abs(tick)))
    end
    ::continue::
end

local infos={} -- 包含了每个被选中的音符起始位置应该增加的长度信息的表
for i,v in ipairs (infoGroup) do -- 将infoGroup表整合入infos表
    for k2,v2 in pairs(v) do
        infos[k2]=v2
    end
end

while table.nums(infos)>0 do -- 再次遍历选中音符，使用infos表中的信息来对音符起始位置进行改变
    for note in noteIterator() do
        local val=infos[note.pitch..","..note.startPos]
        if val==nil then goto continue end
        infos[note.pitch..","..note.startPos]=nil
        note.startPos=note.startPos+val
        setNote(note,note.sel)
        ::continue::
    end
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Strum Rebuilding", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
if (reaper.SN_FocusMIDIEditor) then reaper.SN_FocusMIDIEditor() end