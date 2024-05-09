-- @description Hold to Solo Track Settings
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Smart SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

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
local key_map = createVirtualKeyMap()

function ConcatPath(...) return table.concat({...}, package.config:sub(1, 1)) end
function remove_specific_section(filepath, section_to_remove)
  local file = io.open(filepath, 'r')
  if not file then
    print("File not found")
    return
  end
  
  local lines = {}
  local in_remove_section = false
  local section_removed = false  -- 新增：跟踪是否删除了部分

  for line in file:lines() do
    if line:match('%[' .. section_to_remove .. '%]') then
      in_remove_section = true
      section_removed = true  -- 标记已删除部分
    elseif line:match('%[.-%]') then
      in_remove_section = false
    end

    if not in_remove_section then
      table.insert(lines, line)
    end
  end

  file:close()

  -- 仅在删除了部分时重写文件
  if section_removed then
    file = io.open(filepath, 'w')
    for i, line in ipairs(lines) do
      file:write(line .. '\n')
    end
    file:close()

    -- 仅在删除了部分时显示提示
    if language == "简体中文" then
      reaper.MB("指定部分已成功移除。", "通知", 0)
    elseif language == "繁體中文" then
      reaper.MB("指定部分已成功移除。", "通知", 0)
    else
      reaper.MB("Specified section has been successfully removed.", "Notification", 0)
    end

    reaper.SetExtState("HOLD_TO_SOLO_TRACK_SETTINGS", "VirtualKey", "", true)
  end
end

reaper.Undo_BeginBlock()
local key = reaper.GetExtState("HOLD_TO_SOLO_TRACK_SETTINGS", "VirtualKey")
if (key == "") then 
  key = "F1"
elseif (key == ",") then
  key = ";;" -- Replace comma with ;;
end

if language == "简体中文" then
  title = "持续独奏轨道设置"
  lable = "虚拟键" .. ',' .. "移除键 (y/n)"
  mb_msg = "不能设置这个按键，请改其他按键。"
  mb_title = "错误"
elseif language == "繁體中文" then
  title = "持續獨奏軌道設置"
  lable = "虛擬鍵" .. ',' .. "移除鍵 (y/n)"
  mb_msg = "不能設置這個按鍵，請改其他按鍵。"
  mb_title = "錯誤"
else
  title = "Hold to Solo Track Settings"
  lable = "Virtual key" .. ',' .. "Remove key (y/n)"
  mb_msg = "This key can't be set. Please choose another."
  mb_title = "Error"
end

local retval, retvals_csv = reaper.GetUserInputs(title, 2, lable, key .. ',' .. "n")
if not retval then return end
key, remove = retvals_csv:match("(.*),(.*)")
key, remove = tostring(key), tostring(remove)
if remove ~= "y" and remove ~= "n" then return end

-- 移除虚拟键
if remove == "y" then
  local res_path = reaper.GetResourcePath()
  local ext_ini_path = ConcatPath(res_path, 'reaper-extstate.ini')
  remove_specific_section(ext_ini_path, 'HOLD_TO_SOLO_TRACK_SETTINGS')
  return
end

-- If the user entered ";;", interpret it as ","
if key == ";;" then key = "," end
if (not key_map[key]) then
  reaper.MB(mb_msg, mb_title, 0)
  return
end

reaper.SetExtState("HOLD_TO_SOLO_TRACK_SETTINGS", "VirtualKey", key, true)

if language == "简体中文" then
  mb2_msg = "虚拟键 ".. key .." 设置完毕。接下来，你需要将按键 ".. key .." 设置为无动作，以避免触发系统警报声。\n点击【确定】将会弹出操作列表的快捷键设置，请将快捷键设置为按键 ".. key .." 。\n\n最后，请重新运行 Hold to Solo Track 脚本，並使用快捷键 ".. key .." 进行独奏。"
  mb2_title = "继续下一步"
elseif language == "繁體中文" then
  mb2_msg = "虛擬鍵 ".. key .." 設置完畢。接下來，你需要將按鍵 ".. key .." 設置為無動作，以避免觸發系統警報聲。\n點擊【確定】將會彈出操作列表的快捷鍵設置，請將快捷鍵設置為按鍵 ".. key .." 。\n\n最後，請重新運行 Hold to Solo Track 腳本，並使用快捷鍵 ".. key .." 進行獨奏。"
  mb2_title = "繼續下一步"
else
  mb2_msg = "The virtual key " .. key .. " has been set up. Next, you need to configure the key " .. key .. " to 'No Action' to prevent triggering system alert sounds.\nClicking [OK] will open the action list's shortcut settings. Please set the shortcut to key " .. key .. ".\n\nLastly, please rerun the Hold to Solo Track script and use the shortcut " .. key .. " to solo."
  mb2_title = "Proceed to the next step."
end

reaper.MB(mb2_msg, mb2_title, 0) -- 继续下一步
reaper.DoActionShortcutDialog(0, 0, 65535, -1) -- No-op (no action)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()