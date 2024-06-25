-- @description Auto-Load VSTi for MIDI Playback (Settings)
-- @version 1.0
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

local language = getSystemLanguage()

reaper.Undo_BeginBlock() -- 撤销块开始

local section = "AutoLoadVSTiForMIDIPlayback"
local key = "VSTiName"

if language == "简体中文" then
  title = "自动加载 VSTi 以进行 MIDI 回放(设置)"
  ip_title = "VSTi 设置"
  ip_caption = "输入 VSTi 名称:,extrawidth=150"
elseif language == "繁體中文" then
  title = "自動加載 VSTi 以進行 MIDI 回放(設置)"
  ip_title = "VSTi 設置"
  ip_caption = "輸入 VSTi 名稱:extrawidth=150"
else
  title = "Auto-Load VSTi for MIDI Playback (Settings)"
  ip_title = "VSTi Settings"
  ip_caption = "Enter VSTi name:extrawidth=150"
end

-- 尝试获取已保存的 VSTi 名称
local savedVSTiName = reaper.GetExtState(section, key)
if not savedVSTiName then savedVSTiName = "SOUND Canvas VA" end

-- 获取用户输入的 VSTi 名称，显示已保存的名称作为默认值
local retval, vstiName = reaper.GetUserInputs(ip_title, 1, ip_caption, savedVSTiName)

if retval then
  -- 保存用户输入的 VSTi 名称为扩展状态
  reaper.SetExtState(section, key, vstiName, true)
end

reaper.Undo_EndBlock(title, -1) -- 撤销块结束