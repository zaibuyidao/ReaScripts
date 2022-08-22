-- @description Strum It (Fast)
-- @version 1.0.7
-- @author zaibuyidao
-- @changelog Optimised articulation
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

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

function Open_URL(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
        os.execute("open ".. url)
    else
        os.execute("start ".. url)
    end
end

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        Open_URL("http://www.sws-extension.org/download/pre-release/")
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
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tTake[take] = nil end -- Remove takes that were not affected by deselection
        end
    end
    if not next(tTake) then return end
    return tTake
end

function table.sortByKey(tab,key,ascend) -- 对于传入的table按照指定的key值进行排序,ascend参数决定是否为升序,默认为true
    direct=direct or true
    table.sort(tab,function(a,b)
        if ascend then return a[key]>b[key] end
        return a[key]<b[key]
    end)
end

local function setAllEvents(take, events)
    local lastPos = 0
    for _, event in pairs(events) do -- 把事件的位置转换成偏移量
        event.offset = event.pos - lastPos
        lastPos = event.pos
    end

    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

local tick = reaper.GetExtState("StrumItFast", "Tick")
if (tick == "") then tick = "4" end
uok, uinput = reaper.GetUserInputs('Strum It (Fast)', 1, 'Enter A Tick (±)', tick)
if not uok then return reaper.SN_FocusMIDIEditor() end
tick = uinput:match("(.*)")
if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("StrumItFast", "Tick", tick, false)
tick = tonumber(tick)

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    local articulationMap = {}
    local function markArticulation(pos, pitch, articulationEvent)
        if not articulationMap[pos] then
            articulationMap[pos] = {}
        end
        articulationMap[pos][pitch] = articulationEvent
    end
    local function findArticulation(pos, pitch)
        local tmp = articulationMap[pos]
        if not tmp then
            return nil
        end
        return tmp[pitch]
    end

    local sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    local lastPos = 0
    local events = {}
    
    local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
    local selectedStartEvents = {}
    local pitchLastStart = {}
    
    local stringPos = 1
    while stringPos < MIDI:len() do
        local offset, flags, msg
        offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDI, stringPos)
    
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
    
        if event.status == 15 then
            if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
                -- text event
            elseif event.msg:find("articulation") then
                local chan, pitch = msg:match("NOTE (%d+) (%d+) ")
                markArticulation(event.pos, tonumber(pitch), event)
            end
        end

        if not event.selected then
            goto continue
        end

        if event.status == 9 then
            if selectedStartEvents[event.pos] == nil then selectedStartEvents[event.pos] = {} end
            table.insert(selectedStartEvents[event.pos], event)

            pitchLastStart[event.pitch] = event.pos
        elseif event.status == 8 then
            if pitchLastStart[event.pitch] == nil then error("音符有重叠無法解析") end
            pitchLastStart[event.pitch] = nil
        end
    
        ::continue::
        lastPos = lastPos + offset
    end
    
    local atick = math.abs(tick)
    for _, es in pairs(selectedStartEvents) do
        table.sortByKey(es,"pitch",tick < 0)
        for i=1, #es do
            local articulation = findArticulation(es[i].pos, es[i].pitch)
            es[i].pos = es[i].pos + atick * (i-1)
            if articulation then
                articulation.pos = es[i].pos
            end
        end
    end
    
    -- local last = events[#events]
    -- table.remove(events, #events)
    -- table.sort(events,function(a,b) -- 事件重新排序
    --   -- if a.status == 11 then return false end
    --   if a.pos == b.pos then
    --     if a.status == b.status then
    --         return a.pitch < b.pitch
    --     end
    --     return a.status < b.status
    --   end
    --   return a.pos < b.pos
    -- end)
    -- table.insert(events, last)
    
    setAllEvents(take, events)
    reaper.MIDI_Sort(take)
    
    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDI)
        reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
    end
end

reaper.Undo_EndBlock("Strum It (Fast)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()