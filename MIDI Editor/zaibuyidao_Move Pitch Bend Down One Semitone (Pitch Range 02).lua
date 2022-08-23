-- @description Move Pitch Bend Down One Semitone (Pitch Range 02)
-- @version 1.0.1
-- @author zaibuyidao
-- @links https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
-- @donation http://www.paypal.me/zaibuyidao
-- @about
--   # Move Pitch Bend Down One Semitone (Pitch Range 02)

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

    n = 2

    local seg = getSegments(n)

    reaper.Undo_BeginBlock()
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, index[i])
        local pitch = (MSB - 64) * 128 + LSB -- 获取 LSB（低7位）MSB（高7位）的弯音值

        --pitch = moveUp(pitch, seg) -- 向上
        pitch = moveDown(pitch, seg) -- 向下

        LSB = pitch & 0x7F
        MSB = (pitch >> 7) + 64
        
        reaper.MIDI_SetCC(take, index[i], selected, muted, ppqpos, chanmsg, chan, LSB, MSB, false)
    end
    reaper.Undo_EndBlock("Move Pitch Bend Down One Semitone (Pitch Range 02)", -1)
end

reaper.UpdateArrange()