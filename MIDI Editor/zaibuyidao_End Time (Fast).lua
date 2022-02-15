--[[
 * ReaScript Name: End Time (Fast)
 * Version: 1.0.3
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

function print(param)
    if type(param) == "table" then
        table.print(param)
        return
    end
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
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
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return end

sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)

local function min(a,b)
    if a>b then
        return b
    end
    return a
end

local function setAllEvents(events)
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function endTime()

    local lastPos = 0
    local pitchNotes = {}
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len()
    local stringPos = 1
    local noteOffEvent
    local events = {}
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    
        local selected = flags&1 == 1
        local pitch = msg:byte(2)
        local status = msg:byte(1)>>4
        if pitchNotes[pitch] == nil then pitchNotes[pitch] = {} end
        local e = {
            ["pos"] = lastPos + offset,
            ["flags"] = flags,
            ["msg"] = msg,
            ["selected"] = selected,
            ["pitch"] = pitch,
            ["status"] = status,
        }
        table.insert(events, e)
    
        if e.status == 8 or e.status == 9 then
            table.insert(pitchNotes[pitch], e)
        end
    
        lastPos = lastPos + offset
        
    end
    
    pitchLastStart = {}
    
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
            -- table.insert(events, es[i])
        end
    end
    
    -- table.sort(events,function(a,b) -- 事件排序
    --     if a.pos == b.pos then
    --         if a.status == b.status then
    --             return a.pitch < b.pitch
    --         end
    --         return a.status < b.status
    --     end
    --     return a.pos < b.pos
    -- end)
    
    local lastPos = 0
    for _, event in pairs(events) do
        event.pos = min(event.pos, events[#events].pos)
        event.offset = event.pos - lastPos
        lastPos = event.pos
        -- Msg("calc offset:" .. event.offset .. " " .. event.status)
    end
    
    setAllEvents(events)
    reaper.MIDI_Sort(take)
    
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
