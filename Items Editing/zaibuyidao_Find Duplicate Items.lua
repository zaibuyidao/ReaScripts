-- @description Find Duplicate Items
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
reaper.ClearConsole()
reaper.Undo_BeginBlock()

local item_count = reaper.CountMediaItems(0)
local bgm_count = {} -- 保存每个名称出现的次数

for i = 0, item_count - 1 do
  local item = reaper.GetMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  if take then
    local name = reaper.GetTakeName(take)
    if name and name ~= "" then
      bgm_count[name] = (bgm_count[name] or 0) + 1
    end
  end
end

if language == "简体中文" then
  TXT_1 = "重复对象列表:\n"
  TXT_2 = "对象 '%s' 重复了 %d 个\n"
  TXT_3 = "\n脚本执行完毕\n"
  TXT_4 = "查找重复对象"
elseif language == "繁體中文" then
  TXT_1 = "重複對象列表:\n"
  TXT_2 = "對象 '%s' 重複了 %d 個\n"
  TXT_3 = "\n腳本執行完畢\n"
  TXT_4 = "查找重複對象"
else
  TXT_1 = "Duplicate item list:\n"
  TXT_2 = "Item '%s' is duplicated %d times\n"
  TXT_3 = "\nScript execution complete.\n"
  TXT_4 = "Find Duplicate Items"
end

-- 打印重复对象信息
reaper.ShowConsoleMsg(TXT_1)
for name, count in pairs(bgm_count) do
  if count > 1 then
    reaper.ShowConsoleMsg(string.format(TXT_2, name, count))
  end
end

reaper.ShowConsoleMsg(TXT_3)
reaper.Undo_EndBlock(TXT_4, -1)