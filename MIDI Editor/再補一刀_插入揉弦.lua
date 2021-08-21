--[[
 * ReaScript Name: 插入揉弦
 * Version: 2.0
 * Author: 再補一刀
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
  + Initial release
 * v2.0 (2021-8-21)
  + Code rewriting
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end
local _SN_FocusMIDIEditor = reaper.SN_FocusMIDIEditor
reaper.SN_FocusMIDIEditor = function(...) if _SN_FocusMIDIEditor then _SN_FocusMIDIEditor(...) end end

function get_curve1(bottom, top, num) -- 正弦曲线版本
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

function get_curve2(bottom, top, num) -- 正弦曲线间隙版本
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

get_curve = get_curve1

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local bottom = reaper.GetExtState("Vibrato", "Bottom")
  if (bottom == "") then bottom = "0" end
  local top = reaper.GetExtState("Vibrato", "Top")
  if (top == "") then top = "256" end
  local times = reaper.GetExtState("Vibrato", "Times") 
  if (times == "") then times = "16" end
  local length = reaper.GetExtState("Vibrato", "Length")
  if (length == "") then length = "120" end
  local num = reaper.GetExtState("Vibrato", "Num")
  if (num == "") then num = "12" end

  local user_ok, user_input_CSV = reaper.GetUserInputs("插入揉弦", 5, "起始值,最高值,重複,長度,點數", bottom ..','.. top ..','.. times .. "," .. length .. "," .. num)
  if not user_ok then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = user_input_CSV:match("(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(bottom) or not tonumber(top) or not tonumber(times) or not tonumber(length) or not tonumber(num) then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = tonumber(bottom), tonumber(top), tonumber(times), tonumber(length), tonumber(num)
  if times < 1 then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("Vibrato", "Bottom", bottom, false)
  reaper.SetExtState("Vibrato", "Top", top, false)
  reaper.SetExtState("Vibrato", "Times", times, false)
  reaper.SetExtState("Vibrato", "Length", length, false)
  reaper.SetExtState("Vibrato", "Num", num, false)
  
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
  
  j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
  while j ~= -1 do
    reaper.MIDI_SetCCShape(take, j, 1, 0, false)
    reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
    j = reaper.MIDI_EnumSelCC(take, j)
  end
  
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("插入揉弦", -1)
  reaper.UpdateArrange()
end

Main()

-- local c = get_curve(0,1024,12)
-- for j = 1, #c do
--   print(c[j])
-- end

reaper.SN_FocusMIDIEditor()