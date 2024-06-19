-- @description Insert Pitch Bend Curve (Sine)
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Pitch Bend Script Series, filter "zaibuyidao pitch bend" in ReaPack or Actions to access all scripts.
--   Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

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

get_curve = get_cur_sine1

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if not take or not reaper.TakeIsMIDI(take) then return end

  local bottom = reaper.GetExtState("InsertPitchBendCurveSine", "Bottom")
  if (bottom == "") then bottom = "0" end
  local top = reaper.GetExtState("InsertPitchBendCurveSine", "Top")
  if (top == "") then top = "1024" end
  local times = reaper.GetExtState("InsertPitchBendCurveSine", "Times") 
  if (times == "") then times = "16" end
  local length = reaper.GetExtState("InsertPitchBendCurveSine", "Length")
  if (length == "") then length = "240" end
  local num = reaper.GetExtState("InsertPitchBendCurveSine", "Num")
  if (num == "") then num = "12" end

  if language == "简体中文" then
    title = "插入弯音曲线(正弦)"
    captions_csv = "起始点,最高点,重复,长度,点数"
  elseif language == "繁體中文" then
    title = "插入彎音曲綫(正弦)"
    captions_csv = "起始點,最高點,重複,長度,點數"
  else
    title = "Insert Pitch Bend Curve (Sine)"
    captions_csv = "Starting value,Highest value,Repetitions,Length,Points"
  end

  local uok, uinput = reaper.GetUserInputs(title, 5, captions_csv, bottom ..','.. top ..','.. times .. "," .. length .. "," .. num)
  if not uok then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = uinput:match("(.*),(.*),(.*),(.*),(.*)")
  if not tonumber(bottom) or not tonumber(top) or not tonumber(times) or not tonumber(length) or not tonumber(num) then return reaper.SN_FocusMIDIEditor() end
  bottom, top, times, length, num = tonumber(bottom), tonumber(top), tonumber(times), tonumber(length), tonumber(num)
  if times < 1 then return reaper.SN_FocusMIDIEditor() end

  reaper.SetExtState("InsertPitchBendCurveSine", "Bottom", bottom, false)
  reaper.SetExtState("InsertPitchBendCurveSine", "Top", top, false)
  reaper.SetExtState("InsertPitchBendCurveSine", "Times", times, false)
  reaper.SetExtState("InsertPitchBendCurveSine", "Length", length, false)
  reaper.SetExtState("InsertPitchBendCurveSine", "Num", num, false)
  
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
  reaper.Undo_EndBlock(title, -1)
  reaper.UpdateArrange()
end

Main()

-- local c = get_curve(0,1024,12)
-- for j = 1, #c do
--   print(c[j])
-- end

reaper.SN_FocusMIDIEditor()
reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40366) -- CC: Set CC lane to Pitch