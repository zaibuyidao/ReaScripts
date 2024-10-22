-- @description Mouse Modifiers - Toggle Move Edit Cursor
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

-- 检查并取消官方覆盖功能
local official_ids = {42616, 42618, 42620, 42633}
for _, id in ipairs(official_ids) do
  if reaper.GetToggleCommandState(id) == 1 then
    reaper.Main_OnCommand(id, 0) -- 取消激活官方覆盖功能
  end
end

local was_set = -1

local function UpdateState()
  local is_set = reaper.GetMouseModifier('MM_CTX_TRACK_CLK', 0) == '1 m' -- 检查是否为 '移动光标' 状态
  if is_set ~= was_set then
    was_set = is_set
    -- if is_set then
    --     reaper.set_action_options(4) -- 设置脚本切换状态为 '开'
    -- else
    --     reaper.set_action_options(8) -- 设置脚本切换状态为 '关'
    -- end
    reaper.set_action_options(is_set and 4 or 8) -- 设置脚本切换状态
    reaper.RefreshToolbar(0) -- 刷新工具栏
  end
end

local function ToggleMoveCursorState()
  local current_state = reaper.GetMouseModifier('MM_CTX_TRACK_CLK', 0)
  if current_state == '1 m' then
    reaper.SetMouseModifier('MM_CTX_TRACK_CLK', 0, '3 m') -- 切换到 '不移动光标' 状态
  else
    reaper.SetMouseModifier('MM_CTX_TRACK_CLK', 0, '1 m') -- 切换到 '移动光标' 状态
  end
  UpdateState()
end

ToggleMoveCursorState()
reaper.defer(UpdateState)