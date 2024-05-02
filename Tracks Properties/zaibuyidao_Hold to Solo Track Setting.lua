-- @description Hold to Solo Track Setting
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Intelligent SOLO Script Series, filter "zaibuyidao solo" in ReaPack or Actions to access all scripts.

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

local function generateKeyMap()
  local map = {}
  for i = 0, 9 do
    map[tostring(i)] = 0x30 + i
  end
  for i = 0, 25 do
    local char = string.char(65 + i)  -- Uppercase A-Z
    map[char] = 0x41 + i
    char = string.char(97 + i)  -- Lowercase a-z
    map[char] = 0x41 + i  -- Virtual Key Codes are the same for uppercase
  end
  map[','] = 0xBC
  map['.'] = 0xBE
  map['<'] = 0xE2
  map['>'] = 0xE2
  return map
end

key_map = generateKeyMap()

reaper.Undo_BeginBlock()
shift_key = 0x10
ctrl_key = 0x11
alt_key = 0x12
state = reaper.JS_VKeys_GetState(0) -- 获取按键的状态

local key = reaper.GetExtState("SOLO_TRACK_SHORTCUT_SETTING", "VirtualKey")
if (key == "") then 
  key = "9" 
elseif (key == ",") then
  key = ";;" -- Replace comma with ;;
end

if language == "简体中文" then
  title = "持续独奏轨道设置"
  lable = "输入 (0-9,A-Z,使用';;'代替','或.)"
  err_title = "不能设置这个按键，请改其他按键"
elseif language == "繁體中文" then
  title = "持續獨奏軌道設置"
  lable = "輸入 (0-9,A-Z,使用';;'代替','或.)"
  err_title = "不能設置這個按鍵，請改其他按鍵"
else
  title = "Hold to Solo Track Settings"
  lable = "Enter (0-9, A-Z, use ';;' for ',' or .)"
  err_title = "This key can't be set. Please choose another."
end

local retval, retvals_csv = reaper.GetUserInputs(title, 1, lable, key)
if retval == nil or retval == false then 
  return
end

-- If the user entered ";;", interpret it as ","
if retvals_csv == ";;" then
  retvals_csv = ","
end

if (not key_map[retvals_csv]) then
  reaper.MB(err_title, "Error", 0)
  return
end

key = retvals_csv
VirtualKeyCode = key_map[key]
reaper.SetExtState("HOLD_TO_SOLO_TRACK_SETTING", "VirtualKey", key, true)

if language == "简体中文" then
  okk_title = "虚拟键 ".. key .." 设置完毕。接下来，你需要将按键 ".. key .." 设置为无动作，以避免触发系统警报声。\n点击【确定】将会弹出操作列表的快捷键设置，请将快捷键设置为按键 ".. key .." 。\n\n最后，请重新运行 Hold to Solo Track 脚本，並使用快捷键 ".. key .." 进行独奏。"
  okk_box = "继续下一步"
elseif language == "繁體中文" then
  okk_title = "虛擬鍵 ".. key .." 設置完畢。接下來，你需要將按鍵 ".. key .." 設置為無動作，以避免觸發系統警報聲。\n點擊【確定】將會彈出操作列表的快捷鍵設置，請將快捷鍵設置為按鍵 ".. key .." 。\n\n最後，請重新運行 Hold to Solo Track 腳本，並使用快捷鍵 ".. key .." 進行獨奏。"
  okk_box = "繼續下一步"
else
  okk_title = "The virtual key " .. key .. " has been set up. Next, you need to configure the key " .. key .. " to 'No Action' to prevent triggering system alert sounds.\nClicking [OK] will open the action list's shortcut settings. Please set the shortcut to key " .. key .. ".\n\nLastly, please rerun the Hold to Solo Track script and use the shortcut " .. key .. " to solo."
  okk_box = "Proceed to the next step."
end

reaper.MB(okk_title, okk_box, 0) -- 继续下一步
reaper.DoActionShortcutDialog(0, 0, 65535, -1) -- No-op (no action)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()