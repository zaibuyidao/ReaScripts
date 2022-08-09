-- @description Move Pitch Bend One Semitone
-- @version 1.0
-- @author zaibuyidao
-- @links https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
-- @donation http://www.paypal.me/zaibuyidao
-- @about
--   # Move Pitch Bend One Semitone
--   Move Pitch Bend One Semitone:
--   * Move the bend up one semitone
--   * move the bend down one semitone

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

function moveUp(origin, targets)
    if #targets == 0 then error() end
    for i = 1, #targets do
        if (not equals(origin, targets[i])) and targets[i] > origin then
            return targets[i]
        end
    end
    return targets[#targets]
end

function moveDown(origin, targets)
    if #targets == 0 then error() end
    for i = #targets, 1, -1 do
        if (not equals(origin, targets[i])) and targets[i] < origin then
            return targets[i]
        end
    end
    return targets[1]
end

-- a = getSegments(6)
-- table.print(a)
-- b = 4096
-- print(alignTo(b, a))
-- print(moveUp(b, a))
-- print(moveDown(b, a))
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
    n = reaper.GetExtState("MovePitchBendOneSemitone", "PitchRange")
    if (n == "") then n = "12" end
    toggle = reaper.GetExtState("MovePitchBendOneSemitone", "Toggle")
    if (toggle == "") then toggle = "0" end

    local uok, uinput = reaper.GetUserInputs('Move Pitch Bend One Semitone', 2, 'Pitch Range 音高範圍,0=Up 上移 1=Down 下移', n ..','.. toggle)
    n, toggle = uinput:match("(.*),(.*)")

    if not uok or not tonumber(n) or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("MovePitchBendOneSemitone", "PitchRange", n, false)
    reaper.SetExtState("MovePitchBendOneSemitone", "Toggle", toggle, false)

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

        if toggle == "0" then
            pitch = moveUp(pitch, seg)
        elseif toggle == "1" then
            pitch = moveDown(pitch, seg)
        end
        
        LSB = pitch & 0x7F
        MSB = (pitch >> 7) + 64
        
        reaper.MIDI_SetCC(take, index[i], selected, muted, ppqpos, chanmsg, chan, LSB, MSB, false)
    end
    reaper.Undo_EndBlock("Move Pitch Bend One Semitone", -1)
end

reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()