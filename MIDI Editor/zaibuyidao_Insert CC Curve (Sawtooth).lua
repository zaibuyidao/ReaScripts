--[[
 * ReaScript Name: Insert CC Curve (Sawtooth)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-10-10)
  + Initial release
--]]

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox("SWS extension is required by this script.\n此腳本需要 SWS 擴展。\nHowever, it doesn't seem to be present for this REAPER installation.\n然而，對於這個REAPER安裝來說，它似乎並不存在。\n\nDo you want to download it now ?\n你想現在就下載它嗎？", "Warning", 1)
  if retval == 1 then
    Open_URL("http://www.sws-extension.org/download/pre-release/")
  end
  return
end

local _SN_FocusMIDIEditor = reaper.SN_FocusMIDIEditor
reaper.SN_FocusMIDIEditor = function(...) if _SN_FocusMIDIEditor then _SN_FocusMIDIEditor(...) end end

function get_curve0(bottom, top, num) -- 正弦曲线间隙版本
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

function get_curve2(bottom, top, num) -- 三角波曲线版本
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

function get_curve3(bottom, top, num) -- 方波曲线版本
  local result = {}
  for i = 1, num/2 do
    table.insert(result,  math.floor(bottom))
  end
  for i = 1, num/2 do
    table.insert(result, math.floor(top))
  end
  return result
end

function get_curve4(bottom, top, num) -- 锯齿波曲线版本
  local result = {}
  local step = (top - bottom) / (num - 1)
  local cur = bottom
  for i = 1, num do
    table.insert(result,  math.floor(cur))
    cur = cur + step
  end
  return result
end

local bottom = reaper.GetExtState("InsterCCCurveSawtooth", "Bottom")
if (bottom == "") then bottom = "70" end
local top = reaper.GetExtState("InsterCCCurveSawtooth", "Top")
if (top == "") then top = "100" end
local times = reaper.GetExtState("InsterCCCurveSawtooth", "Times") 
if (times == "") then times = "16" end
local length = reaper.GetExtState("InsterCCCurveSawtooth", "Length")
if (length == "") then length = "240" end
local num = reaper.GetExtState("InsterCCCurveSawtooth", "Num")
if (num == "") then num = "12" end
local ccnum = reaper.GetExtState("InsterCCCurveSawtooth", "CCNum")
if (ccnum == "") then ccnum = "11" end

local user_ok, user_input_CSV = reaper.GetUserInputs("Insert CC Curve (鋸齒波)", 6, "Starting value 起始點,Highest value 最高點,Repetitions 重複,Length 長度,Points 點數,CC number 控制器編號", bottom ..','.. top ..','.. times .. "," .. length .. "," .. num .. "," .. ccnum)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
bottom, top, times, length, num, ccnum = user_input_CSV:match("(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(bottom) or not tonumber(top) or not tonumber(times) or not tonumber(length) or not tonumber(num) or not tonumber(ccnum) then return reaper.SN_FocusMIDIEditor() end
bottom, top, times, length, num, ccnum = tonumber(bottom), tonumber(top), tonumber(times), tonumber(length), tonumber(num), tonumber(ccnum)
if times < 1 then return reaper.SN_FocusMIDIEditor() end

reaper.SetExtState("InsterCCCurveSawtooth", "Bottom", bottom, false)
reaper.SetExtState("InsterCCCurveSawtooth", "Top", top, false)
reaper.SetExtState("InsterCCCurveSawtooth", "Times", times, false)
reaper.SetExtState("InsterCCCurveSawtooth", "Length", length, false)
reaper.SetExtState("InsterCCCurveSawtooth", "Num", num, false)
reaper.SetExtState("InsterCCCurveSawtooth", "CCNum", ccnum, false)

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

curve = get_curve4(bottom, top, num)
chan = 0 -- 通道默认为0

-- for j = 1, #curve do
--   Msg(curve[j])
-- end

for i = 1, times do
  for j = 1, #curve do
    local value = curve[j]
    reaper.MIDI_InsertCC(take, true, false, cur_tick, 0xB0, chan, ccnum, value)
    cur_tick = cur_tick + step_length
  end
end
if (curve[#curve] ~= bottom) then
  reaper.MIDI_InsertCC(take, false, false, cur_tick, 0xB0, chan, ccnum, bottom)
end

j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
while j ~= -1 do
  reaper.MIDI_SetCCShape(take, j, 0, 0, false)
  reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
  j = reaper.MIDI_EnumSelCC(take, j)
end

reaper.MIDI_Sort(take)
reaper.Undo_EndBlock("Insert CC Curve (Sawtooth)", -1)
reaper.UpdateArrange()

-- local c = get_curve(0,1024,12)
-- for j = 1, #c do
--   Msg(c[j])
-- end

reaper.SN_FocusMIDIEditor()