-- @description Strum It (Fast)
-- @version 1.0.9
-- @author zaibuyidao
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
    for _, v in ipairs({...}) do
        reaper.ShowConsoleMsg(tostring(v) .. " ")
    end
    reaper.ShowConsoleMsg("\n")
end

function getSystemLanguage()
    local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
    local os = reaper.GetOS()
    local lang
  
    if os == "Win32" or os == "Win64" then -- Windows
        if locale == 936 then -- Simplified Chinese
            lang = "简体中文"
        elseif locale == 950 then -- Traditional Chinese
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "OSX32" or os == "OSX64" then -- macOS
        local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
        if lang == "zh-CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh-TW" then -- 繁体中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    elseif os == "Linux" then -- Linux
        local handle = io.popen("echo $LANG")
        local result = handle:read("*a")
        handle:close()
        lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
        if lang == "zh_CN" then -- 简体中文
            lang = "简体中文"
        elseif lang == "zh_TW" then -- 繁體中文
            lang = "繁體中文"
        else -- English
            lang = "English"
        end
    end

    return lang
end

local language = getSystemLanguage()

if language == "简体中文" then
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁体中文" then
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
else
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
end

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
    if retval == 1 then
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
        else
            os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
        end
    end
    return
end

if not reaper.APIExists("JS_Window_Find") then
    reaper.MB(jsmsg, jstitle, 0)
    local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if ok then
        reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
        reaper.MB(err, jserr, 0)
    end
    return reaper.defer(function() end)
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

local tick = reaper.GetExtState("STRUM_IT_FAST", "Tick")
if (tick == "") then tick = "4" end
uok, uinput = reaper.GetUserInputs(title, 1, captions_csv, tick)
if not uok then return reaper.SN_FocusMIDIEditor() end
tick = uinput:match("(.*)")
if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("STRUM_IT_FAST", "Tick", tick, false)
tick = tonumber(tick)

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
    
    reaper.Undo_BeginBlock()
    
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
            local showmsg = ""
            if language == "简体中文" then
                showmsg = "音符有重叠无法解析"
            elseif language == "繁体中文" then
                showmsg = "音符有重叠無法解析"
            else
                showmsg = "Notes are overlapping and cannot be resolved."
            end
            if pitchLastStart[event.pitch] == nil then error(showmsg) end
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

    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDI)
        if language == "简体中文" then
            msgbox = "脚本造成事件位置位移，原始MIDI数据已恢复"
            errbox = "错误"
        elseif language == "繁体中文" then
            msgbox = "腳本造成事件位置位移，原始MIDI數據已恢復"
            errbox = "錯誤"
        else
            msgbox = "The script caused event position displacement, original MIDI data has been restored."
            errbox = "Error"
        end
        reaper.ShowMessageBox(msgbox, errbox, 0)
    end
    reaper.MIDI_Sort(take)
end

reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()