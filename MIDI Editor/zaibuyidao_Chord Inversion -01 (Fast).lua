-- @description Chord Inversion -01 (Fast)
-- @version 1.0.5
-- @author zaibuyidao
-- @changelog Optimised articulation
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
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
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
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

function getAllTakes()
    tTake = {}
    if reaper.MIDIEditor_EnumTakes then
      local editor = reaper.MIDIEditor_GetActive()
      for i = 0, math.huge do
          take = reaper.MIDIEditor_EnumTakes(editor, i, false)
          if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
            tTake[take] = true
            tTake[take] = {item = reaper.GetMediaItemTake_Item(take)}
          else
              break
          end
      end
    else
      for i = 0, reaper.CountMediaItems(0)-1 do
        local item = reaper.GetMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
          tTake[take] = true
        end
      end
    
      for take in next, tTake do
        if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tTake[take] = nil end
      end
    end
    if not next(tTake) then return end
    return tTake
end

function Open_URL(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
        os.execute("open ".. url)
    else
        os.execute("start ".. url)
    end
end

if not reaper.BR_GetMidiSourceLenPPQ then
    local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
end

function min(a,b) if a>b then return b end return a end

local function setAllEvents(take, events)
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

function getEventPitch(event) return event.msg:byte(2) end
function getEventSelected(event) return event.flags&1 == 1 end
function getEventType(event) return event.msg:byte(1)>>4 end
function getArticulationInfo(event) return event.msg:match("NOTE (%d+) (%d+) ") end
function setEventPitch(event, pitch) event.msg = string.pack("BBB", event.msg:byte(1), pitch or event.msg:byte(2), event.msg:byte(3)) end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
    if not notes_selected then return end

    local events = {}
    local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
    -- print("Get")
    -- print("string len:" .. #MIDIstring)
    local groupEventPairs = {} -- {开始事件，结束事件} = groupEventPairs[组位置][i]
    local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
    local articulationEventAtPitch = {}
    local stringPos = 1
    local lastPos = 0
    while stringPos <= MIDIstring:len() do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
        local event = {
            offset = offset,
            pos = lastPos + offset,
            flags = flags,
            msg = msg,
        }
        table.insert(events, event)
    
        local status = getEventType(event)
        if status == EVENT_NOTE_START then
            noteStartEventAtPitch[getEventPitch(event)] = event
        elseif status == EVENT_NOTE_END then
            local start = noteStartEventAtPitch[getEventPitch(event)]
            if start == nil then error("音符有重叠無法解析") end
            local groupPos = reaper.MIDI_GetPPQPos_StartOfMeasure(take, start.pos)
            if not groupEventPairs[groupPos] then groupEventPairs[groupPos] = {} end
            if getEventSelected(event) then
                table.insert(groupEventPairs[groupPos], {
                    first = start, 
                    second = event,
                    articulation = articulationEventAtPitch[getEventPitch(event)],
                    pitch = getEventPitch(start)
                })
            end
            noteStartEventAtPitch[getEventPitch(event)] = nil
            articulationEventAtPitch[getEventPitch(event)] = nil
        elseif status == EVENT_ARTICULATION then
            if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
                -- text event
            elseif event.msg:find("articulation") then
                local chan, pitch = msg:match("NOTE (%d+) (%d+) ")
                articulationEventAtPitch[tonumber(pitch)] = event
            end
        end
    
        ::continue::
        lastPos = lastPos + offset
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
        if #pitchs == 1 then return end -- 只有一种音高则不处理
    
        -- for tone, num in pairs(toneNum) do
        --     print("tone " .. tone .. " " .. num)
        -- end
    
        -- for i, pitch in pairs(pitchs) do
        --     print("pitch " .. i .. " " .. pitch .. " tone " .. pitch % 12)
        -- end
    
        local overlayTone -- 决定最后叠在顶部或底部音符的音调
        if toneNum[pitchs[1] % 12] == 1 then
            overlayTone = pitchs[1] % 12
            -- print("use Bottom")
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
            repeat overlayPitch = overlayPitch + 12 until overlayPitch > topPitch -- 重复将被叠加的音符的音高+12，直到这个音高比原来顶部的音高要大
            if overlayPitch > 127 then return end -- 如果将被叠加的音高大于127，则直接返回，不再继续进行处理
        else 
            overlayPitch = overlayPitch + 132
            repeat overlayPitch = overlayPitch - 12 until overlayPitch < topPitch --重复将被叠加的音符的音高+12，直到这个音高比原来顶部的音高要大
            if overlayPitch < 0 then return end -- 如果将被叠加的音高小于0，则直接返回，不再继续进行处理
        end
    
        local newPitch = {}
        newPitch[topPitch] = overlayPitch
        for i = 1, #pitchs - 1 do
            newPitch[pitchs[i]] = pitchs[i+1]
        end
    
        for i, eventPair in ipairs(eventPairs) do
            local p = newPitch[eventPair.pitch]
            setEventPitch(eventPair.first, p)
            setEventPitch(eventPair.second, p)
            if eventPair.articulation then
                eventPair.articulation.msg = eventPair.articulation.msg:gsub("(NOTE %d+ )(%d+)", "%1" .. p)
            end
        end
    end
    
    for groupPos, eventPairs in pairs(groupEventPairs) do
        move(eventPairs, false)
    end
    
    setAllEvents(take, events)
    
    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDIstring)
        reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
    end
end
reaper.Undo_EndBlock("Chord Inversion -01 (Fast)", -1)
reaper.UpdateArrange()