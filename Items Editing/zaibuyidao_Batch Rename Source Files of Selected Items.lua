-- @description Batch Rename Source Files of Selected Items
-- @version 1.0.2
-- @author zaibuyidao
-- @changelog
--   + New Script
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
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

-- 遍历所有媒体对象，检查是否有选中的
function CountSelectedItems(proj)
  local sel_cnt = 0
  local item_count = reaper.CountMediaItems(proj)

  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(proj, i)
    if reaper.IsMediaItemSelected(item) then
      sel_cnt = sel_cnt + 1
    end
  end

  return sel_cnt
end

-- 保存当前选中的媒体对象
function SaveSelectedItems(t)
  local proj = 0 -- 获取当前工程
  local cnt = reaper.CountMediaItems(proj) -- 获取媒体对象的数量
  for i = 0, cnt - 1 do
    local item = reaper.GetMediaItem(proj, i)
    if reaper.IsMediaItemSelected(item) then
      table.insert(t, item) -- 仅保存选中的对象
    end
  end
end

-- 恢复选中的媒体对象
function RestoreSelectedItems(t)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
  for _, item in ipairs(t) do
    if item then
      reaper.SetMediaItemSelected(item, true) -- 恢复选中的对象
    end
  end
end

local init_sel_items = {}
SaveSelectedItems(init_sel_items) -- 保存当前选中的对象
reaper.PreventUIRefresh(1) -- 暂时禁用界面刷新，避免显示错误
reaper.Undo_BeginBlock()

local write_take_name = true -- true 将新文件名写入 Take 名称，false 保持原 Take 名称

-- 检查是否选中至少一个媒体对象
local sel_cnt = CountSelectedItems(0)
if sel_cnt == 0 then
  reaper.ShowMessageBox("请先选中至少一个媒体对象！", "Error", 0)
  return
end

-- 获取 Take 的源文件路径
local function GetTakeSourceFilePath(take)
  if not take then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end
  local path = reaper.GetMediaSourceFileName(source, "")
  return path
end

-- 收集选中对象的源文件路径
local function CollectSelectedSourcePaths()
  local selected_paths = {}
  local cnt = CountSelectedItems(0)
  for i = 0, cnt-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local path = GetTakeSourceFilePath(take)
    if path then
      selected_paths[path] = true -- 记录路径，便于查找
    end
  end
  return selected_paths
end

-- 根据源路径选中对应的媒体对象
local function SelectItemsBySourcePaths(selected_paths)
  local cnt = reaper.CountMediaItems(0)
  for i = 0, cnt-1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local path = GetTakeSourceFilePath(take)
    if path and selected_paths[path] then
      reaper.SetMediaItemSelected(item, true)
    end
  end
end

local selected_paths = CollectSelectedSourcePaths()
if next(selected_paths) == nil then
  reaper.ShowMessageBox("没有选中任何带源文件的对象。", "提示", 0)
  return
end
SelectItemsBySourcePaths(selected_paths)

sel_cnt = CountSelectedItems(0)

-- 获取用户输入的命名模式
local title = "Rename Source Files"
local prompt = "Enter naming pattern:,extrawidth=200" -- (supports: $source, d=START[-END], a=LETTER[-LETTER], r=LENGTH)
local pattern = "$source_d=0001_a=D-A_r=4"
local ok, baseName = reaper.GetUserInputs(title, 1, prompt, pattern)
if not ok or baseName == "" then return end
if baseName == "$source_d=0001_a=D-A_r=4" then baseName = "" end

-- 分离文件名和扩展名
local function SplitNameExt(filename)
  local ext = filename:match("%.[^%.]+$") or ""
  if ext ~= "" then
    return filename:sub(1, #filename - #ext), ext
  else
    return filename, ""
  end
end

-- 收集选中媒体对象及其源路径
local function CollectAudioSources()
  local cnt = CountSelectedItems(0)
  local items, uniqueList, seen = {}, {}, {}
  for i = 0, cnt - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local src = reaper.GetMediaItemTake_Source(take)
      local path = reaper.GetMediaSourceFileName(src, "")
      if path ~= "" then
        table.insert(items, { item = item, take = take, oldPath = path })
        if not seen[path] then
          seen[path] = true
          table.insert(uniqueList, path)
        end
      end
    end
  end
  if #uniqueList == 0 then
    reaper.ShowMessageBox("选中的媒体对象没有音频源或均为 MIDI!", "Error", 0)
    return nil
  end
  return items, uniqueList
end

baseName, userExt = SplitNameExt(baseName)
local items, uniqueList = CollectAudioSources()
if not items then return end

-- 显示重命名结果
local function ShowResult(uniqueList, errors)
  local total = #uniqueList
  local fail  = #errors
  local succ  = total - fail
  reaper.ShowConsoleMsg("\n" .. string.format("共处理 %d 个文件。", total))
  reaper.ShowConsoleMsg(string.format("成功 %d 个，", succ)) 
  reaper.ShowConsoleMsg(string.format("失败 %d 个。", fail) .. "\n")
  
  -- 显示失败详情
  if fail > 0 then
    reaper.ShowConsoleMsg("\n失败详情: \n")
    for _, e in ipairs(errors) do
      reaper.ShowConsoleMsg("  - " .. e .. "\n")
    end
  end
end

local function ShowResult2(uniqueList, errors)
  local total  = #uniqueList
  local fail   = #errors
  local succ   = total - fail
  local lines  = {
    string.format("共处理 %d 个文件", total),
    string.format(" • 成功 %d 个", succ),
    string.format(" • 失败 %d 个", fail),
  }
  if fail > 0 then
    table.insert(lines, "")
    table.insert(lines, "失败详情：")
    for _, e in ipairs(errors) do table.insert(lines, "  - "..e) end
  end
  reaper.ShowMessageBox(table.concat(lines, "\n"), "重命名完成", 0)
end

local function DisplayRenameLog(uniqueList, nameMap, errors, useDialog)
  reaper.ShowConsoleMsg("---- 开始重命名 ----\n")
  -- Console 每条尝试信息
  for _, oldPath in ipairs(uniqueList) do
    local newName = nameMap[oldPath] or ""
    reaper.ShowConsoleMsg(string.format("尝试: %s -> %s\n", oldPath, newName))
  end

  -- Console 汇总
  local total = #uniqueList
  local fail  = #errors
  local succ  = total - fail
  reaper.ShowConsoleMsg(string.format("\n共处理 %d 个文件。成功 %d 个，失败 %d 个。\n", total, succ, fail))

  -- Console 失败详情
  if fail > 0 then
    reaper.ShowConsoleMsg("\n失败详情:\n")
    for _, e in ipairs(errors) do
      reaper.ShowConsoleMsg("  - " .. e .. "\n")
    end
  end

  reaper.ShowConsoleMsg("---- 重命名结束 ----\n")

  -- 如果需要弹窗，再用对话框展示一次
  if useDialog then
    local lines = {
      string.format("共处理 %d 个文件", total),
      string.format(" • 成功 %d 个", succ),
      string.format(" • 失败 %d 个", fail),
    }
    if fail > 0 then
      table.insert(lines, "")
      table.insert(lines, "失败详情：")
      for _, e in ipairs(errors) do
        table.insert(lines, "  - " .. e)
      end
    end
    reaper.ShowMessageBox(table.concat(lines, "\n"), "重命名完成", 0)
  end
end

-- 构造新的文件名映射
local function BuildNameMap(uniqueList, baseName, userExt)
  local nameMap = {}
  -- 辅助：从路径提取扩展名
  local function getExt(path) return path:match("%.[^%.]+$") or "" end

  for i, oldPath in ipairs(uniqueList) do
    -- 1) 取出原始文件名（不含扩展）
    local filename = oldPath:match("[^\\/]+$") or oldPath
    local origName = filename:match("(.+)%.[^%.]+$") or filename

    -- 2) 从 baseName 复制一个模板字符串
    local name = baseName

    -- 3) 数字范围 d=起始-结束
    name = name:gsub("d=(%d+)%-(%d+)", function(s, e)
      local s_, e_ = tonumber(s), tonumber(e)
      local pad   = math.max(#s, #e)
      local step  = s_ <= e_ and 1 or -1
      -- 构造这个范围的序列
      local seq = {}
      for v = s_, e_, step do seq[#seq+1] = v end
      -- 按 (i-1)%#seq 拿出数字
      return string.format("%0"..pad.."d", seq[((i-1) % #seq) + 1])
    end)

    -- 4) 连续数字 d=起始
    name = name:gsub("d=(%d+)", function(s)
      local num = tonumber(s) + i - 1
      local pad = #s
      return string.format("%0"..pad.."d", num)
    end)

    -- 5) 字母范围 a=起始-结束（支持 a=A-Z 或 a=Z-X 的正向/逆向循环）
    name = name:gsub("a=([A-Za-z])%-([A-Za-z])", function(c1, c2)
      local b1, b2 = c1:byte(), c2:byte()
      local rng    = math.abs(b2 - b1) + 1      -- 字母区间长度
      local off    = (i - 1) % rng              -- 循环偏移
      -- 正序 or 倒序
      local bb     = (b1 <= b2) and (b1 + off) or (b1 - off)
      return string.char(bb)
    end)

    -- 6) 连续字母 a=起始
    name = name:gsub("a=([A-Za-z])", function(c)
      local sb = c:byte()
      local is_up = (c >= "A" and c <= "Z")
      local start_byte = is_up and string.byte("A") or string.byte("a")
      -- 总共26个字母
      local off = (sb - start_byte + (i-1)) % 26
      return string.char(start_byte + off)
    end)

    -- 7) 随机字符 r=长度
    name = name:gsub("r=(%d+)", function(n)
      local cnt = tonumber(n)
      -- 构建字符池：'0'-'9','A'-'Z','a'-'z'
      local pool = {}
      for c = 48, 57  do pool[#pool+1] = string.char(c) end
      for c = 65, 90  do pool[#pool+1] = string.char(c) end
      for c = 97, 122 do pool[#pool+1] = string.char(c) end
      -- 随机抽取 cnt 个字符
      local out = {}
      for _ = 1, cnt do
        out[#out+1] = pool[math.random(#pool)]
      end
      return table.concat(out)
    end)

    -- 枚举循环: e=项1|项2|…; (分号后是终止符)
    name = name:gsub("e=([^;]+);", function(list)
      local vals = {}
      for v in list:gmatch("([^|]+)") do
        table.insert(vals, v)
      end
      if #vals == 0 then return "" end
      local idx = ((i - 1) % #vals) + 1
      return vals[idx]
    end)

    -- 8) 替换 $source 为原始文件名
    name = name:gsub("%$source", origName)

    -- 9) 拼接扩展名
    local ext = (userExt ~= "" and userExt) or getExt(oldPath)
    nameMap[oldPath] = name .. ext
  end

  -- 10) 冲突修复
  local seen = {} -- 记录每个生成名称出现了几次
  for _, oldPath in ipairs(uniqueList) do
    local nm = nameMap[oldPath]
    seen[nm] = (seen[nm] or 0) + 1
    if seen[nm] > 1 then
      -- 提取扩展名
      local ext  = nm:match("(%.[^%.]+)$") or ""
      -- 提取不带扩展名的部分
      local base = nm:sub(1, #nm - #ext)
      -- 第2次出现加 -001, 第3次 -002...
      nameMap[oldPath] = base .. string.format("-%03d", seen[nm]-1) .. ext
    end
  end

  return nameMap
end

-- 离线所有源文件，记录原始在线状态
local function OfflineSources(items)
  local state = {} -- key: take 对象，value: 离线前是否在线
  for _, rec in ipairs(items) do
    local take = rec.take
    local src  = reaper.GetMediaItemTake_Source(take)
    -- 对每个 take 独立记录并离线
    local wasOnline = reaper.CF_GetMediaSourceOnline(src)
    state[take] = wasOnline
    if wasOnline then
      reaper.CF_SetMediaSourceOnline(src, false)
    end
  end
  return state
end

-- 检测文件是否存在
local function FileExists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

-- 重命名并更新文件和引用
local function RenameAndUpdate(uniqueList, nameMap, items)
  reaper.ClearConsole()
  local errors = {}

  for _, oldPath in ipairs(uniqueList) do
    local newName = nameMap[oldPath]
    local dir     = oldPath:match("^(.*[\\/])") or ""
    local newPath = dir .. newName

    if not FileExists(oldPath) then
      table.insert(errors, "不存在: " .. oldPath)
    else
      -- 重命名
      local ok, err = os.rename(oldPath, newPath)
      if not ok then
        -- 尝试替换斜杠
        ok, err = os.rename(oldPath:gsub("\\","/"), newPath:gsub("\\","/"))
      end
      if not ok then
        table.insert(errors, string.format("失败: %s -> %s (%s)", oldPath, newName, err or "未知"))
      else
        -- 更新每个引用此文件的 Take
        for _, rec in ipairs(items) do
          if rec.oldPath == oldPath then
            reaper.BR_SetTakeSourceFromFile(rec.take, newPath, false)
            if write_take_name then
              reaper.GetSetMediaItemTakeInfo_String(rec.take, "P_NAME", newName:gsub("%.[^%.]+$",""), true)
            end
          end
        end
      end
    end
  end

  return errors
end

-- 主流程
local origState = OfflineSources(items)
local nameMap   = BuildNameMap(uniqueList, baseName, userExt)
local errors    = RenameAndUpdate(uniqueList, nameMap, items)

-- 恢复在线状态 & 刷新波形
for _, rec in ipairs(items) do
  local take = rec.take
  local src  = reaper.GetMediaItemTake_Source(take)
  local wasOnline = origState[take]
  -- 恢复每个 take 对应源文件的在线状态
  reaper.CF_SetMediaSourceOnline(src, wasOnline)
end
reaper.Main_OnCommand(40441, 0) -- Peaks: Rebuild peaks for selected items

-- 恢复选中的对象
RestoreSelectedItems(init_sel_items)
reaper.MarkProjectDirty(0)
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

DisplayRenameLog(uniqueList, nameMap, errors, false)