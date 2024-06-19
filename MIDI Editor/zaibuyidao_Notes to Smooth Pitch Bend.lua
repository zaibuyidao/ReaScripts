-- @description Notes to Smooth Pitch Bend
-- @version 1.0
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

range = 12

if language == "简体中文" then
  title = "音符转平滑弯音"
  err_title = "错误"
  err_msg1 = "请检查音符间隔，并将其限制在一个八度内"
  err_msg2 = "请选择两个或更多音符"
elseif language == "繁体中文" then
  title = "音符轉平滑彎音"
  err_title = "錯誤"
  err_msg1 = "請檢查音符間隔，並將其限制在一個八度内"
  err_msg2 = "請選擇兩個或更多音符"
else
  title = "Notes to Smooth Pitch Bend"
  err_title = "Error"
  err_msg1 = "Please check the note interval and limit it to one octave."
  err_msg2 = "Please select two or more notes."
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
local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local cur_gird, swing = reaper.MIDI_GetGrid(take)
local tick_gird = midi_tick * cur_gird

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

if #index > 1 then
  local prevLSB, prevMSB = 0, 64  -- 初始化前一个音符的弯音值为（0, 64）

  for i = 1, #index do
    retval, selected, muted, startppqpos[i], endppqpos[i], chan, pitch[i], vel[i] = reaper.MIDI_GetNote(take, index[i])
    if selected then
      if i > 1 then  -- 从第二个音符开始插入网格点
        reaper.MIDI_InsertCC(take, true, false, startppqpos[i]-tick_gird, 224, 0, prevLSB, prevMSB)
      end

      if pitch[i-1] then
        local pitchnote = (pitch[i]-pitch[1])
        local seg = getSegments(range)
        
        if pitchnote > 0 then
          pitchbend = pitchUp(pitchnote, seg)
        else
          pitchbend = pitchDown(pitchnote, seg)
        end
        
        if pitchbend == nil then return reaper.MB(err_msg1, err_title, 0) end

        LSB = pitchbend & 0x7F
        MSB = (pitchbend >> 7) + 64

        prevLSB, prevMSB = LSB, MSB  -- 更新前一个音符的弯音值

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

      j = reaper.MIDI_EnumSelCC(take, -1) -- 选中CC设置形状
      while j ~= -1 do
        reaper.MIDI_SetCCShape(take, j, 1, 0, false)
        reaper.MIDI_SetCC(take, j, false, false, nil, nil, nil, nil, nil, false)
        j = reaper.MIDI_EnumSelCC(take, j)
      end
    end
  end
else
  reaper.MB(err_msg2, err_title, 0)
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.MIDIEditor_OnCommand(editor, 40366) -- CC: Set CC lane to Pitch