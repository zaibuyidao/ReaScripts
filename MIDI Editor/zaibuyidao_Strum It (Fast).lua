--[[
 * ReaScript Name: Strum It (Fast)
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
 * v1.0 (2022-1-21)
  + Initial release
--]]

function Msg(param)
    reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

local function getAllNotesQuick()
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
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
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab)) -- 将编辑好的MIDI上传到take
end

local function getGroupPitchEvents()
    local lastPos = 0
    local pitchNotes = {}
    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
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
    return pitchNotes
end

function table.sortByKey(tab,key,ascend) -- 对于传入的table按照指定的key值进行排序,ascend参数决定是否为升序,默认为true
    direct=direct or true
    table.sort(tab,function(a,b)
        if ascend then return a[key]>b[key] end
        return a[key]<b[key]
    end)
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then notes_selected = true end
if not notes_selected then return end

sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)

local tick = reaper.GetExtState("StrumIt", "Tick")
if (tick == "") then tick = "4" end
user_ok, user_input_csv = reaper.GetUserInputs('Strum It', 1, 'How many ticks should be used to separate', tick)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
tick = user_input_csv:match("(.*)")
if not tonumber(tick) then return reaper.SN_FocusMIDIEditor() end
reaper.SetExtState("StrumIt", "Tick", tick, false)

tick = tonumber(tick)

local lastPos = 0
local events = {}

local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
local MIDIlen = MIDIstring:len()

local selectedStartEvents = {}

reaper.Undo_BeginBlock()

local stringPos = 1
while stringPos < MIDIlen do
    local offset, flags, msg
    offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
    if msg:len() == 3 then -- 如果 msg 包含 3 个字节
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
        end

        ::continue::
        lastPos = lastPos + offset
    end
end

local atick = math.abs(tick)
for _, es in pairs(selectedStartEvents) do
    table.sortByKey(es,"pitch",tick < 0)
    for i=1, #es do
        es[i].pos = es[i].pos + atick * (i-1)
    end
end

-- table.sort(events,function(a,b) -- 事件重新排序
--     -- if a.status == 11 then return false end
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

setAllEvents(events)

if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
    reaper.MIDI_SetAllEvts(take, MIDIstring)
    reaper.ShowMessageBox("腳本造成 All-Note-Off 的位置偏移\n\n已恢復原始數據", "ERROR", 0)
end

reaper.Undo_EndBlock("Strum It", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()