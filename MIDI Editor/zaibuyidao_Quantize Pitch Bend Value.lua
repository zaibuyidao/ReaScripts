-- @description Quantize Pitch Bend Value
-- @version 1.0
-- @author zaibuyidao
-- @links https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
-- @donation http://www.paypal.me/zaibuyidao
-- @about
--   # Quantize Pitch Bend Value
--   Quantize the selected pitch bend to an equal value of the pitch range

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
                        print(indent ..
                                  string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print( indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
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

function equals(a, b)
    return math.abs(a - b) < 0.0000001
end

function getSegments(n)
    local x = 8192
    local p = math.floor((x / n) + 0.5) -- 四舍五入
    local arr = {}
    local cur = 0
    for i = 1, n do
        cur = cur + p
        table.insert(arr, math.min(cur, x))
    end
    local res = {}
    for i = #arr, 1, -1 do
        table.insert(res, -arr[i])
    end
    table.insert(res, 0)
    for i = 1, #arr do
        table.insert(res, arr[i])
    end
    res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
    return res
end

function alignTo(origin, targets)
    if #targets == 0 then error() end
    if origin < targets[1] then return targets[1] end
    for i = 2, #targets do
        if equals(origin, targets[i - 1]) then return targets[i - 1] end
        if (origin < targets[i - 1]) then goto continue end
        if equals(origin, targets[i]) then return targets[i] end

        if origin > targets[i - 1] and origin < targets[i] then
            local mid = (targets[i] + targets[i-1]) / 2
            if equals(origin, mid) then
                if mid < 0 then return targets[i-1] end
                return targets[i]
            end
            if origin < mid then return targets[i-1] end
            return targets[i]
        end
        ::continue::
    end
    return targets[#targets]
end

-- a = getSegments(6)
-- table.print(a)
-- b = 4096
-- print(alignTo(b, a))
-- os.exit()

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelCC(take, -1)
while val ~= -1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
end

if #index > 0 then

    local n = reaper.GetExtState("QuantizePitchBendValue", "PitchRange")
    if (n == "") then n = "2" end

    local uok, n = reaper.GetUserInputs('Quantize Pitch Bend Value', 1, 'Pitch Range 音高範圍', n)
    
    if not uok or not tonumber(n) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("QuantizePitchBendValue", "PitchRange", n, false)
    n = tonumber(n)
    local seg = getSegments(n)

    reaper.Undo_BeginBlock()
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, index[i])
        local pitch = (MSB - 64) * 128 + LSB -- 获取 LSB（低7位）MSB（高7位）的弯音值

        -- print(LSB, MSB)
        -- print(pitch)
        -- local pitchbend = pitch + 8192

        -- print(pitch, alignTo(pitch, seg))

        pitch = alignTo(pitch, seg)
        
        LSB = pitch & 0x7F
        MSB = (pitch >> 7) + 64

        reaper.MIDI_SetCC(take, index[i], selected, muted, ppqpos, chanmsg, chan, LSB, MSB, false)
        reaper.Undo_EndBlock("Quantize Pitch Bend Value", -1)
    end
end

reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()