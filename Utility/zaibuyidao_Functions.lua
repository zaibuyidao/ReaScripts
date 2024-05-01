-- @noindex
-- @description Functions
-- @version 1.0
-- @author zaibuyidao
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @about Core Function Library
-- @changelog
--   New Script

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
