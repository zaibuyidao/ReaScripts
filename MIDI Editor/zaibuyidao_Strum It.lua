-- @description Strum It
-- @version 1.3.1
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive()) -- 全局take值
if not take or not reaper.TakeIsMIDI(take) then return end

function table.sortByKey(tab,key,ascend) -- 对于传入的table按照指定的key值进行排序,ascend参数决定是否为升序,默认为true
    direct=direct or true
    table.sort(tab,function(a,b)
        if ascend then return a[key]>b[key] end
        return a[key]<b[key]
    end)
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

function countEvts() -- 获取选中音符数量
    local _, notecnt, _, _ = reaper.MIDI_CountEvts(take)
    return notecnt
end

function getNote(sel) -- 根据传入的sel索引值，返回指定位置的含有音符信息的表
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

function getSelIndexs() -- 获取全部被选中音符的索引值
    local sel=-1
    local ret={}
    repeat
        sel = reaper.MIDI_EnumSelNotes(take, sel)
        local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, sel)
        table.insert(ret,sel)
    until sel == -1
    return ret
end

function setNote(note,sel,arg) -- 传入一个音符信息表已经索引值，对指定索引位置的音符信息进行修改
    reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end

function noteIterator() -- 迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end

local title, captions_csv = "", ""
if language == "简体中文" then
    title = "扫弦"
    captions_csv = "输入滴答数(±):"
elseif language == "繁体中文" then
    title = "掃弦"
    captions_csv = "輸入嘀答數(±):"
else
    title = "Strum It"
    captions_csv = "Enter A Tick (±):"
end

tick = reaper.GetExtState("STRUM_IT", "Tick")
if (tick == "") then tick = "4" end
uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, tick)
if not uok then return reaper.SN_FocusMIDIEditor() end
tick = uinput:match("(.*)")
if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("STRUM_IT", "Tick", tick, false)
if countEvts()==0 then return end

reaper.Undo_BeginBlock()
reaper.MIDI_DisableSort(take)
local noteGroups={} -- 按照startPos进行分组储存note的表
for note in noteIterator() do -- 遍历选中音符，并对noteGroups表赋值
    if noteGroups[note.startPos]==nil then noteGroups[note.startPos]={} end
    table.insert(noteGroups[note.startPos],note)
end

local infoGroup={}
for startPos, notes in pairs(noteGroups) do -- 遍历noteGroups表，notes
    if #notes <= 1 then goto continue end -- 如果该分组含有音符数量不大于1则不处理
    if tonumber(tick) > 0 then
        table.sortByKey(notes,"pitch",false)
        table.insert(infoGroup,table.addIncrese(notes,"pitch","startPos",tick))
    else
        table.sortByKey(notes,"pitch",true)
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
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()