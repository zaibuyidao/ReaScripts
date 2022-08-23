-- @description Insert Pitch Bend Curve (Triangle)
-- @version 1.0
-- @author zaibuyidao
-- @changelog Initial release
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

function open_url(url)
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
    open_url("http://www.sws-extension.org/download/pre-release/")
  end
end

local _SN_FocusMIDIEditor = reaper.SN_FocusMIDIEditor
reaper.SN_FocusMIDIEditor = function(...) if _SN_FocusMIDIEditor then _SN_FocusMIDIEditor(...) end end

function get_cur_sine1(bottom, top, num) -- 正弦曲线版本
  local scale = math.abs(top-bottom) / 2
  local step_length = math.pi * 2 / num
  local result = {}
  local cur = -math.pi
  local revert = 1
  if (top < bottom) then revert = -1 end
  local offset = bottom + scale
  if (top < bottom) then offset = bottom - scale end
  for i=1,num do
    table.insert(result, math.floor(math.cos(cur) * scale * revert + offset + 0.5))
    cur = cur + step_length
  end
  return result
end

function get_cur_sine2(bottom, top, num) -- 正弦曲线间隙版本
  local scale = math.abs(top-bottom) / 2
  local step_length = math.pi * 2 / (num -2)
  local result = {}
  local cur = -math.pi
  local revert = 1
  if (top < bottom) then revert = -1 end
  local offset = bottom + scale
  if (top < bottom) then offset = bottom - scale end
  for i=1,num/2 do
    table.insert(result, math.floor(math.cos(cur) * scale * revert + offset + 0.5))
    cur = cur + step_length
  end

  -- 复制对称点
  local s = #result
  for i=s,1,-1 do
    table.insert(result,result[i])
  end

  return result
end

function get_cur_triangle(bottom, top, num) -- 三角波曲线版本
  local result = {}
  local step = (top - bottom) / (num / 2)
  local cur = bottom
  for i = 1, num/2 do
    table.insert(result,  math.floor(cur))
    cur = cur + step
  end
  for i = 1, num/2 do
    table.insert(result, math.floor(cur))
    cur = cur - step
  end
  return result
end

get_curve = get_cur_triangle

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local bottom = reaper.GetExtState("InsertPitchBendCurveTriangle", "Bottom")
  if (bottom == "") then bottom = "0" end
  local top = reaper.GetExtState("InsertPitchBendCurveTriangle", "Top")
  if (top == "") then top = "1024" end
  local times = reaper.GetExtState("InsertPitchBendCurveTriangle", "Times") 
  if (times == "") then times = "16" end
  local length = reaper.GetExtState("InsertPitchBendCurveTriangle", "Length")
  if (length == "") then length = "240" end
  local num = reaper.GetExtState("InsertPitchBendCurveTriangle", "Num")
  if (num == "") then num = "12" end

  local user_ok, user_input_CSV = reaper.GetUserInputs("Insert Pitch Bend Curve (Triangle)", 5, "Starting value 起始點,Highest value 最高點,Repetitions 重複,Length 長度,Points 點數", bottom ..','.. top ..','.. times .. "," .. length .. "," .. num)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = user_input_CSV:match("(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(bottom) or not tonumber(top) or not tonumber(times) or not tonumber(length) or not tonumber(num) then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = tonumber(bottom), tonumber(top), tonumber(times), tonumber(length), tonumber(num)
  if times < 1 then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("InsertPitchBendCurveTriangle", "Bottom", bottom, false)
  reaper.SetExtState("InsertPitchBendCurveTriangle", "Top", top, false)
  reaper.SetExtState("InsertPitchBendCurveTriangle", "Times", times, false)
  reaper.SetExtState("InsertPitchBendCurveTriangle", "Length", length, false)
  reaper.SetExtState("InsertPitchBendCurveTriangle", "Num", num, false)
  
  local step_length = length / num

  local cur_pos = reaper.GetCursorPositionEx() -- 获取光标位置
  local cur_tick = reaper.MIDI_GetPPQPosFromProjTime(take, cur_pos) -- 转换光标的tick位置
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)

  idx = reaper.MIDI_EnumSelCC(take, -1) -- 反选所有CC
  while idx ~= -1 do
    reaper.MIDI_SetCC(take, idx, false, false, nil, nil, nil, nil, nil, false)
    idx = reaper.MIDI_EnumSelCC(take, idx)
  end

  local curve = get_curve(bottom, top, num)
  chan = 0 -- 通道默认为0

  -- for j = 1, #curve do
  --   Msg(curve[j])
  -- end

  for i = 1, times do
    for j = 1, #curve do
      local value = curve[j]
      value = value + 8192
      local LSB = value & 0x7f -- 低7位
      local MSB = value >> 7 & 0x7f -- 高7位
      reaper.MIDI_InsertCC(take, true, false, cur_tick, 224, chan, LSB, MSB) -- 224=弯音，LSB+MSB=弯音值
      cur_tick = cur_tick + step_length
    end
  end
  if (curve[#curve] ~= bottom) then
    value = bottom + 8192
    reaper.MIDI_InsertCC(take, false, false, cur_tick, 224, chan, value & 0x7f, value >> 7 & 0x7f)
  end
  
  j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状为直线
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 1, 0, false)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
    j = reaper.MIDI_EnumSelCC(take, j)
  end
  
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Insert Pitch Bend Curve (Triangle)", -1)
  reaper.UpdateArrange()
end

Main()

-- local c = get_curve(0,1024,12)
-- for j = 1, #c do
--   print(c[j])
-- end

reaper.SN_FocusMIDIEditor()
reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40366) -- CC: Set CC lane to Pitch