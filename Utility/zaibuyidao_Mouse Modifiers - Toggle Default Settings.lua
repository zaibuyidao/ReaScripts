-- @description Mouse Modifiers - Toggle Default Settings
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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local marquee_selection = reaper.NamedCommandLookup('_RSe26d413e28a889ec8384d643aeb592b204e5e7e9')
local time_selection = reaper.NamedCommandLookup('_RSa7b6a0054a56c6f5822b24ee2b398cd4488b449c')
local razor_editing = reaper.NamedCommandLookup('_RS310aee702b4cc146de8699ea241a41e0c3d46b3d')
local is_new_value, filename, sectionID, cmdID,mode, resolution, val = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, marquee_selection, 0)
reaper.SetToggleCommandState(sectionID, time_selection, 0)
reaper.SetToggleCommandState(sectionID, razor_editing, 0)
reaper.RefreshToolbar2(sectionID, cmdID)
reaper.SetMouseModifier('MM_CTX_ITEM',0,'13 m') -- Move item ignoring time selection
reaper.SetMouseModifier('MM_CTX_TRACK',0,'7 m') -- Select time
reaper.SetMouseModifier('MM_CTX_TRACK_CLK', 0, '1 m') -- 切换到 '移动光标' 状态
reaper.SetMouseModifier('MM_CTX_ITEM_CLK',0,'1 m') -- 切换到 选择对象并切换编辑光标
reaper.Undo_EndBlock("Mouse Modifiers - Toggle Default Settings", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()