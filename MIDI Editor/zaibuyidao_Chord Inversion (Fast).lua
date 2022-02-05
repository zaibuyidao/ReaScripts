--[[
 * ReaScript Name: Chord Inversion (Fast)
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
 * v1.0 (2021-1-23)
  + Initial release
--]]

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function min(a,b) if a>b then return b end return a end

function getInput(title,lable,default)
    title=title or "Title"
    lable=lable or "Lable:"
    local userOK, get_value = reaper.GetUserInputs(title, 1, lable, default)
    if userOK then return get_value end
end

local function setAllEvents(events)
    -- -- 排序事件
    -- table.sort(events,function(a,b)
    --     if a.status == 11 then return false end
    --     if a.pos == b.pos then
    --         if a.status == b.status then
    --             return a.pitch < b.pitch
    --         end
    --         return a.status < b.status
    --     end
    --     return a.pos < b.pos
    -- end)
    -- local lastPos = 0
    -- for _, event in pairs(events) do
    --     event.offset = event.pos - lastPos
    --     lastPos = event.pos
    -- end

    -- 构造事件字符串数据
    local tab = {}
    for _, event in pairs(events) do
        local msg = event.msg
        if event.msg:len() == 3 then
            msg = string.pack("BBB", event.msg:byte(1), event.pitch or event.msg:byte(2), event.msg:byte(3))
        end
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, msg))
        -- Msg("build item len:" .. #item)
    end
    -- Msg("Set")
    -- Msg("events num:" .. #tab)
    -- Msg("string len:" .. #table.concat(tab))
    reaper.MIDI_SetAllEvts(take, table.concat(tab))-- 将编辑好的MIDI上传到take
end

function move(eventPairs, up)
    if up == nil then
        up = true -- 上移为true，下移为false
    end
    if #eventPairs < 2 then return end
    table.sort(eventPairs, function (a, b)
        if up then
            return a.pitch < b.pitch
        end
        return a.pitch > b.pitch
    end)
    local pitchs = {}
    local toneNum = {}
    table.insert(pitchs, eventPairs[1].pitch)
    toneNum[pitchs[1] % 12] = 1
    for i = 2, #eventPairs do
        local curPitch = eventPairs[i].pitch
        if pitchs[#pitchs] ~= curPitch then
            table.insert(pitchs, curPitch)
            if not toneNum[curPitch % 12] then 
                toneNum[curPitch % 12] = 1
            else
                toneNum[curPitch % 12] = toneNum[curPitch % 12] + 1
            end
        end
    end
    if #pitchs == 1 then return end       -- 只有一种音高则不处理

    -- for tone, num in pairs(toneNum) do
    --     Msg("tone " .. tone .. " " .. num)
    -- end

    -- for i, pitch in pairs(pitchs) do
    --     Msg("pitch " .. i .. " " .. pitch .. " tone " .. pitch % 12)
    -- end

    local overlayTone       -- 决定最后叠在顶部或底部音符的音调
    if toneNum[pitchs[1] % 12] == 1 then
        overlayTone = pitchs[1] % 12
        -- Msg("use Bottom")
    else
        local topTone = pitchs[#pitchs] % 12
        if up then
            for tone = topTone + 1, 11 do
                if toneNum[tone] then overlayTone = tone break end
            end
            if not overlayTone then
                for tone = 0, topTone do
                    if toneNum[tone] then overlayTone = tone break end
                end
            end
        else
            for tone = topTone - 1, 0, -1 do
                if toneNum[tone] then overlayTone = tone break end
            end
            if not overlayTone then
                for tone = 11, topTone, -1 do
                    if toneNum[tone] then overlayTone = tone break end
                end
            end
        end
    end

    local topPitch=pitchs[#pitchs]
    local overlayPitch = overlayTone

    if up then
        repeat overlayPitch = overlayPitch + 12 until overlayPitch > topPitch --重复将被叠加的音符的音高+12，直到这个音高比原来顶部的音高要大
        if overlayPitch > 127 then return end --如果将被叠加的音高大于127，则直接返回，不再继续进行处理
    else 
        overlayPitch = overlayPitch + 132
        repeat overlayPitch = overlayPitch - 12 until overlayPitch < topPitch --重复将被叠加的音符的音高+12，直到这个音高比原来顶部的音高要大
        if overlayPitch < 0 then return end --如果将被叠加的音高小于0，则直接返回，不再继续进行处理
    end

    local newPitch = {}
    newPitch[topPitch] = overlayPitch
    for i = 1, #pitchs - 1 do
        newPitch[pitchs[i]] = pitchs[i+1]
    end

    for i, eventPair in ipairs(eventPairs) do
        local p = newPitch[eventPair.pitch]
        eventPair.first.pitch = p
        eventPair.second.pitch = p
        if eventPair.articulation then
            eventPair.articulation.msg = eventPair.articulation.msg:gsub("(NOTE %d+ )(%d+)", "%1" .. p)
        end
    end
end

function chordInversion()
    local times = reaper.GetExtState("ChordInversion", "Times")
    if (times == "") then times = "1" end
    times = getInput("Chord Inversion", "Times", times) --获得翻转次数
    if times == nil then return end
    reaper.SetExtState("ChordInversion", "Times", times, false)
    times = tonumber(times) --将文本型的次数转换为整数型的次数
    if times == nil then return end

    local flag = true --是否上翻
    if times < 0 then  --如果次数小于0则下翻
        flag = false
        times = -times
    end
    
    for i = 1, tonumber(times) do
        local events = {}
        local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
        -- Msg("Get")
        -- Msg("string len:" .. #MIDIstring)
        local groupEventPairs = {} -- {开始事件，结束事件} = groupEventPairs[组位置][i]
        local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
        local articulationEventAtPitch = {}
        local stringPos = 1
        local lastPos = 0
        while stringPos <= MIDIstring:len() do
            local offset, flags, msg
            offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        
            -- Msg("msg_len:" .. msg:len() .. " flags:" .. flags .. " offset:" .. offset .. " stringPos:" .. stringPos .. " pitch:" .. msg:byte(2) .. " status:"  .. (msg:byte(1)>>4))
            -- if (msg:len()~=3) then
            --     Msg(msg)
            --     local t = {}
            --     for i=1,msg:len() do
            --         table.insert(t, "[" .. i .. ":" .. msg:byte(i) .. "]")
            --     end
            --     Msg(table.concat(t, " "))
            --     local chan, pitch = msg:match("NOTE (%d+) (%d+) ")
            --     Msg(pitch)
            -- end
        
            local event = {
                offset = offset,
                pos = lastPos + offset,
                flags = flags,
                msg = msg,
                selected = flags&1 == 1,
                status = msg:byte(1)>>4,
            }
            if msg:len() == 3 then
                event.pitch = msg:byte(2)
            end
            table.insert(events, event)
        
            if event.status == EVENT_NOTE_START then
                noteStartEventAtPitch[event.pitch] = event
            elseif event.status == EVENT_NOTE_END then
                local start = noteStartEventAtPitch[event.pitch]
                local groupPos = reaper.MIDI_GetPPQPos_StartOfMeasure(take, start.pos)
                if not groupEventPairs[groupPos] then groupEventPairs[groupPos] = {} end
                if event.selected then
                    table.insert(groupEventPairs[groupPos], {
                        first = start, 
                        second = event,
                        articulation = articulationEventAtPitch[event.pitch],
                        pitch = start.pitch
                    })
                end
                noteStartEventAtPitch[event.pitch] = nil
                articulationEventAtPitch[event.pitch] = nil
            elseif event.status == EVENT_ARTICULATION then
                local chan, pitch = msg:match("NOTE (%d+) (%d+) ")
                articulationEventAtPitch[tonumber(pitch)] = event
            end
        
            ::continue::
            lastPos = lastPos + offset
        end
        
        -- Msg("events num:" .. #events)
        
        for groupPos, eventPairs in pairs(groupEventPairs) do
            move(eventPairs, flag)
        end
        
        setAllEvents(events)
    
        if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
            reaper.MIDI_SetAllEvts(take, MIDIstring)
            reaper.ShowMessageBox("腳本造成 All-Notes-Off 的位置偏移\n\n已恢複原始數據", "ERROR", 0)
        end
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
            chordInversion()
        end
    else -- 否则，判断MIDI编辑器是否被激活
        take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
        sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
        if not take or not reaper.TakeIsMIDI(take) then return end
        if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
        if not notes_selected then return end
        chordInversion()
    end

    reaper.Undo_EndBlock("Chord Inversion (Fast)", -1)
    reaper.UpdateArrange()
    reaper.SN_FocusMIDIEditor()
end

main()