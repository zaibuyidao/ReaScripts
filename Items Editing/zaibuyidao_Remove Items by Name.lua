-- @description Remove Items by Name
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
reaper.Undo_BeginBlock()

if language == "简体中文" then
  title = "按名称删除对象"
  captions_csv = "对象名称:,rderextrawidth=200"
  TXT_1 = "请输入有效的对象名称"
  TXT_2 = "提示"
  TXT_3 = "已删除 %d 个名称为 '%s' 的对象"
elseif language == "繁體中文" then
  title = "按名稱刪除對象"
  captions_csv = "對象名稱:,rderextrawidth=200"
  TXT_1 = "請輸入有效的對象名稱"
  TXT_2 = "提示"
  TXT_3 = "已刪除 %d 個名稱為 '%s' 的對象"
else
  title = "Remove Items"
  captions_csv = "Item name:,rderextrawidth=200"
  TXT_1 = "Please enter a valid item name"
  TXT_2 = "Notice"
  TXT_3 = "%d items with the name '%s' have been deleted"
end

local retval, userInput = reaper.GetUserInputs(title, 1, captions_csv, "")
if not retval then return end
userInput = userInput:match("^%s*(.-)%s*$") -- 去除前后空白

if userInput == "" then
  reaper.MB(TXT_1, TXT_2, 0)
  return
end

local count = reaper.CountMediaItems(0)
local itemsDeleted = 0
for i = count - 1, 0, -1 do
  local item = reaper.GetMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  if take then
    local name = reaper.GetTakeName(take)
    if name == userInput then
      local track = reaper.GetMediaItem_Track(item)
      reaper.DeleteTrackMediaItem(track, item)
      itemsDeleted = itemsDeleted + 1
    end
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock(title, -1)
reaper.MB(string.format(TXT_3, itemsDeleted, userInput), TXT_2, 0)