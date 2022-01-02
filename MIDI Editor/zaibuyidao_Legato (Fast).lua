--[[
 * ReaScript Name: Legato (Fast)
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
 * v1.0 (2022-1-2)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
if not notes_selected then return end

local function getAllNotesQuick(tail)
    tail = tail or 12
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len() - tail
    local result = {}
    local stringPos = 1
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        if msg:len() == 3 then -- 如果msg包含3个字节
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
    return result, MIDIstring:sub(-tail)
end

local function setAllEvents(events, tail)
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    table.insert(tab, tail)
    reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

local function getGroupPitchEvents(tail)
    local lastPos = 0
    local pitchNotes = {}
    tail = tail or 12
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len() - tail
    local stringPos = 1
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        if msg:len() == 3 then -- 如果msg包含3个字节
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
    return pitchNotes, MIDIstring:sub(-tail)
end

function legato()
    local lastPos = 0
    local events = {}
    local tail = tail or 12
    local pitchLastStart = {} -- 每个音高上一个音符的开始位置
    local startPoss = {}
    local startPosIndex = {}
    local endEvents = {}
    
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    local MIDIlen = MIDIstring:len() - tail
    local tails = MIDIstring:sub(-tail)
    local stringPos = 1
    
    while stringPos < MIDIlen do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        if msg:len() == 3 then -- 如果msg包含3个字节
            local selected = flags&1 == 1
            local pitch = msg:byte(2)
            local status = msg:byte(1)>>4
            local event = {
                ["pos"] = lastPos + offset,
                ["flags"] = flags,
                ["msg"] = msg,
                ["selected"] = selected,
                ["pitch"] = pitch,
                ["status"] = status,
            }
            table.insert(events, event)
    
            if not event.selected then
                goto continue
            end
    
            if event.status == 9 then
    
                -- 遍历到了一个新的开始事件位置
                if #startPoss == 0 or event.pos > startPoss[#startPoss] then
                    -- 记录开始位置
                    table.insert(startPoss, event.pos)  
                    startPosIndex[event.pos] = #startPoss
                    
                    -- 对缓存的结束事件赋值
                    for _, endEvent in pairs(endEvents) do
                        endEvent.pos = event.pos
                    end
                    endEvents = {}
                end
    
                pitchLastStart[event.pitch] = event.pos
            elseif event.status == 8 then
                local startPosindex = startPosIndex[pitchLastStart[event.pitch]] -- 当前结束事件对应的音符的开始位置索引值
                if startPosindex ~= #startPoss then
                    event.pos = startPoss[startPosindex + 1]
                else
                    -- 加入缓存，等待新的开始事件出现
                    table.insert(endEvents, event)
                end
            end
    
            ::continue::
            lastPos = lastPos + offset
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
    end
    
    setAllEvents(events, tails)
end

function main()
    reaper.Undo_BeginBlock()
    count_sel_items = reaper.CountSelectedMediaItems(0)
    if count_sel_items > 0 then -- 如果有item被选中
        for i = 1, count_sel_items do
            item = reaper.GetSelectedMediaItem(0, i - 1)
            take = reaper.GetTake(item, 0)
            legato()
        end
    else -- 否则，判断MIDI编辑器是否被激活
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        if take == nil then return end
        legato()
    end

    reaper.Undo_EndBlock("Legato (Fast)", -1)
    reaper.UpdateArrange()
end

main()