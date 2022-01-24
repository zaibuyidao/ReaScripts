--[[
 * ReaScript Name: End Time (Fast)
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0 or newer recommended
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-1-2)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local function min(a,b)
    if a>b then
        return b
    end
    return a
end

local function getAllNotesQuick()
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len()
    local result = {}
    local stringPos = 1
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        if msg:len() == 3 then -- 如果 msg 包含 3 个字节
            local selected = flags&1 == 1
            local pitch = msg:byte(2)
            local status = msg:byte(1)>>4
            table.insert(result, {
                ["offset"] = offset,
                ["flags"] = flags,
                ["msg"] = msg,
                ["selected"] = selected,
                ["pitch"] = pitch,
                ["status"] = status,
            })
        end
    end
    return result
end

local function setAllEvents(events)
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab))-- 将编辑好的MIDI上传到take
end

function endTime()
    local lastPos = 0
    local pitchNotes = {}
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len()
    local stringPos = 1
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        if msg:len() == 3 then -- 如果 msg 包含 3 个字节
            local selected = flags&1 == 1
            local pitch = msg:byte(2)
            local status = msg:byte(1)>>4
            if pitchNotes[pitch] == nil then pitchNotes[pitch] = {} end
            table.insert(pitchNotes[pitch], {
                ["pos"] = lastPos + offset,
                ["flags"] = flags,
                ["msg"] = msg,
                ["selected"] = selected,
                ["pitch"] = pitch,
                ["status"] = status,
            })
            lastPos = lastPos + offset
        end
    end

    local pitchLastStart = {} -- 每个音高上一个音符的开始位置
    local events = {}
    local dur = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetCursorPositionEx(0)) -- 获取光标位置
    
    for _, es in pairs(pitchNotes) do
        for i = 1, #es do
            if not es[i].selected then
                goto continue
            end
    
            if es[i].status == 9 then
                pitchLastStart[es[i].pitch] = es[i].pos
            end
    
            if pitchLastStart[es[i].pitch] >= dur then
                goto continue
            end
            
            if es[i].status == 8 then
                if i == #es then 
                    es[i].pos = dur
                else
                    es[i].pos = min(dur, es[i+1].pos)
                end
            end
            -- Msg(tostring(es[i].pos) .. " " .. tostring(es[i].status))
            ::continue::
            table.insert(events, es[i])
        end
    end
    
    -- table.sort(events,function(a,b) -- 事件重新排序
    --     if a.pos == b.pos then
    --         if a.status == b.status then
    --             return a.pitch < b.pitch
    --         end
    --         return a.status < b.status
    --     end
    --     return a.pos < b.pos
    -- end)
    
    local lastPos = 0
    
    for _, event in pairs(events) do -- 把事件的位置转换成偏移量
        event.offset = event.pos - lastPos
        lastPos = event.pos
        -- Msg(tostring(event.offset) .. " " .. tostring(event.status))
    end
    
    setAllEvents(events)

    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDIstring)
        reaper.ShowMessageBox("腳本造成 All-Note-Off 的位置偏移\n\n已恢復原始數據", "ERROR", 0)
    end
end

function main()
    reaper.Undo_BeginBlock()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then -- 如果有item被选中
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
            if not take or not reaper.TakeIsMIDI(take) then return end
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
            if not notes_selected then return end
            endTime()
        end
    else -- 否则，判断MIDI编辑器是否被激活
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
        if not take or not reaper.TakeIsMIDI(take) then return end
        if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
        if not notes_selected then return end
        endTime()
    end

    reaper.Undo_EndBlock("End Time (Fast)", -1)
    reaper.UpdateArrange()
end

main()