-- @description Functions
-- @version 1.0.2
-- @author zaibuyidao
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @about Core Function Library
-- @changelog New Script

function print(param)
  if type(param) == "table" then
    table.print(param)
    return
  end
  reaper.ShowConsoleMsg(tostring(param) .. "\n")
end

function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
    if (print_r_cache[tostring(t)]) then
      print(indent .. "*" .. tostring(t))
    else
      print_r_cache[tostring(t)] = true
      if (type(t) == "table") then
        for pos, val in pairs(t) do
          if (type(val) == "table") then
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
            sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
            print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
          elseif (type(val) == "string") then
            print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
          else
            print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
          end
        end
      else
        print(indent .. tostring(t))
      end
    end
  end
  if (type(t) == "table") then
    print(tostring(t) .. " {")
    sub_print_r(t, "  ")
    print("}")
  else
    sub_print_r(t, "  ")
  end
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

function checkSWSExtension()
  local language = getSystemLanguage()
  local msg, title = "This script requires the SWS Extension. Do you want to download it now?", "Warning"

  if language == "简体中文" then
    msg = "该脚本需要 SWS 扩展，您想现在就下载它吗？"
    title = "警告"
  elseif language == "繁體中文" then
    msg = "該脚本需要 SWS 擴展，您想現在就下載它嗎？"
    title = "警告"
  end

  if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox(msg, title, 1)
    if retval == 1 then
      if not OS then local OS = reaper.GetOS() end
      if OS=="OSX32" or OS=="OSX64" then
        os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
      else
        os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
      end
    end
    return false
  else
    return true
  end
end

function checkJSAPIExtension()
  local language = getSystemLanguage()
  local msg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again. Thanks!\n"
  local title = "You must install JS_ReaScriptAPI"

  if language == "简体中文" then
    msg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本。谢谢！\n"
    title = "您必须安裝 JS_ReaScriptAPI"
  elseif language == "繁體中文" then
    msg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本。謝謝！\n"
    title = "您必須安裝 JS_ReaScriptAPI"
  end

  if not reaper.APIExists("JS_Window_Find") then
    reaper.MB(msg, title, 0)
    local retval, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
    if retval then
      reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
    else
      reaper.MB(err, "Something went wrong...", 0)
    end
    -- return reaper.defer(function() end)
    return false
  else
    return true
  end
end

function openUrl(url)
  local os = reaper.GetOS()
  if os:match("^OSX") then
    os.execute('open "" "' .. url .. '"')  -- MacOS
  elseif os:match("^Win") then
    os.execute('start "" "' .. url .. '"')  -- Windows
  else
    os.execute('xdg-open "' .. url .. '"')  -- Linux and others
  end
end

function getPathDelimiter()
  local os = reaper.GetOS()
  if os ~= "Win32" and os ~= "Win64" then
    return "/"
  else
    return "\\"
  end
end

function normalizePathDelimiter(p)
  if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then
    local r = p:gsub("/", "\\"):gsub("\\+","\\")
    return r
  else
    local r = p:gsub("\\", "/"):gsub("/+","/")
    return r
  end
end

-- 用于智能SOLO脚本
function createVirtualKeyMap()
  local map = {}

  -- Number keys 0-9
  for i = 0, 9 do
    map[tostring(i)] = 0x30 + i
  end

  -- Alphabetic keys A-Z (and a-z as VK codes are the same for upper and lower case)
  for i = 0, 25 do
    local charUpper = string.char(65 + i) -- Uppercase A-Z
    map[charUpper] = 0x41 + i
    local charLower = string.char(97 + i) -- Lowercase a-z
    map[charLower] = 0x41 + i
  end

  -- Other character keys
  map[','] = 0xBC
  map['.'] = 0xBE
  map['<'] = 0xE2
  map['>'] = 0xE2 -- The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard
  map[';'] = 0xBA
  map[':'] = 0xBA
  map['"'] = 0xDE
  map["'"] = 0xDE
  map['['] = 0xDB
  map[']'] = 0xDD
  map['\\'] = 0xDC
  map['|'] = 0xDC
  map['/'] = 0xBF
  map['?'] = 0xBF
  map['`'] = 0xC0
  map['~'] = 0xC0 -- Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the `~ key
  map['-'] = 0xBD
  map['='] = 0xBB
  map['+'] = 0xBB

  -- Function keys F1-F24
  for i = 1, 24 do
    local key = 'F' .. i
    map[key] = 0x6F + i
    map[string.lower(key)] = 0x6F + i
    map[string.upper(key)] = 0x6F + i
  end

  -- Special keys and their VK codes
  local specialKeys = {
    ['BACKSPACE'] = 0x08,
    ['TAB'] = 0x09,
    ['CLEAR'] = 0x0C,
    ['ENTER'] = 0x0D,
    ['SHIFT'] = 0x10,
    ['CTRL'] = 0x11,
    ['ALT'] = 0x12,
    ['PAUSE'] = 0x13,
    ['CAPSLOCK'] = 0x14,
    ['ESCAPE'] = 0x1B,
    ['SPACE'] = 0x20,
    ['PAGEUP'] = 0x21,
    ['PAGEDOWN'] = 0x22,
    ['END'] = 0x23,
    ['HOME'] = 0x24,
    ['LEFT'] = 0x25,
    ['UP'] = 0x26,
    ['RIGHT'] = 0x27,
    ['DOWN'] = 0x28,
    ['SELECT'] = 0x29,
    ['PRINT'] = 0x2A,
    ['EXECUTE'] = 0x2B,
    ['PRINTSCREEN'] = 0x2C,
    ['INSERT'] = 0x2D,
    ['DELETE'] = 0x2E,
    ['HELP'] = 0x2F
  }

  -- Merge special keys into the map
  for key, value in pairs(specialKeys) do
    map[string.lower(key)] = value
    map[string.upper(key)] = value
    map[key] = value
  end

  -- Numeric keypad keys 0-9
  for i = 0, 9 do
    local key = 'NUMPAD' .. i
    map[key] = 0x60 + i
    map[string.lower(key)] = 0x60 + i
    map[string.upper(key)] = 0x60 + i
  end

  -- Add additional specific keys
  local specificKeys = {
    ['MULTIPLY'] = 0x6A,
    ['ADD'] = 0x6B,
    ['SEPARATOR'] = 0x6C,
    ['SUBTRACT'] = 0x6D,
    ['DECIMAL'] = 0x6E,
    ['DIVIDE'] = 0x6F
  }

  -- Merge specific keys into the map
  for key, value in pairs(specificKeys) do
    map[string.lower(key)] = value
    map[string.upper(key)] = value
    map[key] = value
  end

  -- System keys
  local systemKeys = {
    ['LWIN'] = 0x5B,
    ['RWIN'] = 0x5C,
    ['APPS'] = 0x5D,
    ['SLEEP'] = 0x5F,
    ['NUMLOCK'] = 0x90,
    ['SCROLLLOCK'] = 0x91,
    ['LSHIFT'] = 0xA0,
    ['RSHIFT'] = 0xA1,
    ['LCONTROL'] = 0xA2,
    ['RCONTROL'] = 0xA3,
    ['LMENU'] = 0xA4,
    ['RMENU'] = 0xA5
  }

  -- Merge specific keys into the map
  for key, value in pairs(systemKeys) do
    map[string.lower(key)] = value
    map[string.upper(key)] = value
    map[key] = value
  end

  -- Media keys
  local mediaKeys = {
    ['BROWSER_BACK'] = 0xA6,
    ['BROWSER_FORWARD'] = 0xA7,
    ['BROWSER_REFRESH'] = 0xA8,
    ['BROWSER_STOP'] = 0xA9,
    ['BROWSER_SEARCH'] = 0xAA,
    ['BROWSER_FAVORITES'] = 0xAB,
    ['BROWSER_HOME'] = 0xAC,
    ['VOLUME_MUTE'] = 0xAD,
    ['VOLUME_DOWN'] = 0xAE,
    ['VOLUME_UP'] = 0xAF,
    ['MEDIA_NEXT_TRACK'] = 0xB0,
    ['MEDIA_PREV_TRACK'] = 0xB1,
    ['MEDIA_STOP'] = 0xB2,
    ['MEDIA_PLAY_PAUSE'] = 0xB3,
    ['LAUNCH_MAIL'] = 0xB4,
    ['LAUNCH_MEDIA_SELECT'] = 0xB5,
    ['LAUNCH_APP1'] = 0xB6,
    ['LAUNCH_APP2'] = 0xB7
  }

  -- Merge media keys into the map
  for key, value in pairs(mediaKeys) do
    map[string.lower(key)] = value
    map[string.upper(key)] = value
    map[key] = value
  end

  return map
end

function table.serialize(obj)
  local lua = ""
  local t = type(obj)
  if t == "number" or t == "boolean" then
    lua = tostring(obj)
  elseif t == "string" then
    lua = string.format("%q", obj)
  elseif t == "table" then
    lua = "{\n"
    for k, v in pairs(obj) do
      lua = lua .. "[" .. table.serialize(k) .. "]=" .. table.serialize(v) .. ",\n"
    end
    lua = lua .. "}"
  else
    error("cannot serialize a " .. t)
  end
  return lua
end

function table.unserialize(lua)
  if lua == nil or lua == "" then
    return nil
  else
    local func, err = load("return " .. lua)
    if not func then error(err) end
    return func()
  end
end

function getExtState(key1, key2)
  local stateString = reaper.GetExtState(key1, key2)
  if stateString == "" then
    return nil  -- Handle the case where no state is found.
  else
    return table.unserialize(stateString)
  end
end

function setExtState(key1, key2, data, persist)
  local serializedData = table.serialize(data)
  reaper.SetExtState(key1, key2, serializedData, persist)
end