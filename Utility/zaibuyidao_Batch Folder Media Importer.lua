-- @description Batch Folder Media Importer
-- @version 1.0.7
-- @author zaibuyidao, ChangoW
-- @changelog
--   # Fixed issue with incorrect root directory path.
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

-- 设置 package.path 以加载 REAPER 内置 ImGui 库
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3.2'
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
local ctx = ImGui.CreateContext('Batch Folder Media Importer')
local sans_serif = ImGui.CreateFont('sans-serif', 13)
ImGui.Attach(ctx, sans_serif)

-----------------------------------------------------------
-- 脚本状态变量（必须在所有使用它们的函数之前声明）
-----------------------------------------------------------
local activeDirs     = {}    -- 存储每个子目录复选框的选中状态
local inputPath      = ""    -- 导入的基目录路径
local importInterval = 0   -- 每个媒体项之间编辑光标前移的时间（毫秒）
local selectAll      = false -- “全选”复选框状态
local subdirectories = {}    -- 基目录下的所有子目录列表
local oneFile        = false
-----------------------------------------------------------
-- 工具函数
-----------------------------------------------------------

--- 拼接多个路径部分，自动使用操作系统对应的路径分隔符
-- @param ... 多个路径部分
-- @return string 拼接后的完整路径
function joinPaths(...)
  local parts = {...}
  local osStr = reaper.GetOS()
  local delimiter = (osStr == "Win32" or osStr == "Win64") and "\\" or "/"
  local path = ""
  for i, part in ipairs(parts) do
    -- 去除部分末尾和开头的分隔符，避免重复
    if i == 1 then
      path = part:gsub("[/\\]+$", "")
    else
      path = path .. delimiter .. part:gsub("^[/\\]+", ""):gsub("[/\\]+$", "")
    end
  end
  return path
end

--- 获取指定目录下的所有文件名称（按自然排序）
-- @param directory string 目录路径
-- @return table 包含所有音频文件名称的表
local function getAudioFilesInDirectory(directory)
  local audioFiles = {}
  local files = getFilesInDirectory(directory)
  for _, file in ipairs(files) do
    -- 假设音频文件以 ".wav", ".mp3", ".flac" 等为扩展名
    if file:match("%.wav$") or file:match("%.mp3$") or file:match("%.flac$") then
      table.insert(audioFiles, file)
    end
  end
  return audioFiles
end

-- 获取基目录下的所有音频文件，并将其作为“子目录”显示
local function getAllSubdirectories(directory, parentPath)
  local subdirs = {}
  
  -- 获取基目录下的音频文件
  local audioFiles = getAudioFilesInDirectory(directory)
  if #audioFiles > 0 then
    -- 如果基目录下有音频文件，添加为一个特殊的子目录项
    table.insert(subdirs, directory)  -- 添加基目录本身
  end

  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(directory, i)
    if not subdir then break end
    local fullPath = joinPaths(directory, subdir)
    -- 递归调用
    local subsubdirs = getAllSubdirectories(fullPath, parentPath)
    if #subsubdirs > 0 then
      for _, subsubdir in ipairs(subsubdirs) do
        table.insert(subdirs, subsubdir)
      end
    else
      table.insert(subdirs, fullPath)
    end
    i = i + 1
  end
  return subdirs
end

function naturalSortCompare(a, b)
  local function padnum(d) return ("%012d"):format(tonumber(d)) end
  return tostring(a):gsub("%d+", padnum) < tostring(b):gsub("%d+", padnum)
end

--- 获取指定目录下的所有文件名称（按自然排序）
-- @param directory string 目录路径
-- @return table 包含所有文件名称的表
function getFilesInDirectory(directory)
  local files = {}
  local i = 0
  while true do
    local filename = reaper.EnumerateFiles(directory, i)
    if not filename then break end
    table.insert(files, filename)
    i = i + 1
  end
  table.sort(files, naturalSortCompare)
  return files
end

-- 根据操作系统规范化路径分隔符
local function normalizePathDelimiters(inputPath)
  local osStr = reaper.GetOS()
  if osStr == "Win32" or osStr == "Win64" then
    -- Windows 使用单个反斜杠作为路径分隔符
    inputPath = inputPath:gsub("/", "\\"):gsub("\\\\", "\\")
  else
    -- 其他操作系统使用正斜杠作为路径分隔符
    inputPath = inputPath:gsub("\\", "/")
  end
  return inputPath
end

--- 将编辑光标前移指定时长（单位：毫秒）
-- @param timeLength number 前移的时长（毫秒）
local function moveEditCursorByTime(timeLength)
  local currentPos = reaper.GetCursorPosition()
  reaper.SetEditCurPos(currentPos + timeLength / 1000, true, true)
end

-- 统计指定目录及其子目录中的音频文件数量
local function countAudioFilesInDirectory(directory)
  local count = 0
  -- 获取当前目录下的所有文件
  local files = getFilesInDirectory(directory)
  for _, file in ipairs(files) do
    -- 检查文件扩展名是否为音频格式
    if file:match("%.wav$") or file:match("%.mp3$") or file:match("%.flac$") or file:match("%.ogg$") then
      count = count + 1
    end
  end
  return count
end

-- 获取指定目录下的所有子目录，并统计所有音频文件数量
local function countAudioFilesRecursively(directory)
  local totalCount = 0
  -- 首先统计基目录下的音频文件数量
  totalCount = totalCount + countAudioFilesInDirectory(directory)
  
  -- 遍历所有子目录并递归统计音频文件数量
  local i = 0
  while true do
    local subdir = reaper.EnumerateSubdirectories(directory, i)
    if not subdir then break end
    local fullPath = joinPaths(directory, subdir)
    -- 递归统计子目录下的音频文件数量
    totalCount = totalCount + countAudioFilesRecursively(fullPath)
    i = i + 1
  end
  
  return totalCount
end

-- 获取基目录KR下的音频文件总数
local function getTotalAudioFiles(inputPath)
  local totalFiles = countAudioFilesRecursively(inputPath)
  return totalFiles
end

-- 打印音频文件数量
-- local function showAudioFileCount(inputPath)
--   local totalFiles = getTotalAudioFiles(inputPath)
--   reaper.ShowConsoleMsg("Total Audio Files: " .. totalFiles .. "\n")
-- end

-----------------------------------------------------------
-- 核心业务逻辑
-----------------------------------------------------------

--- 将指定基目录下的各子目录中的音频文件依次插入工程中
-- 每个子目录对应一个新轨道（首个文件插入时创建轨道并命名为子目录名称）
-- 插入后编辑光标自动前移指定时长
-- @param baseDirectory string 基目录路径
-- @param subdirectories table 子目录路径列表

--- 获取当前选中的轨道编号
-- 如果没有选中任何轨道，则返回 0
local function getFirstSelectedTrackNumber()
  local track = reaper.GetSelectedTrack(0, 0)
  if track then
    return reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  end
  -- 如果没有选中轨道，返回最后一个轨道的编号
  local trackCount = reaper.CountTracks(0)
  if trackCount > 0 then
    return trackCount  -- 返回最后一轨的编号
  end
  return 0
end

local function importMediaFromDirectories(baseDirectory, subdirectories, pos)
  local firstSelectedTrackNumber = getFirstSelectedTrackNumber()
  -- 开始 Undo 块和UI刷新锁定
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local trackOffset = 0
  local initialCursorPosition = reaper.GetCursorPosition()

  -- 遍历每个子目录，并根据选中的轨道进行处理
  for i, subdir in ipairs(subdirectories) do
    if activeDirs[i] then
      local files = getAudioFilesInDirectory(subdir)
      if #files > 0 then
        -- 新建轨道：在每个子目录内处理前先创建一个新的轨道
        trackOffset = trackOffset + 1
        if not oneFile then reaper.InsertTrackAtIndex((firstSelectedTrackNumber - 1) + trackOffset, true) end
        local newTrack = reaper.GetTrack(0, (firstSelectedTrackNumber - 1) + trackOffset)
        if newTrack then
          local baseDirName = inputPath:match("([^/\\]+)$")
          -- 获取相对路径部分
          local relativeSubdir = subdir:sub(#baseDirectory + 1)
        
          -- 如果相对路径部分为空，表示只是基目录本身
          if relativeSubdir == "" then
            relativeSubdir = baseDirName  -- 只保留基目录名，不加反斜杠
          else
            relativeSubdir = baseDirName .. "\\" .. relativeSubdir  -- 拼接基目录和子目录
          end
          -- 设置轨道名称
          if not oneFile then
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", relativeSubdir, true)
            -- 将新轨道设置为唯一选中轨道
            reaper.SetOnlyTrackSelected(newTrack)
          end
          -- 将编辑光标移动到新轨道的起始位置
          -- 如果这里选择是，那么就勾选从光标位置导入的选项（相同时间位置），否则只勾选顺序导入(连续时间位置)的关系
          if pos == 1 then
            reaper.SetEditCurPos(initialCursorPosition, true, true)
          end
        end

        -- 在当前新创建的轨道中逐个导入子目录的媒体文件
        for _, fileName in ipairs(files) do
          local fullPath = joinPaths(subdir, fileName)
          if oneFile then
            reaper.InsertMedia(fullPath, 1)
          else
            reaper.InsertMedia(fullPath, 0)
          end
          moveEditCursorByTime(importInterval)
        end
      end
    end
  end

  -- 结束UI刷新锁定和 Undo 块
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Batch Folder Media Importer", -1)
end

-- 判断路径是否为根目录
local function isRootDirectory(path)
  -- Windows 根目录 (例如 "C:\" 或 "D:\")
  if path:match("^[A-Za-z]:\\$") or path:match("^[A-Za-z]:$") then
    return true
  end
  -- Unix-like 系统根目录 ("/")
  if path == "/" then
    return true
  end
  return false
end

-----------------------------------------------------------
-- ImGui 界面循环
-----------------------------------------------------------

--- 主循环函数，用于绘制 ImGui 界面并响应用户交互
-- @param currentSubdirectories table 当前基目录下的子目录列表
local showSelectAll = false  -- 控制 "Select All" 复选框的显示

local function mainLoop(currentSubdirectories)
  return function()
    ImGui.PushFont(ctx, sans_serif)
    ImGui.SetNextWindowSizeConstraints(ctx, 456, 146, FLT_MAX, FLT_MAX)
    local visible, open = ImGui.Begin(ctx, "Batch Folder Media Importer", true)
    if visible then
      -- 显示“Folder”标签和路径输入框，合并为一行
      ImGui.PushItemWidth(ctx, -65)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, 'Path:')
      ImGui.SameLine(ctx)

      local changed, new_inputPath = ImGui.InputText(ctx, '##path', inputPath, 256)
      ImGui.SameLine(ctx)

      -- 显示“Browse...”按钮
      if ImGui.Button(ctx, 'Browse...') then
        local retval, folder = reaper.JS_Dialog_BrowseForFolder("Select folder:", "")
        if retval and folder:len() > 0 then
          -- 格式化路径
          folder = normalizePathDelimiters(folder)
          -- 如果是根目录，给出提示并停止继续
          if isRootDirectory(folder) then
            if language == "简体中文" then
              reaper.ShowMessageBox(
                "根目录（例如 Windows 上的 C:\\, D:\\, 或类 Unix 系统上的 /）不支持。\n" ..
                "请选择一个有效目录下的子目录继续操作。",
                "无效的目录选择",
                0
              )
            elseif language == "繁體中文" then
              reaper.ShowMessageBox(
                "根目錄（例如 Windows 上的 C:\\, D:\\, 或類 Unix 系統上的 /）不支持。\n" ..
                "請選擇一個有效目錄下的子目錄繼續操作。",
                "無效的目錄選擇",
                0
              )
            else
              reaper.ShowMessageBox(
                "Root directories (e.g., C:\\, D:\\ on Windows, or / on Unix-like systems) are not supported.\n" ..
                "Please select a subdirectory within a valid directory to proceed.",
                "Invalid Directory Selection",
                0
              )
            end
          else
            inputPath = folder
            currentSubdirectories = getAllSubdirectories(inputPath, "")
          end
        end
      end

      -- 路径编辑框内容变化时立即更新路径
      if changed then
        inputPath = normalizePathDelimiters(new_inputPath)  -- 确保路径格式化处理
        -- 如果是根目录，给出提示并停止更新路径
        if isRootDirectory(inputPath) then
          --reaper.ShowMessageBox("Root directory is not supported!", "Warning", 0)  -- 显示消息框
          inputPath = ""  -- 清空输入框，避免选择根目录
          currentSubdirectories = {}  -- 清空子目录列表
        else
          -- 更新子目录并设置"Select All"复选框
          currentSubdirectories = getAllSubdirectories(inputPath, "")
        end
      end

      -- 选择导入方式（连续时间位置/相同时间位置）
      ImGui.PushItemWidth(ctx, -65)
      local rv = false
      if not val then val = 0 end
      
      -- 创建导入选项
      rv, val = ImGui.RadioButtonEx(ctx, 'Sequential time postions', val, 0)
      ImGui.SameLine(ctx)
      rv, val = ImGui.RadioButtonEx(ctx, 'Same time position', val, 1)
      ImGui.SameLine(ctx)

      -- 设置时间间隔
      _, importInterval = ImGui.InputInt(ctx, "Interval (ms)", importInterval, 1, 100)

      -- 仅在有子目录时显示 "Select All" 复选框
      -- local showSelectAll = #currentSubdirectories > 0  -- 如果有子目录则显示 "Select All"
      -- if showSelectAll then
      --   local changed_selectAll, new_selectAll = ImGui.Checkbox(ctx, "Select all files", selectAll)
      --   if changed_selectAll then
      --     selectAll = new_selectAll
      --     for i = 1, #currentSubdirectories do
      --       activeDirs[i] = selectAll  -- 更新所有子目录的复选框状态
      --     end
      --   end
      --   ImGui.SameLine(ctx)
      -- end

      -- 显示 "Select All" 复选框
      local changed_selectAll, new_selectAll = ImGui.Checkbox(ctx, "Select all files", selectAll)
      if changed_selectAll then
        selectAll = new_selectAll
        for i = 1, #currentSubdirectories do
          activeDirs[i] = selectAll  -- 更新所有子目录的复选框状态
        end
      end
      ImGui.SameLine(ctx)

      -- 显示子目录复选框
      -- for i, subdir in ipairs(currentSubdirectories) do
      --   _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, subdir, activeDirs[i])
      -- end

      -- 在显示子目录时隐藏inputPath部分
      -- for i, subdir in ipairs(currentSubdirectories) do
      --   local relativeSubdir = subdir:sub(#inputPath + 2) -- 去除inputPath部分
      --   _, activeDirs[i] = reaper.ImGui_Checkbox(ctx, relativeSubdir, activeDirs[i])
      -- end

      -- 选择 "Import each file onto a separate track" 复选框
      rv, oneFile = ImGui.Checkbox(ctx, 'Import each file onto a separate track.', oneFile)

      -- 显示总文件数量
      local totalFiles = getTotalAudioFiles(inputPath)
      ImGui.SeparatorText(ctx, totalFiles ..' Audio Files, '.. #currentSubdirectories .." Folders.")

      local function remove_last_folder(path)
        if path:sub(-1) == "\\" then path = path:sub(1, -2) end
        return path:match("^(.*)\\")  -- 匹配并去掉最后一个文件夹
      end

      local newHeadPath = remove_last_folder(inputPath)

      for i, subdir in ipairs(currentSubdirectories) do
        -- 获取相对路径（去掉inputPath部分）
        local relativeSubdir = subdir:sub(#newHeadPath + 2)  -- 去掉inputPath部分
        if relativeSubdir:sub(-1) == "\\" then
          relativeSubdir = relativeSubdir:sub(1, -2)
        end
        -- 显示复选框和子目录名称
        _, activeDirs[i] = ImGui.Checkbox(ctx, relativeSubdir, activeDirs[i])
      end

      -- 导入按钮
      -- local buttonWidth = ImGui.CalcTextSize(ctx, "Start Import")  -- 计算按钮文本的宽度
      -- ImGui.SetCursorPosX(ctx, ImGui.GetWindowWidth(ctx) - buttonWidth - 18)  -- 设置按钮位置为右边
      if ImGui.Button(ctx, "Start Import!", -1) then
        importMediaFromDirectories(joinPaths(inputPath, ""), currentSubdirectories, val)
      end

      ImGui.End(ctx)
    end

    ImGui.PopFont(ctx)
    if open then
      reaper.defer(mainLoop(currentSubdirectories))
    end
  end
end

-----------------------------------------------------------
-- 脚本入口：启动 ImGui 主循环
-----------------------------------------------------------
reaper.defer(mainLoop(subdirectories))