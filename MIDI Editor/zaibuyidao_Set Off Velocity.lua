-- @description Set Off Velocity
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

local getTakes = getAllTakes()

if language == "简体中文" then
  title = "设置释放力度"
  captions_csv = "释放值:"
elseif language == "繁體中文 " then
  title = "設置釋放力度"
  captions_csv = "釋放值:"
else
  title = "Set Off Velocity"
  captions_csv = "Off Value:"
end

local uin = reaper.GetExtState("SetOffVelocity", "OffValue")
if (uin == "") then uin = "1" end

uok, uin = reaper.GetUserInputs(title, 1, captions_csv, uin)
if not uok then return end
reaper.SetExtState("SetOffVelocity", "OffValue", uin, false)

local vel = math.max(0, math.min(127, tonumber(uin) or 1))
local pack, unpack = string.pack, string.unpack

reaper.Undo_BeginBlock()

for take, _ in pairs(getTakes) do
  local midi_ok, midi_string = reaper.MIDI_GetAllEvts(take, "")
  if not midi_ok then 
    reaper.ShowMessageBox("Error loading MIDI", "Error", 0) 
    reaper.Undo_EndBlock(title, -1)
    return 
  end
  
  local string_pos, table_events = 1, {}
  while string_pos < #midi_string do
    local offset, flags, msg
    offset, flags, msg, string_pos = unpack("i4Bs4", midi_string, string_pos)
    if flags & 1 == 1 and #msg >= 3 and msg:byte(1) >> 4 == 8 and msg:byte(3) ~= -1 then
      msg = msg:sub(1, 2) .. string.char(vel)
    end
    table.insert(table_events, pack("i4Bs4", offset, flags, msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(table_events))
end

reaper.Undo_EndBlock(title, -1)
reaper.SN_FocusMIDIEditor()