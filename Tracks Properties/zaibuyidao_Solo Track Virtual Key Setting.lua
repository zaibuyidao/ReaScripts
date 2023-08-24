-- @description Solo Track Virtual Key Setting
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ") 
  end
  reaper.ShowConsoleMsg("\n")
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
end

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
  map['<'] = 0xBC
  map['>'] = 0xBE
  return map
end

key_map = generateKeyMap()

local language = getSystemLanguage()
if language == "简体中文" then
  title = "独奏轨道虚拟键设置"
  lable = "输入 (0-9, A-Z, 使用';;'代替','或.)"
  err_title = "不能设置这个按键，请改其他按键"
  okk_title = "设置完毕，请重新激活 Solo Track 脚本"
  okk_box = "成功！"
elseif language == "繁体中文" then
  title = "獨奏軌道虚拟键設置"
  lable = "輸入 (0-9,A-Z,使用';;'代替','或.)"
  err_title = "不能設置這個按鍵，請改其他按鍵"
  okk_title = "設置完畢，請重新激活 Solo Track 脚本"
  okk_box = "成功！"
else
  title = "Solo Track Virtual Key Settings"
  lable = "Enter (0-9, A-Z, use ';;' for ',' or .)"
  err_title = "This key can't be set. Please choose another."
  okk_title = "Settings applied. Please reactivate the Solo Track script."
  okk_box = "Completed!"
end

reaper.Undo_BeginBlock()
shift_key = 0x10
state = reaper.JS_VKeys_GetState(0) -- 获取按键的状态
if state:byte(shift_key) ~= 0 then -- 检查Shift键是否被按下
  if key == ',' then
      VirtualKeyCode = key_map['<']
  elseif key == '.' then
      VirtualKeyCode = key_map['>']
  end
else
  VirtualKeyCode = key_map[key]
end

local key = reaper.GetExtState("SOLO_TRACK_VIRTUAL_KEY_SETTING", "VirtualKey")
if (key == "") then 
    key = "9" 
elseif (key == ",") then
    key = ";;" -- Replace comma with ;;
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
reaper.SetExtState("SOLO_TRACK_VIRTUAL_KEY_SETTING", "VirtualKey", key, true)
reaper.MB(okk_title, okk_box, 0)
reaper.Undo_EndBlock(title, -1)
reaper.UpdateArrange()