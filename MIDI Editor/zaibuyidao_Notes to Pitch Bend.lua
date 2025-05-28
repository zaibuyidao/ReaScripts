-- @description Notes to Pitch Bend
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

local language       = getSystemLanguage() -- Detect the system language to display messages in Chinese or English
local range          = 12                  -- Pitch bend range in semitones (±12 semitones)
local autoSwitchLane = true                -- Set to false to preserve the user's original CC lane

local title, err_title, err_msg1, err_msg2
if language == "简体中文" then
  title = "音符转弯音"
  err_title = "错误"
  err_msg1 = "请检查音符间隔，并将其限制在一个八度内"
  err_msg2 = "请选择两个或更多音符"
elseif language == "繁體中文" then
  title = "音符轉彎音"
  err_title = "錯誤"
  err_msg1 = "請檢查音符間隔，並將其限制在一個八度内"
  err_msg2 = "請選擇兩個或更多音符"
else
  title = "Notes to Pitch Bend"
  err_title = "Error"
  err_msg1 = "Please check the note interval and limit it to one octave."
  err_msg2 = "Please select two or more notes."
end

local editor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(editor)
if take == nil then return end

-- 获取选中音符索引
local index = {}
local val = reaper.MIDI_EnumSelNotes(take, -1)
while val ~= -1 do
  table.insert(index, val)
  val = reaper.MIDI_EnumSelNotes(take, val)
end

if #index < 2 then
  reaper.MB(err_msg2, err_title, 0)
  return
end

-- 插值表
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

local function pitchUp(o, targets)
  return targets[o + (range + 1)]
end

local function pitchDown(p, targets)
  return targets[p + (range + 1)]
end

local seg = getSegments(range)
local notes = {}

-- 获取音符数据并排序
for _, idx in ipairs(index) do
  local retval, sel, mut, s_ppq, e_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, idx)
  if sel then
    table.insert(notes, {
      index = idx,
      startppq = s_ppq,
      endppq = e_ppq,
      pitch = pitch,
      vel = vel,
      chan = chan,
      selected = sel,
      muted = mut
    })
  end
end

table.sort(notes, function(a, b) return a.startppq < b.startppq end)

-- 主音符
local main = notes[1]

-- 查找选中音符中最末尾的结束位置
local last_endppq = 0
for _, n in ipairs(notes) do
  if n.endppq > last_endppq then
    last_endppq = n.endppq
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local max_endppq = 0
local LSB_list = {}
local MSB_list = {}
LSB_list[1] = 0
MSB_list[1] = 64

for i = 2, #notes do
  local n = notes[i]
  local interval = n.pitch - main.pitch
  if math.abs(interval) > range then
    reaper.MB(err_msg1, err_title, 0)
    return
  end

  local bend = interval >= 0 and pitchUp(interval, seg) or pitchDown(interval, seg)
  if not bend then
    reaper.MB(err_msg1, err_title, 0)
    return
  end

  local LSB = bend & 0x7F
  local MSB = (bend >> 7) + 64
  LSB_list[i] = LSB
  MSB_list[i] = MSB
  if notes[i].endppq > max_endppq then max_endppq = notes[i].endppq end

  reaper.MIDI_InsertCC(take, false, false, n.startppq, 224, 0, LSB, MSB)

  if notes[i].endppq < max_endppq then
    if i > 1 and LSB_list[i - 1] and MSB_list[i - 1] then
      reaper.MIDI_InsertCC(take, false, false, n.endppq, 224, 0, LSB_list[i - 1], MSB_list[i - 1])
    else
      reaper.MIDI_InsertCC(take, false, false, n.endppq + 10, 224, 0, 0, 64)
    end
  end
end

-- 删除所有选中音符 v1
for i = #index, 1, -1 do
  reaper.MIDI_DeleteNote(take, index[i])
end
-- 删除所有选中音符 v2
-- j = reaper.MIDI_EnumSelNotes(take, -1)
-- while j > -1 do
--   reaper.MIDI_DeleteNote(take, j)
--   j = reaper.MIDI_EnumSelNotes(take, -1)
-- end

-- 重插主音符，延长结束位置
reaper.MIDI_InsertNote(take, true, main.muted, main.startppq, last_endppq, main.chan, main.pitch, main.vel, true)
-- 在最后位置插入归零
reaper.MIDI_InsertCC(take, false, false, last_endppq, 224, 0, 0, 64)

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
if autoSwitchLane then
  reaper.MIDIEditor_OnCommand(editor, 40366) -- CC: Set CC lane to Pitch
end