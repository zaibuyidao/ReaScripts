-- @description Locate Items
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

reaper.Undo_BeginBlock()
local language = getSystemLanguage()
local extSection = "DuplicateItemsFinder"
local storedInput = reaper.GetExtState(extSection, "userInput")
if storedInput == nil then storedInput = "" end

if language == "简体中文" then
  title = "对位对象"
  captions_csv = "对象名称:,rderextrawidth=200"
  TXT_1 = "请输入有效的对象名称"
  TXT_2 = "提示"
elseif language == "繁體中文" then
  title = "定位對象"
  captions_csv = "對象名稱:,rderextrawidth=200"
  TXT_1 = "請輸入有效的對象名稱"
  TXT_2 = "提示"
else
  title = "Locate Items"
  captions_csv = "Item name:,rderextrawidth=200"
  TXT_1 = "Please enter a valid item name"
  TXT_2 = "Notice"
end

local retval, userInput = reaper.GetUserInputs(title, 1, captions_csv, storedInput)
if not retval then return end
userInput = userInput:match("^%s*(.-)%s*$") -- 去除前后空白

if userInput == "" then
  reaper.MB(TXT_1, TXT_2, 0)
  return
end

if language == "简体中文" then
  TXT_3 = "没有找到名称为 \"" .. userInput .. "\" 的对象"
  TXT_4 = "提示"
  TXT_5 = "定位到第 %d/%d 个匹配对象, 开始位置: %s\n"
elseif language == "繁體中文" then
  TXT_3 = "沒有找到名稱為 \"" .. userInput .. "\" 的對象"
  TXT_4 = "提示"
  TXT_5 = "定位到第 %d/%d 個匹配對象, 開始位置: %s\n"
else
  TXT_3 = "No item found with the name \"" .. userInput .. "\""
  TXT_4 = "Notice"
  TXT_5 = "Located %d/%d matching item(s), start position: %s\n"
end

-- 遍历所有对象，收集名称匹配的对象
local matchingItems = {}
local itemCount = reaper.CountMediaItems(0)
for i = 0, itemCount - 1 do
  local item = reaper.GetMediaItem(0, i)
  local take = reaper.GetActiveTake(item)
  if take then
    local name = reaper.GetTakeName(take)
    if name == userInput then
      table.insert(matchingItems, item)
    end
  end
end

if #matchingItems == 0 then
  reaper.MB(TXT_3, TXT_4, 0)
  return
end

reaper.SetExtState(extSection, "userInput", userInput, false)

-- 按对象开始时间排序
table.sort(matchingItems, function(a, b)
  return reaper.GetMediaItemInfo_Value(a, "D_POSITION") < reaper.GetMediaItemInfo_Value(b, "D_POSITION")
end)

-- 使用 ExtState 保存上一次的搜索状态，字段分别为 lastSearchName 与 lastIndex
local lastSearchName = reaper.GetExtState(extSection, "lastSearchName")
local lastIndexStr = reaper.GetExtState(extSection, "lastIndex")
local lastIndex = tonumber(lastIndexStr) or 0

local indexToJump = 0
if lastSearchName ~= userInput then
  indexToJump = 1 -- 新的搜索词，重置索引为第一个
else
  indexToJump = lastIndex + 1
  if indexToJump > #matchingItems then
    indexToJump = 1 -- 循环回到第一个
  end
end

local itemToJump = matchingItems[indexToJump]
local itemStart = reaper.GetMediaItemInfo_Value(itemToJump, "D_POSITION")

-- 定位光标到对象的开始位置
reaper.SetEditCurPos(itemStart, true, false)
reaper.UpdateArrange()

reaper.SetExtState(extSection, "lastSearchName", userInput, false)
reaper.SetExtState(extSection, "lastIndex", tostring(indexToJump), false)
local formattedTime = reaper.format_timestr_pos(itemStart, "%M:%S.%3N", 0)
reaper.ShowConsoleMsg(string.format(TXT_5, indexToJump, #matchingItems, formattedTime))
reaper.Undo_EndBlock(title, -1)