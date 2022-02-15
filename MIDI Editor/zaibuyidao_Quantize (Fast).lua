--[[
 * ReaScript Name: Quantize (Fast)
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
 * v1.0 (2021-2-15)
  + Initial release
--]]

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local midiEditor = reaper.MIDIEditor_GetActive()
take = reaper.MIDIEditor_GetTake(midiEditor)
if not take or not reaper.TakeIsMIDI(take) then return end

sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)

function setAllEvents(events)
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
    local lastPos = 0
    for _, event in pairs(events) do
        event.offset = event.pos - lastPos
        lastPos = event.pos
    end

    -- 构造事件字符串数据
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab))
end

function min(a,b) if a>b then return b end return a end
function getEventPitch(event) return event.msg:byte(2) end
function getEventSelected(event) return event.flags&1 == 1 end
function getEventType(event) return event.msg:byte(1)>>4 end
function getArticulationInfo(event) return event.msg:match("NOTE (%d+) (%d+) ") end
function setEventPitch(event, pitch) event.msg = string.pack("BBB", event.msg:byte(1), pitch or event.msg:byte(2), event.msg:byte(3)) end

reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40659)

local events = {}
local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")

local noteEvents = {}
local ccEvents = {}
local textEvents = {}

local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
local articulationEventAtPitch = {}

local stringPos = 1
local lastPos = 0
while stringPos <= MIDIstring:len() do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    local event = { offset = offset, pos = lastPos + offset, flags = flags, msg = msg }
    table.insert(events, event)

    local eventType = getEventType(event)
    local eventPitch = getEventPitch(event)

    -- Msg("type:" .. eventType .. " flags:" .. flags .. " offset:" .. offset .. " msg:" .. table.concat(table.pack(string.byte(msg, 1, #msg)), " "))

    if eventType == EVENT_NOTE_START then
        noteStartEventAtPitch[eventPitch] = event
    elseif eventType == EVENT_NOTE_END then
        local start = noteStartEventAtPitch[eventPitch]
        table.insert(noteEvents, {
            first = start,
            second = event,
            articulation = articulationEventAtPitch[eventPitch],
            pitch = getEventPitch(start)
        })
        noteStartEventAtPitch[eventPitch] = nil
        articulationEventAtPitch[eventPitch] = nil
    elseif eventType == EVENT_ARTICULATION then
        if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
            table.insert(textEvents, event)
        else
            local chan, pitch = getArticulationInfo(event)
            articulationEventAtPitch[tonumber(pitch)] = event
        end
    elseif eventType == 11 then
        if event.msg:byte(2) >= 0 and event.msg:byte(2) <= 127 then
            table.insert(ccEvents, event)
        end
    end
    lastPos = lastPos + offset
end

setAllEvents(events)

local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local gird, swing = reaper.MIDI_GetGrid(take)

if swing == 0 then
    gird = reaper.GetExtState("Quantize", "Grid")
    if (gird == "") then gird = "240" end
    local toggle = reaper.GetExtState("Quantize", "Toggle")
    if (toggle == "") then toggle = "0" end
    local user_ok, input_cav = reaper.GetUserInputs('Quantize', 2, 'Enter A Tick,0=Default 1=Start 2=End 3=Pos', gird ..','.. toggle)
    gird, toggle = input_cav:match("(.*),(.*)")
    if not user_ok or not tonumber(gird) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("Quantize", "Grid", gird, false)
    reaper.SetExtState("Quantize", "Toggle", toggle, false)
    -- Msg("gird:" .. gird .. " tick:" .. tick .. " cur_gird:" .. cur_gird .. "")
    gird = gird / tick
else
    local toggle = reaper.GetExtState("Quantize", "Toggle")
    if (toggle == "") then toggle = "0" end
    local user_ok, input_cav = reaper.GetUserInputs('Quantize', 1, 'Enter A Tick,0=Default 1=Start 2=End 3=Pos', toggle)
    toggle = input_cav
    if not user_ok or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("Quantize", "Toggle", toggle, false)
end

-- 将position对齐到refs里的beat位置
-- refs是一个小节内由网格线和swing线的beat位置组成的列表
-- minpos 不允许对齐后的位置小于minpos
-- maxpos 不允许对齐后的位置大于maxpos
function align(position, refs, minpos, maxpos)
    minpos = minpos or -0xffff
    maxpos = maxpos or 0xffff
    local bp = position % 4 -- 在一个小节内的位置
    local s = position - bp
    local anspos
    for i = 2, #refs do
        if refs[i-1] > refs[i] then error("Illegal refs") end
        if bp >= refs[i-1] and bp <= refs[i] then
            local mid = refs[i-1] + (refs[i] - refs[i-1]) / 2
            if bp <= mid then
                anspos = i - 1
                break
            else
                anspos = i
                break
            end
        end
    end
    if not anspos then
        error("Error in aling position:" .. position .. " to " .. table.concat(refs, " "))
    end
    
    local function check_min()
        return refs[anspos] + s > minpos + 0.01
    end

    local function check_max()
        return refs[anspos] + s < maxpos - 0.01
    end

    if not check_min() then
        repeat
            anspos = anspos + 1
        until check_min()
    elseif not check_max() then
        repeat
            anspos = anspos - 1
        until check_max()
    end
    return refs[anspos] + s
end

-- 生成refs列表
-- align_gird 用户自定义的网格线beat单位大小
-- swing 窗口底部显示的swing百分比值
-- view_gird 窗口底部显示的gird值乘以4，即网格线占用的beat单位大小
function get_refs(align_gird, swing, view_gird)
    view_gird = view_gird or align_gird
    local result = {}
    local cur = 0
    -- 网格线
    while cur <= 5 do
        table.insert(result, cur)
        cur = cur + align_gird * 2
    end
    -- swing线或网格线
    local swing_offset_beat = view_gird / 2 * swing
    local cur_swing = view_gird + swing_offset_beat
    while cur_swing <= 5 do
        table.insert(result, cur_swing)
        cur_swing = cur_swing + view_gird * 2
    end
    table.sort(result)
    return result
end

function StartTimes() -- 只量化音符的起始位置
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            -- Msg("startppqpos:" .. startppqpos .. " endppqpos:" .. endppqpos)
            -- Msg("start_note_qn:" .. start_note_qn .. " end_note_qn:" .. end_note_qn)
            -- Msg("beats_01:" .. beats_01 .. " start_cdenom:" .. start_cdenom)
            -- Msg("beats_02:" .. beats_02 .. " end_cdenom:" .. end_cdenom)
            out_beatpos = align(start_cdenom, get_refs(gird, swing), nil, nil)
            -- Msg("aling start " .. start_cdenom .. " to " .. table.concat(get_refs(gird, swing, gird), " ") .. " is " .. out_beatpos)
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            noteEvents[i].first.pos = out_ppq
        end
    end
end

function EndTimes() -- 只量化音符结束位置
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            out_beatpos = align(end_cdenom, get_refs(gird, swing), start_cdenom, nil)
            -- Msg("start_cdenom:" .. start_cdenom)
            -- Msg("aling end " .. end_cdenom .. " to " .. table.concat(get_refs(gird, swing, gird), " ") .. " is " .. out_beatpos)
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            noteEvents[i].second.pos = out_ppq
        end
    end
end

function Position() -- 只移动音符的起始位置
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local beats_02, _, _, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos
            out_beatpos = align(start_cdenom, get_refs(gird, swing), nil, nil)
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            endppqpos = endppqpos - (startppqpos - out_ppq)
            noteEvents[i].first.pos = out_ppq
            noteEvents[i].second.pos = endppqpos
        end
    end
end

function CCEvents() -- 仅量化CC位置，只在默认使用
    for i = 1, #ccEvents do
        local selected = getEventSelected(ccEvents[i])
        local ppqpos = ccEvents[i].pos
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            out_beatpos = align(start_cdenom, get_refs(gird, swing))
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            ccEvents[i].pos = out_ppq
        end
    end
end

function TextEvents() -- 量化文本事件，只在默认使用
    for i = 1, #textEvents do
        local selected = getEventSelected(textEvents[i])
        local ppqpos = textEvents[i].pos
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local beats_01, _, _, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            out_beatpos = align(start_cdenom, get_refs(gird, swing))
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            textEvents[i].pos = out_ppq
        end
    end
end

reaper.Undo_BeginBlock()

if toggle == "3" then
    Position() -- 只移动音符的起始位置
elseif toggle == "2" then
    EndTimes() -- 结束位置量化，仅音符
elseif toggle == "1" then
    StartTimes() -- 起始位置量化，仅音符
elseif toggle == "0" then
    StartTimes() -- 默认起始位置量化，仅音符
    EndTimes() -- 默认结束位置量化，仅音符
    CCEvents() -- 默认量化CC事件
    TextEvents() -- 默认量化文本事件
end

setAllEvents(events)

if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("脚本造成了all-note-off的转移\n\n已恢复原始数据", "ERROR", 0)
end

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("SWS extension is required by this script.\n此腳本需要 SWS 擴展。\nHowever, it doesn't seem to be present for this REAPER installation.\n然而，對於這個REAPER安裝來說，它似乎並不存在。\n\nDo you want to download it now ?\n你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
      Open_URL("http://www.sws-extension.org/download/pre-release/")
    end
    return
end

reaper.Undo_EndBlock("Quantize (Fast)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
