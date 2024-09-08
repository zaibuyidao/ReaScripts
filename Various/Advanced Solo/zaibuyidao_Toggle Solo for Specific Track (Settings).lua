-- NoIndex: true
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

function ConcatPath(...) return table.concat({...}, package.config:sub(1, 1)) end
function remove_specific_section(filepath, section_to_remove)
  local file = io.open(filepath, 'r')
  if not file then
    print("File not found")
    return
  end
  
  local lines = {}
  local in_remove_section = false

  for line in file:lines() do
    -- 判断是否开始删除节
    if line:match('%[' .. section_to_remove .. '%]') then
      in_remove_section = true
    elseif line:match('%[.-%]') then
      in_remove_section = false
    end

    -- 如果不在删除节内，则保留行
    if not in_remove_section then
      table.insert(lines, line)
    end
  end

  file:close()

  -- 写回修改后的内容
  file = io.open(filepath, 'w')
  for i, line in ipairs(lines) do
    file:write(line .. '\n')
  end
  file:close()

  -- 提示已完成删除
  if language == "简体中文" then
    reaper.MB("指定部分已成功移除。", "通知", 0)
  elseif language == "繁體中文" then
    reaper.MB("指定部分已成功移除。", "通知", 0)
  else
    reaper.MB("Specified section has been successfully removed.", "Notification", 0)
  end
end

if language == "简体中文" then
    title = "切换指定轨道独奏"
    captions_csv = "轨道编号:" .. ',' .. "移除设置 (y/n)"
elseif language == "繁體中文" then
    title = "切換指定軌道獨奏"
    captions_csv = "軌道編號:"
else
    title = "Toggle Solo for Specific Track"
    captions_csv = "Track number:"
end

local num = reaper.GetExtState("TOGGLE_SOLO_FOR_SPECIFIC_TRACK_SETTINGS", "Number")
if num == "" then num = 1 end

local retval, retvals_csv = reaper.GetUserInputs(title, 1, captions_csv, num)
if not retval then return end
num = retvals_csv:match("(.*)")
if not retval or not tonumber(num) then return end
reaper.SetExtState("TOGGLE_SOLO_FOR_SPECIFIC_TRACK_SETTINGS", "Number", num, 1)
