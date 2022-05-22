--[[
 * ReaScript Name: Strum It (Fast)
 * Version: 1.0.4
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2022-1-21)
  + Initial release
--]]

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

function open_url(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
        os.execute("open ".. url)
    else
        os.execute("start ".. url)
    end
end

if not reaper.BR_GetMidiSourceLenPPQ then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
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
user_ok, user_input_csv = reaper.GetUserInputs('Strum It (Fast)', 1, 'Enter A Tick (±)', tick)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
tick = user_input_csv:match("(.*)")
if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("StrumItFast", "Tick", tick, false)
tick = tonumber(tick)

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
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
            es[i].pos = es[i].pos + atick * (i-1)
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