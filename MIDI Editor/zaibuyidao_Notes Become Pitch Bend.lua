-- @description Notes Become Pitch Bend
-- @version 1.6.1
-- @author zaibuyidao
-- @changelog Optimised pitch bend
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao

range = 12

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

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= - 1 do
  cnt = cnt + 1
  index[cnt] = val
  val = reaper.MIDI_EnumSelNotes(take, val)
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

function pitchUp(o, targets)
  if #targets == 0 then error() end
  for i = 1, #targets do
    return targets[o + (range + 1)]
  end
end

function pitchDown(p, targets)
  if #targets == 0 then error() end
  for i = #targets, 1, -1 do
    return targets[p + (range + 1)]
  end
end

local pitch = {}
local startppqpos = {}
local endppqpos = {}
local vel = {}

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if #index > 1 then
  for i = 1, #index do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch[i], vel[i] = reaper.MIDI_GetNote(take, index[i])
    if selected then
      if pitch[i-1] then
        local pitchnote = (pitch[i]-pitch[1])
        local seg = getSegments(range)
        
        if pitchnote > 0 then
          pitchbend = pitchUp(pitchnote, seg)
        else
          pitchbend = pitchDown(pitchnote, seg)
        end
        
        if pitchbend == nil then return reaper.MB("Please check the note interval and limit it to one octave.\n請檢查音符間隔，並將其限制在一個八度内。", "Error", 0) end

        LSB = pitchbend & 0x7F
        MSB = (pitchbend >> 7) + 64

        reaper.MIDI_InsertCC(take, false, false, startppqpos[i], 224, 0, LSB, MSB)
      end
      if i == #index then
        j = reaper.MIDI_EnumSelNotes(take, -1)
        while j > -1 do
          reaper.MIDI_DeleteNote(take, j)
          j = reaper.MIDI_EnumSelNotes(take, -1)
        end
        if (pitch[1] ~= pitch[i]) then
          reaper.MIDI_InsertCC(take, false, false, endppqpos[i], 224, 0, 0, 64)
        end
        reaper.MIDI_InsertNote(take, selected, muted, startppqpos[1], endppqpos[i], chan, pitch[1], vel[1], true)
      end
    end
  end
else
  reaper.MB("Please select two or more notes\n請選擇兩個或更多音符","Error",0)
end

reaper.Undo_EndBlock("Notes Become Pitch Bend", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor, 40366) -- CC: Set CC lane to Pitch