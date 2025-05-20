-- @description Batch Rename Plus
-- @version 1.0.12
-- @author zaibuyidao
-- @changelog
--   Added mouse-wheel support for switching batch modes.
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

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
-- local ImGui = require 'imgui' '0.9.3.2'
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext('Batch Rename Plus')
local sans_serif = reaper.ImGui_CreateFont('sans-serif', 14)
local font_large = reaper.ImGui_CreateFont("", 20)
local font_medium = reaper.ImGui_CreateFont("", 14)
local font_botton = reaper.ImGui_CreateFont("", 16)
local font_small = reaper.ImGui_CreateFont("", 12)

reaper.ImGui_Attach(ctx, sans_serif)
reaper.ImGui_Attach(ctx, font_large)
reaper.ImGui_Attach(ctx, font_medium)
reaper.ImGui_Attach(ctx, font_botton)
reaper.ImGui_Attach(ctx, font_small)

local preview_font_size  = 14 -- 当前预览字体大小（像素）
local preview_font_sizes = { 8, 10, 12, 14, 16, 18, 20, 22, 24 }
local preview_fonts      = {}
for _, sz in ipairs(preview_font_sizes) do
  preview_fonts[sz] = reaper.ImGui_CreateFont("", sz)
  reaper.ImGui_Attach(ctx, preview_fonts[sz])
end

reaper.ImGui_SetNextWindowSize(ctx, 365, 800, reaper.ImGui_Cond_FirstUseEver())

-- 状态变量
local process_mode           = 0                     -- 0 = Items, 1 = Tracks
local enable_rename          = false                 -- true = enable rename
local enable_replace         = false                 -- true = enable rename
local enable_remove          = false                 -- true = enable rename
local enable_insert          = false                 -- true = enable rename
local rename_pattern         = ""                    -- pattern input
local find_text              = ""                    -- find string
local replace_text           = ""                    -- replace string
local remove_count           = 0                     -- number of chars to remove
local remove_position        = 0                     -- position for removal
local remove_side_index      = 0                     -- 0 = beginning, 1 = end
local insert_text            = ""                    -- text to insert
local insert_position        = 0                     -- position for insertion
local insert_side_index      = 0                     -- 0 = beginning, 1 = end
local use_cycle_mode         = true                  -- cycle mode checkbox
local sort_index             = 0                     -- 0 = Track, 1 = Sequence, 2 = Timeline
local preview_mode           = false                 -- 预览模式默认值
local ignore_case            = false                 -- 是否忽略大小写
local occurrence_mode        = 2                     -- Occurrence 模式：0=First,1=Last,2=All
local write_take_name        = true                  -- true 将新文件名写入 Take 名称，false 保持原 Take 名称
local PREVIEW_TABLE_ID       = "preview_table"       -- 主脚本里共用
local PREVIEW_POPUP_TABLE_ID = "preview_popup_table" -- 弹窗里共用
show_list_window = show_list_window or false
local show_list_data = show_list_data or {}
local show_preview_window = false
local preview_items = {}

--------------------------------------------------------------------------------
-- 用户预设
--------------------------------------------------------------------------------
local presetNames = {}
local selectedPreset = 1 -- 默认为 Reset to factory default
local newPresetName = ""
local showSavePopup = false

-- 重置到初始状态
local function ResetState()
  rename_pattern    = ""
  find_text         = ""
  replace_text      = ""
  remove_count      = 0
  remove_position   = 0
  remove_side_index = 0
  insert_text       = ""
  insert_position   = 0
  insert_side_index = 0
  enable_rename     = false
  enable_replace    = false
  enable_remove     = false
  enable_insert     = false
  ignore_case       = false
  occurrence_mode   = 2 -- All 模式
end

-- 判断表中是否包含某值
local function TableContains(t, val)
  for _,v in ipairs(t) do if v == val then return true end end
  return false
end

-- 读取所有用户预设名
local function LoadPresetList()
  presetNames = {}
  local listStr = reaper.GetExtState("BatchRenamePresets", "__list") or ""
  for name in listStr:gmatch("([^,]+)") do
    if name ~= "" then table.insert(presetNames, name) end
  end
  -- 终把 No preset 放到最前面
  table.insert(presetNames, 1, "No preset")
end

-- 保存用户预设名列表
local function SavePresetList()
  local userNames = {}
  for i=2, #presetNames do -- skip index 1 (恢复出厂设置)
    userNames[#userNames+1] = presetNames[i]
  end
  local listStr = table.concat(userNames, ",")
  reaper.SetExtState("BatchRenamePresets", "__list", listStr, true)
end

-- 将当前状态编码为字符串
local function EncodePreset()
  local data = {
    rename_pattern,
    find_text,
    replace_text,
    tostring(remove_count),
    tostring(remove_position),
    tostring(remove_side_index),
    insert_text,
    tostring(insert_position),
    tostring(insert_side_index),
    enable_rename  and "1" or "0",
    enable_replace and "1" or "0",
    enable_remove  and "1" or "0",
    enable_insert  and "1" or "0",
    ignore_case    and "1" or "0",
    tostring(occurrence_mode),
  }
  return table.concat(data, "\t")
end

-- 应用某条预设（解码并赋值）
local function ApplyPreset(dataStr)
  local params = {}
  for v in dataStr:gmatch("([^\t]*)") do table.insert(params, v) end
  rename_pattern    = params[1] or ""
  find_text         = params[2] or ""
  replace_text      = params[3] or ""
  remove_count      = tonumber(params[4]) or 0
  remove_position   = tonumber(params[5]) or 0
  remove_side_index = tonumber(params[6]) or 0
  insert_text       = params[7] or ""
  insert_position   = tonumber(params[8]) or 0
  insert_side_index = tonumber(params[9]) or 0
  enable_rename     = params[10]=="1"
  enable_replace    = params[11]=="1"
  enable_remove     = params[12]=="1"
  enable_insert     = params[13]=="1"
  ignore_case       = params[14]=="1"
  occurrence_mode   = tonumber(params[15]) or 2
end

-- 通用 ImGui 文本输入对话框
local function ImGui_TextPrompt(ctx, prompt, buf_label, buf_size, callback)
  -- 如果 show 被置为 true 就打开弹窗一次
  if prompt.show then
    reaper.ImGui_OpenPopup(ctx, prompt.id)
    prompt.show = false
  end

  -- 居中弹窗
  local vp = reaper.ImGui_GetWindowViewport(ctx)
  local cx, cy = reaper.ImGui_Viewport_GetCenter(vp)
  reaper.ImGui_SetNextWindowPos(ctx, cx, cy, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

  -- 真正绘制 Modal
  if reaper.ImGui_BeginPopupModal(ctx, prompt.id, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    -- 标题文字
    reaper.ImGui_Text(ctx, prompt.title)
    -- 文本输入框
    local changed
    changed, prompt.buffer = reaper.ImGui_InputText(ctx, buf_label, prompt.buffer, buf_size)
    -- 确定按钮
    if reaper.ImGui_Button(ctx, "OK") then -- ctx, "OK", 120, 0
      callback(prompt.buffer)
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_SameLine(ctx)
    -- 取消按钮
    if reaper.ImGui_Button(ctx, "Cancel") then -- ctx, "OK", 120, 0
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

-- 用于保存预设和重命名预设的两个 prompt 对象
local savePresetPrompt = {
  id     = "Save Preset",
  title  = "Enter a name for the new preset:",
  buffer = "",
  show   = false
}

local renamePresetPrompt = {
  id      = "Rename Preset",
  title   = "Enter a new name for the preset:",
  buffer  = "",
  show    = false,
  oldName = "" -- 用来暂存旧名字
}

-- 预设初始加载
LoadPresetList()
ResetState()

--------------------------------------------------------------------------------
-- 颜色相关
--------------------------------------------------------------------------------
-- 完全透明
local transparent = 0x00000000 -- R=00 G=00 B=00 A=00
local yellow      = 0xFFFF00FF -- 纯黄，RGBA 全不透明
-- 基本色 (100% 不透明)
local white       = 0xFFFFFFFF -- 白色
local black       = 0x000000FF -- 黑色
local red         = 0xFF0000FF -- 红色
local green       = 0x00FF00FF -- 绿色
local blue        = 0x0000FFFF -- 蓝色
local yellow      = 0xFFFF00FF -- 黄色
local cyan        = 0x00FFFFFF -- 青色
local magenta     = 0xFF00FFFF -- 品红
-- 灰度
local gray        = 0x808080FF -- 中灰
local lightGray   = 0xC0C0C0FF -- 浅灰
local darkGray    = 0x404040FF -- 深灰
-- 其他常用色
local orange      = 0xFFA500FF -- 橙色
local purple      = 0x800080FF -- 紫色
local pink        = 0xFFC0CBFF -- 粉色
local brown       = 0xA52A2AFF -- 棕色
local lime        = 0x32CD32FF -- 酸橙绿
local gold        = 0xFFD700FF -- 金色
local silver      = 0xC0C0C0FF -- 银色

-- 预览弹窗
local ext_popup = reaper.GetExtState("BatchRenamePlus", "PopupPreviewOpen")
if ext_popup == "true" then show_preview_window = true
elseif ext_popup == "false" then show_preview_window = false end

-- 预览表格
local default_preview_open = false
local ext = reaper.GetExtState("BatchRenamePlus", "PreviewOpen")
local preview_open = default_preview_open
if ext == "true" then preview_open = true elseif ext == "false" then preview_open = false end
-- 预览表格的 flags1 初始值。如果全部不勾选，则使用flags1 = 0
local tables = {
  disable_indent = false,
  horizontal = {
    flags1 = reaper.ImGui_TableFlags_Resizable()
    -- + reaper.ImGui_TableFlags_ScrollX()
    + reaper.ImGui_TableFlags_ScrollY(),
    flags2 = reaper.ImGui_TableFlags_Resizable(),
    -- + reaper.ImGui_TableFlags_ScrollX()
    -- + reaper.ImGui_TableFlags_ScrollY()
  },
}

function help_marker(desc)
  reaper.ImGui_TextDisabled(ctx, '(?)')
  if reaper.ImGui_BeginItemTooltip(ctx) then
    reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
    reaper.ImGui_Text(ctx, desc)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)
  end
end

local function make_case_insensitive_pattern(str)
  return str:gsub("(%a)", function(c)
    return "["..c:lower()..c:upper().."]"
  end)
end

local function replace_last(s, pat, repl)
  return s:gsub("^(.*)("..pat..")", function(a,b) return a..repl end)
end

local function escape_pattern(str)
  -- 正则元字符转义 ^ $ ( ) % . [ ] + - |
  str = str:gsub("([%^%$%(%)%%%.%[%]%+%-%|])", "%%%1")
  str = str:gsub("%*", ".*")
  str = str:gsub("%?", ".")
  return str
end

local function apply_modifiers(name, i)
  local is_preview = preview_mode
  -- 单值步长: d=START/STEP  → START + (i-1)*STEP
  name = name:gsub("d=(%d+)%/(%d+)", function(s, step)
    local width  = #s
    local start0 = tonumber(s)
    local stp    = tonumber(step)
    local val    = start0 + (i-1) * stp
    return string.format("%0"..width.."d", val)
  end)

  -- 1) 循环步长: d=START-END[/STEP]
  if use_cycle_mode then
    -- 带步长
    name = name:gsub("d=(%d+)%-(%d+)%/(%d+)", function(s,e,step)
      local width  = #s
      local s0, e0 = tonumber(s), tonumber(e)
      local stp    = tonumber(step)
      local rng    = math.abs(e0-s0)+1
      local count  = math.floor((rng+stp-1)/stp)
      local off    = ((i-1)%count)*stp
      local val    = (s0 <= e0) and (s0+off) or (s0-off)
      return string.format("%0"..width.."d", val)
    end)
    -- 不带步长，等同 step=1
    name = name:gsub("d=(%d+)%-(%d+)", function(s, e)
      local len  = #s
      local s0, e0 = tonumber(s), tonumber(e)
      local rng  = math.abs(e0 - s0) + 1
      local off  = (i - 1) % rng
      local val  = (s0 <= e0) and (s0 + off) or (s0 - off)
      return string.format("%0"..len.."d", val)
    end)
    -- 循环模式: 字母区间 A-Z 或 a-z
    name = name:gsub("a=([A-Za-z])%-([A-Za-z])", function(c1, c2)
      local b1, b2 = c1:byte(), c2:byte()
      local rng    = math.abs(b2 - b1) + 1
      local off    = (i - 1) % rng
      local bb     = (b1 <= b2) and (b1 + off) or (b1 - off)
      return string.char(bb)
    end)
  end

  -- 2) 累加单字符: a=X 或 a=x
  name = name:gsub("a=([A-Za-z])", function(c)
    local b    = c:byte()
    local base = (b >= 97 and b <= 122) and 97 or 65
    return string.char(base + ((b - base) + (i - 1)) % 26)
  end)

  -- 3) 累加数字: d=N → N+i-1
  name = name:gsub("d=(%d+)", function(n)
    local len = #n
    local num = tonumber(n) + (i - 1)
    return string.format("%0"..len.."d", num)
  end)

  -- 4) 随机字符串 r=n
  if is_preview then
    name = name:gsub("r=(%d+)", function(n)
      return "random("..n..")"
    end)
  else
    name = name:gsub("r=(%d+)", function(n)
      local cnt = tonumber(n)
      local pool = {}
      for c = 48, 57  do pool[#pool+1] = string.char(c) end
      for c = 65, 90  do pool[#pool+1] = string.char(c) end
      for c = 97, 122 do pool[#pool+1] = string.char(c) end
      local out = {}
      for _ = 1, cnt do out[#out+1] = pool[math.random(#pool)] end
      return table.concat(out)
    end)
  end

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

  return name
end

--表格预览
local function render_preview_table(ctx, id, realCount, row_builder)
  preview_mode = true
  local cnt = realCount

  local hdr_flags = preview_open and reaper.ImGui_TreeNodeFlags_DefaultOpen() or 0
  reaper.ImGui_PushID(ctx, id)
  local is_open = reaper.ImGui_CollapsingHeader(ctx, "Preview##" .. id, nil, hdr_flags)
  preview_open = is_open
  reaper.SetExtState("BatchRenamePlus", "PreviewOpen", tostring(preview_open), true)

  if not is_open then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, string.format("- %d Object(s)", cnt))
    reaper.ImGui_PopID(ctx)
    preview_mode = false
    return
  end

  -- 标题显示总数
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, string.format("- %d Object(s)", cnt))
  -- reaper.ImGui_SeparatorText(ctx, string.format("Preview - %d Object(s)", cnt))

  -- 压缩复选框样式
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local tblFlags1 = tables.horizontal.flags1 or 0
  local ok
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, "Resize", tblFlags1, reaper.ImGui_TableFlags_Resizable())
  reaper.ImGui_SameLine(ctx)
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, "Horizontal Scroll", tblFlags1, reaper.ImGui_TableFlags_ScrollX())
  reaper.ImGui_SameLine(ctx)
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, "Vertical Scroll", tblFlags1, reaper.ImGui_TableFlags_ScrollY())
  tables.horizontal.flags1 = tblFlags1

  -- 恢复复选框样式
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_Separator(ctx)

  -- 开始统计错误数, 如果没有任何选中项就显示 10 行空白
  local displayCount = math.max(cnt, 10)
  local errorCount = 0
  local tableFlags = tblFlags1 + reaper.ImGui_TableFlags_RowBg()
  if reaper.ImGui_BeginTable(ctx, id .. "_table", 3, tableFlags, -1, 127) then
    reaper.ImGui_TableSetupColumn(ctx, "Before", reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, "After", reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, "Message", 0)
    reaper.ImGui_TableHeadersRow(ctx)

    for i = 1, displayCount do
      local before, after = "", ""
      if i <= cnt then
        before, after = row_builder(i)
      end

      -- 输出行
      reaper.ImGui_TableNextRow(ctx)
      if i <= cnt then
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, before)
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, after)
        reaper.ImGui_TableNextColumn(ctx)
        if #after == 0 then
          errorCount = errorCount + 1
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
          reaper.ImGui_Text(ctx, "Error: empty name.")
          reaper.ImGui_PopStyleColor(ctx)
        end
      else
        -- placeholder row
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "Empty slot.")
        reaper.ImGui_PopStyleColor(ctx)
      end
    end

    reaper.ImGui_EndTable(ctx)
    -- 显示错误统计
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
    reaper.ImGui_Text(ctx, string.format("%d error(s) detected.", errorCount))
    reaper.ImGui_PopStyleColor(ctx)
  end
  reaper.ImGui_PopID(ctx)
  preview_mode = false
end

local function render_preview_table_popup(ctx, id, realCount, row_builder)
  preview_mode = true
  local cnt = realCount
  -- reaper.ImGui_SeparatorText(ctx, string.format("Preview - %d Object(s)", cnt))

  -- 压缩复选框样式
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local tblFlags2 = tables.horizontal.flags2 or 0
  tables.horizontal.flags2 = tblFlags2

  -- 恢复复选框样式
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_Separator(ctx)

  -- 开始统计错误数, 如果没有任何选中项就显示 10 行空白
  local displayCount = math.max(cnt, 0)
  local errorCount = 0
  local tableFlags = tblFlags2 + reaper.ImGui_TableFlags_RowBg()
  if reaper.ImGui_BeginTable(ctx, id .. "_table", 3, tableFlags, -1, 0) then
    reaper.ImGui_TableSetupColumn(ctx, "Before", reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, "After", reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, "Message", 0)
    reaper.ImGui_TableHeadersRow(ctx)

    for i = 1, displayCount do
      local before, after = "", ""
      if i <= cnt then
        before, after = row_builder(i)
      end

      -- 输出行
      reaper.ImGui_TableNextRow(ctx)
      if i <= cnt then
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, before)
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, after)
        reaper.ImGui_TableNextColumn(ctx)
        if #after == 0 then
          errorCount = errorCount + 1
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
          reaper.ImGui_Text(ctx, "Error: empty name.")
          reaper.ImGui_PopStyleColor(ctx)
        end
      else
        -- placeholder row
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "Empty slot.")
        reaper.ImGui_PopStyleColor(ctx)
      end
    end

    reaper.ImGui_EndTable(ctx)
    -- 显示错误统计
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
    reaper.ImGui_Text(ctx, string.format("%d error(s) detected.", errorCount))
    reaper.ImGui_PopStyleColor(ctx)
  end
end

--------------------------------------------------------------------------------
-- 源文件 相关函数
--------------------------------------------------------------------------------
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

-- 分离文件名和扩展名
local function SplitNameExt(filename)
  local ext = filename:match("%.[^%.]+$") or ""
  if ext ~= "" then
    return filename:sub(1, #filename - #ext), ext
  else
    return filename, ""
  end
end

local function OfflineSources(items)
  local state = {} -- key: take 对象, value: 离线前是否在线
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

--------------------------------------------------------------------------------
-- 区域/标记相关函数
--------------------------------------------------------------------------------
function GetRegionMarkerManager()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local arr = reaper.new_array({}, 1024)
  reaper.JS_Window_ArrayFind(title, true, arr)
  for _, addr in ipairs(arr.table()) do
    local hwnd = reaper.JS_Window_HandleFromAddress(addr)
    -- 验证这个窗口确实是 Region Manager：检查是否有 ID=1056 的子控件
    if reaper.JS_Window_FindChildByID(hwnd, 1056) then
      return hwnd
    end
  end
end

function get_all_regions_mgr()
  local res = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and isrgn then
      table.insert(res, {
        index   = idx,
        isrgn   = true,
        left    = pos,
        right   = rgnend,
        name    = name,
        color   = color,
      })
    end
  end
  -- 按左边界排序(可选)
  -- table.sort(res, function(a,b) return a.left < b.left end)
  return res
end

function get_all_markers_mgr()
  local res = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    -- 只保留 Marker（isrgn == false）
    if retval and not isrgn then
      table.insert(res, {
        index = idx,
        isrgn = false,
        pos   = pos,
        name  = name,
        color = color,
      })
    end
  end
  -- 按时间位置排序(可选)
  -- table.sort(res, function(a,b) return a.pos < b.pos end)
  return res
end

function get_sel_regions_mgr()
  local hwnd = GetRegionMarkerManager()
  if not hwnd then return {} end
  local container = reaper.JS_Window_FindChildByID(hwnd, 1071) -- ListView 控件
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
  if sel_count == 0 then return {} end

  local all = get_all_regions_mgr()
  local out = {}

  -- sel_indexes 是逗号分隔的行号，直接去读第一列(区域编号)
  for _, row in ipairs( {} ) do end -- 占位用
  for id_str in sel_indexes:gmatch("[^,]+") do
    -- 读取第 1 列: 区域在项目中的索引号
    local txt = reaper.JS_ListView_GetItemText(container, tonumber(id_str), 1)
    local idx = tonumber( txt:match("(%d+)") )
    if idx then
      for _, r in ipairs(all) do
        if r.index == idx then
          table.insert(out, r)
          break
        end
      end
    end
  end
  return out
end

function get_sel_markers_mgr()
  local hwnd = GetRegionMarkerManager()
  if not hwnd then return {} end
  local container = reaper.JS_Window_FindChildByID(hwnd, 1071) -- ListView 控件
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
  if sel_count == 0 then return {} end

  local all = get_all_markers_mgr()
  local out = {}

  for id_str in sel_indexes:gmatch("[^,]+") do
    -- 读取第 1 列: Marker 在项目中的索引号
    local txt = reaper.JS_ListView_GetItemText(container, tonumber(id_str), 1)
    local idx = tonumber(txt:match("(%d+)"))
    if idx then
      for _, m in ipairs(all) do
        if m.index == idx then
          table.insert(out, m)
          break
        end
      end
    end
  end

  return out
end

function set_regions_mgr(region)
  reaper.SetProjectMarker3(
    0,
    region.index,
    region.isrgn,
    region.left,
    region.right,
    region.name,
    region.color
  )
end

function set_markers_mgr(marker)
  reaper.SetProjectMarker3(
    0,
    marker.index,
    marker.isrgn,
    marker.pos,
    marker.pos,
    marker.name,
    marker.color
  )
end

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and isrgn then
      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos,
        right = rgnend,
        name = name,
        color = color
      })
    end
  end
  return result
end

function get_all_markers()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, _, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval and not isrgn then
      table.insert(result, {
        index = markrgnindexnumber,
        pos   = pos,
        name  = name,
        color = color,
      })
    end
  end
  return result
end

function get_sel_regions()
  -- 获取时间选区
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then return {} end

  -- 枚举项目中所有 region
  local out = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, is_region, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and is_region then
      -- 如果 region 完全在选区范围内就保留
      if pos >= sel_start and rgnend <= sel_end then
        table.insert(out, {
          index = idx,
          isrgn = true,
          left  = pos,
          right = rgnend,
          name  = name,
          color = color,
        })
      end
    end
  end
  -- 按 index 或 left 排序 (可选)
  -- table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

function get_sel_markers()
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then return {} end

  local out = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, is_region, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and not is_region then
      if pos >= sel_start and pos <= sel_end then
        table.insert(out, {
          index = idx,
          isrgn = false,
          pos   = pos,
          name  = name,
          color = color,
        })
      end
    end
  end
  -- 按 index 排序 (可选)
  -- table.sort(out, function(a,b) return a.index < b.index end)
  return out
end

function get_sel_regions_for_items()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end

  -- 没选 Items，直接返回空
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then return {} end

  -- 收集所有选中 Item 的时间区间
  local items = {}
  for i = 0, item_count-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    local p  = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    local l  = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    table.insert(items, { left = p, right = p + l })
  end
  -- 合并相交区间
  table.sort(items, function(a,b) return a.left < b.left end)
  local merged = {}
  local cur = { left = items[1].left, right = items[1].right }
  for _, it in ipairs(items) do
    if it.left <= cur.right then
      cur.right = math.max(cur.right, it.right)
    else
      table.insert(merged, cur)
      cur = { left = it.left, right = it.right }
    end
  end
  table.insert(merged, cur)

  -- 对每个合并区间，找出所有 overlap 的 Region
  local sel = {}
  for _, mr in ipairs(merged) do
    for _, r in ipairs(all_regions) do
      if r.left < mr.right and r.right > mr.left then
        sel[r.index] = r
      end
    end
  end

  -- 转成数组并按 index 排序
  local out = {}
  for idx, rgn in pairs(sel) do table.insert(out, rgn) end
  table.sort(out, function(a,b) return a.index < b.index end)
  return out
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

function set_marker(marker)
  reaper.SetProjectMarker3(0, marker.index, false, marker.pos, marker.pos, marker.name, marker.color)
end

--------------------------------------------------------------------------------
-- Build 相关函数 通配符
--------------------------------------------------------------------------------
function build_items(build_pattern, origin_name, tname, track_num, folders, take, i)
  build_pattern = build_pattern or ""
  origin_name   = origin_name   or ""
  tname         = tname         or ""
  track_num     = track_num     or 0
  folders       = folders       or ""
  i             = tonumber(i)   or 1

  -- 通用 token 替换
  local name = build_pattern
  name = name:gsub("%$tracknumber", tostring(track_num))
  name = name:gsub("%$item", origin_name)
  name = name:gsub("%$track", tname)
  name = name:gsub("%$folders", folders)

  local guid = ""
  if take then
    local _, g = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
    guid = g or ""
  end
  name = name:gsub("%$GUID", guid)

  name = apply_modifiers(name, i)
  return name
end

local function build_tracks(pat, origin, guid, num, parent, i)
  pat    = pat    or ""
  origin = origin or ""
  guid   = guid   or ""
  num    = num    or 0
  i      = tonumber(i) or 1

  -- 通用 token 替换
  local name = pat
  name = name:gsub("%$tracknumber", tostring(num))
  name = name:gsub("%$track", origin)
  name = name:gsub("%$GUID", guid)
  name = name:gsub("%$folders", parent or "")

  name = apply_modifiers(name, i)
  return name
end

function build_region_manager(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$regionidx", tostring(i))
  name = name:gsub("%$regionid",  tostring(region_id))
  name = name:gsub("%$region",    origin_name)

  -- 调用 apply_modifiers 支持 d=, a=, r=, e=… 等所有格式化
  name = apply_modifiers(name, i)
  return name
end

local function build_region_time(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$regionidx", tostring(i))
  name = name:gsub("%$regionid",  tostring(region_id))
  name = name:gsub("%$region",    origin_name)

  -- 继承循环/累加/随机等功能
  name = apply_modifiers(name, i)
  return name
end

local function build_region_for_items(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$regionidx", tostring(i))
  name = name:gsub("%$regionid",  tostring(region_id))
  name = name:gsub("%$region",    origin_name)

  -- 继承循环/累加/随机等功能
  name = apply_modifiers(name, i)
  return name
end

function build_marker_manager(pattern, origin_name, marker_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  marker_id   = marker_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$markeridx", tostring(i))
  name = name:gsub("%$markerid",  tostring(marker_id))
  name = name:gsub("%$marker",    origin_name)

  -- 调用 apply_modifiers 支持 d=, a=, r=, e=… 等所有格式化
  name = apply_modifiers(name, i)
  return name
end

local function build_marker_time(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$markeridx", tostring(i))
  name = name:gsub("%$markerid",  tostring(marker_id))
  name = name:gsub("%$marker",    origin_name)

  name = apply_modifiers(name, i)
  return name
end

local function build_marker_time(pattern, origin_name, marker_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  marker_id   = marker_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = pattern
  name = name:gsub("%$markeridx", tostring(i))
  name = name:gsub("%$markerid",  tostring(marker_id))
  name = name:gsub("%$marker",    origin_name)

  name = apply_modifiers(name, i)
  return name
end

function build_sources(build_pattern, origin_name, track_num, i)
  build_pattern = build_pattern or ""
  origin_name   = origin_name   or ""
  track_num     = track_num     or 0
  i             = tonumber(i)   or 1

  -- 通用 token 替换
  local name = build_pattern
  name = name:gsub("%$source", origin_name)

  name = apply_modifiers(name, i)
  return name
end

--------------------------------------------------------------------------------
-- 0 批量重命名Items
--------------------------------------------------------------------------------
local function get_sorted_items_data()
  local cnt = reaper.CountSelectedMediaItems(0)
  local items = {}
  -- 1. 收集原始数据
  for i = 0, cnt-1 do
    local item   = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    local orig = take and reaper.GetTakeName(take) or ""
    local track = reaper.GetMediaItem_Track(item)
    local _, tname = reaper.GetTrackName(track, "")
    local tnum = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)
    local parent = reaper.GetParentTrack(track)
    local folders = parent and select(2, reaper.GetTrackName(parent, "")) or ""
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    table.insert(items, {
      item       = item,
      take       = take,
      orig_name  = orig,
      tname      = tname,
      track_num  = tnum,
      folders    = folders,
      position   = pos
    })
  end
  -- 2. 排序逻辑统一处理
  if sort_index == 0 then
    -- 按轨道排序
    local groups = {}
    for _, d in ipairs(items) do
      groups[d.track_num] = groups[d.track_num] or {}
      table.insert(groups[d.track_num], d)
    end
    local tnums = {}
    for tn in pairs(groups) do table.insert(tnums, tn) end
    table.sort(tnums)
    local sorted = {}
    for _, tn in ipairs(tnums) do
      local grp = groups[tn]
      table.sort(grp, function(a,b) return a.position < b.position end)
      for seq, d in ipairs(grp) do
        d.seqIndex = seq
        table.insert(sorted, d)
      end
    end
    items = sorted
  elseif sort_index == 2 then
    -- 按时间线排序
    table.sort(items, function(a,b)
      if a.position == b.position then return a.track_num < b.track_num end
      return a.position < b.position
    end)
    for i, d in ipairs(items) do d.seqIndex = i end
  else
    -- 按原始 Selection 顺序
    for i, d in ipairs(items) do d.seqIndex = i end
  end
  return items
end

local function apply_batch_items()
  -- 1. 基本检查
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then
    reaper.ShowMessageBox("No media items selected.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  -- 2. 收集数据
  local items = get_sorted_items_data()

  -- 4. 开始 Undo
  reaper.Undo_BeginBlock()
  local changed_any = false

  -- 5. 遍历 items，应用四大功能
  for idx, data in ipairs(items) do
    local new_name = data.orig_name
    local seq = (sort_index == 0 and data.seqIndex) or idx

    -- 5.1 Rename 用 build_items 展开
    if enable_rename then
      new_name = build_items(
        rename_pattern,
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )
    end

    -- 5.2 Replace 也用 build_items 先展开 replace_text
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_items(
        replace_text or "",
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )
      -- 根据 Occurrence 模式执行替换
      if occurrence_mode == 0 then
        -- First: 仅替换首个匹配
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        -- Last: 仅替换最后一个匹配
        new_name = replace_last(new_name, pat, repl)
      else
        -- All: 默认替换所有匹配
        new_name = new_name:gsub(pat, repl)
      end
    end

    -- 5.3 Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name) or #new_name
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      if safe_remove_pos < 0 then safe_remove_pos = 0 end

      local s_i, e_i
      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s_i = safe_remove_pos
          e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e_i = name_length - safe_remove_pos - 1
          s_i = e_i - safe_remove_cnt + 1
          if s_i < 0 then s_i = 0 end
        end
      end

      if s_i then
        local b1 = utf8.offset(new_name, s_i + 1) or 1
        local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
        new_name = string.sub(new_name, 1, b1 - 1) .. string.sub(new_name, b2)
      end
    end

    -- 5.4 Insert 同样先用 build_items 展开 insert_text
    if enable_insert and insert_text ~= "" then
      local insert_str = build_items(
        insert_text,
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )

      local name_length = utf8.len(new_name) or #new_name
      local safe_insert_pos = math.min(insert_position, 100)
      if safe_insert_pos < 0 then safe_insert_pos = 0 end
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = string.sub(new_name, 1, b - 1) .. insert_str .. string.sub(new_name, b)
    end

    -- 6. 写回新名字
    if data.take and new_name ~= data.orig_name then
      reaper.GetSetMediaItemTakeInfo_String(data.take, "P_NAME", new_name, true)
      changed_any = true
    end
  end

  -- 7. 结束 Undo
  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 1 批量重命名Tracks
--------------------------------------------------------------------------------
local function apply_batch_tracks()
  local cnt = reaper.CountSelectedTracks(0)
  if cnt == 0 then
    reaper.ShowMessageBox("No tracks selected.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for i = 0, cnt - 1 do
    local track     = reaper.GetSelectedTrack(0,i)
    local _, origin = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local guid      = reaper.BR_GetMediaTrackGUID(track)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5)
    local parent    = reaper.GetParentTrack(track) and select(2, reaper.GetTrackName(reaper.GetParentTrack(track), "")) or ""
    local new_name  = origin

    -- 1) Rename
    if enable_rename and rename_pattern~="" then
      new_name = build_tracks(rename_pattern, origin, guid, track_num, parent, i + 1)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_tracks(replace_text, origin, guid, track_num, parent, i + 1)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end

    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_tracks(insert_text, origin, guid, track_num, parent, i + 1)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= origin then
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_name, true)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 2 批量重命名 Regions Manager
--------------------------------------------------------------------------------
function apply_batch_region_manager()
  local hWnd = GetRegionMarkerManager()
  if not hWnd then
    reaper.ShowMessageBox(
      "Please open the Region/Marker Manager window first.\n\n" ..
      "In the menu bar, go to: View - Region/marker manager",
      "Batch Rename Plus",
      0
    )
    return
  end
  local regions = get_sel_regions_mgr()
  if #regions == 0 then
    reaper.ShowMessageBox("No regions selected in Region Manager.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig = region.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_manager(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_manager(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_manager(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      region.name = new_name
      set_regions_mgr(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 3 批量重命名 Regions (Time Selection)
--------------------------------------------------------------------------------
local function apply_batch_region_time()
  -- 获取时间选区
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then
    reaper.ShowMessageBox("No time selection.", "Batch Rename Plus", 0)
    return
  end

  -- 获取选区内区域
  local regions = get_sel_regions()
  if #regions == 0 then
    reaper.ShowMessageBox("No regions found in time selection.", "Batch Rename Plus", 0)
    return
  end

  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig = region.name
    local new_name  = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_time(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_time(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_time(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      region.name = new_name
      set_region(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 4 批量重命名 Regions For Items
--------------------------------------------------------------------------------
function apply_batch_regions_for_items()
  local regions = get_sel_regions_for_items()
  if #regions == 0 then
    reaper.ShowMessageBox("No regions found for selected items.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig     = region.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_for_items(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_for_items(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) 插入
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_for_items(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    -- 写回
    if new_name ~= orig then
      region.name = new_name
      set_region(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 5 批量重命名 Markers Manager
--------------------------------------------------------------------------------
function apply_batch_marker_manager()
  local hWnd = GetRegionMarkerManager()
  if not hWnd then
    reaper.ShowMessageBox(
      "Please open the Region/Marker Manager window first.\n\n" ..
      "In the menu bar, go to: View - Region/marker manager",
      "Batch Rename Plus",
      0
    )
    return
  end

  local markers = get_sel_markers_mgr()
  if #markers == 0 then
    reaper.ShowMessageBox("No markers selected in Marker Manager.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, marker in ipairs(markers) do
    local orig     = marker.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_marker_manager(rename_pattern, orig, marker.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_marker_manager(replace_text or "", orig, marker.index, idx)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_marker_manager(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      marker.name = new_name
      set_markers_mgr(marker)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 6 批量重命名 Markers (Time Selection)
--------------------------------------------------------------------------------
local function apply_batch_marker_time()
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then
    reaper.ShowMessageBox("No time selection.", "Batch Rename Plus", 0)
    return
  end
  local markers = get_sel_markers()
  if #markers == 0 then
    reaper.ShowMessageBox("No markers found in time selection.", "Batch Rename Plus", 0)
    return
  end

  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, marker in ipairs(markers) do
    local orig     = marker.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_marker_time(rename_pattern, orig, marker.index, idx)
    end

    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_marker_time(replace_text or "", orig, marker.index, idx)
      if occurrence_mode == 0 then
        new_name = new_name:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = new_name:gsub(pat, repl)
      end
    end

    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end

    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_marker_time(insert_text, orig, marker.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      marker.name = new_name
      set_marker(marker)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock("Batch Rename Plus", -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock("Batch Rename Plus (no changes)", -1)
    reaper.ShowMessageBox("No changes applied - please adjust settings.", "Batch Rename Plus", 0)
  end
end

--------------------------------------------------------------------------------
-- 7 批量重命名 源文件
--------------------------------------------------------------------------------
local function get_sorted_sources_data()
  local cnt   = CountSelectedItems(0)
  local items = {}

  -- 1. 收集原始数据
  for i = 0, cnt-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if not item then goto continue end

    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then goto continue end

    -- 源文件对象及路径
    local src  = reaper.GetMediaItemTake_Source(take)
    local path = reaper.GetMediaSourceFileName(src, "")

    -- 轨道信息
    local track   = reaper.GetMediaItem_Track(item)
    local tnum   = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)

    -- item 在时间线上的位置
    local pos    = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    table.insert(items, {
      item      = item,
      take      = take,
      src       = src,
      path      = path,
      orig_name = path:match("[^\\/]+$") or "",
      track_num = tnum,
      position  = pos,
      seqIndex  = 0,   -- 占位，后面会填
    })

    ::continue::
  end

  -- 2. 排序逻辑
  if sort_index == 0 then
    -- 按轨道分组，再按同轨道内时间线排序
    local groups = {}
    for _, d in ipairs(items) do
      groups[d.track_num] = groups[d.track_num] or {}
      table.insert(groups[d.track_num], d)
    end

    local tnums = {}
    for tn in pairs(groups) do table.insert(tnums, tn) end
    table.sort(tnums)

    local sorted = {}
    for _, tn in ipairs(tnums) do
      local grp = groups[tn]
      table.sort(grp, function(a,b) return a.position < b.position end)
      for seq, d in ipairs(grp) do
        d.seqIndex = seq
        table.insert(sorted, d)
      end
    end
    items = sorted

  elseif sort_index == 2 then
    -- 跨轨道时间线排序
    table.sort(items, function(a,b)
      if a.position == b.position then return a.track_num < b.track_num end
      return a.position < b.position
    end)
    for i, d in ipairs(items) do d.seqIndex = i end

  else
    -- 原始选中顺序
    for i, d in ipairs(items) do d.seqIndex = i end
  end

  return items
end

local function apply_batch_sources()
  -- 基本检查
  local sel_cnt = CountSelectedItems(0)
  if sel_cnt == 0 then
    reaper.ShowMessageBox("No media items selected.", "Batch Rename Plus", 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox("No options selected - please check at least one feature.", "Batch Rename Plus", 0)
    return
  end

  -- 保存当前选中状态，禁用界面刷新并开始 Undo
  local init_sel_items = {}
  SaveSelectedItems(init_sel_items)
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  local src_paths = CollectSelectedSourcePaths()
  SelectItemsBySourcePaths(src_paths)

  -- 收集并排序所有源文件数据
  local items = get_sorted_sources_data()

  -- 构建唯一源列表（每条路径只保留一次）
  local seen_paths = {}
  local uniqueRecs = {}
  for _, d in ipairs(items) do
    if not seen_paths[d.path] then
      seen_paths[d.path] = true
      table.insert(uniqueRecs, d)
    end
  end

  -- 轨道和时间线排序，基于选中的item的源文件数量。
  if sort_index == 1 or sort_index == 2 then
    for i, rec in ipairs(uniqueRecs) do
      rec.seqIndex = i
    end
  end

  -- 用 build_sources + replace/删除/插入 生成 nameMap
  local nameMap = {}
  for _, rec in ipairs(uniqueRecs) do
    -- 拆分文件名/扩展
    local filename = rec.path:match("[^\\/]+$") or ""
    local base, ext = filename:match("(.+)(%.[^%.]+)$")
    local seq = rec.seqIndex
    if not base then base, ext = filename, "" end

    -- Rename
    local new_base = base
    if enable_rename and rename_pattern ~= "" then
      new_base = build_sources(rename_pattern, base, rec.track_num, seq)
    end

    -- Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if ignore_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_sources(replace_text, base, rec.track_num, seq)
      if occurrence_mode == 0 then
        new_base = new_base:gsub(pat, repl, 1)
      elseif occurrence_mode == 1 then
        new_base = replace_last(new_base, pat, repl)
      else
        new_base = new_base:gsub(pat, repl)
      end
    end

    -- Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_base) or #new_base
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      if safe_remove_pos < 0 then safe_remove_pos = 0 end

      local s_i, e_i
      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s_i = safe_remove_pos
          e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e_i = name_length - safe_remove_pos - 1
          s_i = e_i - safe_remove_cnt + 1
          if s_i < 0 then s_i = 0 end
        end
      end

      if s_i then
        local b1 = utf8.offset(new_base, s_i + 1) or 1
        local b2 = utf8.offset(new_base, e_i + 2) or (#new_base + 1)
        new_base = string.sub(new_base, 1, b1 - 1) .. string.sub(new_base, b2)
      end
    end

    -- Insert
    if enable_insert and insert_text ~= "" then
      local insert_str = build_sources(insert_text, base, rec.track_num, seq)
      local name_length = utf8.len(new_base) or #new_base
      local safe_insert_pos = math.min(insert_position, 100)
      if safe_insert_pos < 0 then safe_insert_pos = 0 end
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_base, insert_i + 1) or (#new_base + 1)
      new_base = string.sub(new_base, 1, b - 1) .. insert_str .. string.sub(new_base, b)
    end

    nameMap[rec.path] = new_base .. ext
  end

  -- 冲突修复(同名加 -001, -002...)
  local count_seen = {}
  for _, rec in ipairs(uniqueRecs) do
    local nm = nameMap[rec.path]
    count_seen[nm] = (count_seen[nm] or 0) + 1
    if count_seen[nm] > 1 then
      local ext = nm:match("(%.[^%.]+)$") or ""
      local base = nm:sub(1, #nm - #ext)
      nameMap[rec.path] = base .. string.format("-%03d", count_seen[nm]-1) .. ext
    end
  end

  -- 离线所有源、执行重命名并更新引用
  local origState = OfflineSources(items)
  local errors = {}
  for _, rec in ipairs(uniqueRecs) do
    local oldPath = rec.path
    local newName = nameMap[oldPath]
    local dir     = oldPath:match("^(.*[\\/])") or ""
    local newPath = dir .. newName

    if not FileExists(oldPath) then
      table.insert(errors, "Does not exist: " .. oldPath)
    else
      local ok, err = os.rename(oldPath, newPath)
      if not ok then
        ok, err = os.rename(oldPath:gsub("\\","/"), newPath:gsub("\\","/"))
      end
      if ok then
        -- 更新所有引用相同源的 take
        for _, d in ipairs(items) do
          if d.path == oldPath then
            reaper.BR_SetTakeSourceFromFile(d.take, newPath, false)
            if write_take_name then
              -- 使用没有后缀的命名
              -- local onlyName = newName:gsub("%.[^%.]+$", "")
              -- reaper.GetSetMediaItemTakeInfo_String(d.take, "P_NAME", onlyName, true)
              reaper.GetSetMediaItemTakeInfo_String(d.take, "P_NAME", newName, true)
            end
          end
        end
      else
        table.insert(errors, string.format("Failed: %s <--> %s (%s)", oldPath, newName, err or "Unknown"))
      end
    end
  end

  -- 恢复在线状态、重建波形、还原选中、结束 Undo、刷新
  for _, d in ipairs(items) do
    local src = reaper.GetMediaItemTake_Source(d.take)
    reaper.CF_SetMediaSourceOnline(src, origState[d.take])
  end
  reaper.Main_OnCommand(40441, 0) -- Peaks: Rebuild peaks for selected items
  RestoreSelectedItems(init_sel_items)
  reaper.Undo_EndBlock("Batch Rename Plus", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.MarkProjectDirty(0) -- 工程改动提示

  -- 打印错误日志
  if #errors > 0 then
    reaper.ShowConsoleMsg("\n---- Renaming completed, the following errors occurred: ----\n")
    for _, e in ipairs(errors) do
      reaper.ShowConsoleMsg(e .. "\n")
    end
  end
end

local function apply_batch_rename()
  if process_mode == 0 then
    -- Items 模式
    -- local cnt = reaper.CountSelectedMediaItems(0)
    -- if cnt == 0 then reaper.ShowMessageBox("No items selected.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_items()
  elseif process_mode == 1 then
    -- Tracks 模式
    -- local cnt = reaper.CountSelectedTracks(0)
    -- if cnt == 0 then reaper.ShowMessageBox("No tracks selected.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_tracks()
  elseif process_mode == 2 then
    -- Region Manager 模式
    apply_batch_region_manager()
  elseif process_mode == 3 then
    -- Regions (Time Selection) 模式
    -- local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    -- if sel_start == sel_end then reaper.ShowMessageBox("No time selection.", "Error", 0) return end
    -- local regions = get_sel_regions()
    -- if #regions == 0 then reaper.ShowMessageBox("No regions found in time selection.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_region_time()
  elseif process_mode == 4 then
    apply_batch_regions_for_items()
  elseif process_mode == 5 then
    apply_batch_marker_manager()
  elseif process_mode == 6 then
    apply_batch_marker_time()
  elseif process_mode == 7 then
    apply_batch_sources()
  end
end

--------------------------------------------------------------------------------
-- 表格预览和构建
--------------------------------------------------------------------------------
local function get_preview_data_and_builder()
  local data, builder
  if process_mode == 0 then
    data = get_sorted_items_data()
    builder =  function(i)
      local rec     = data[i]
      local orig     = rec.orig_name
      local seq      = rec.seqIndex
      local new_name = orig

      -- 1) Rename
      if enable_rename then
        new_name = build_items(rename_pattern, orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_items(replace_text or "", orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_items(insert_text, orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Tracks
  elseif process_mode == 1 then
    data = {}
    for ti = 0, reaper.CountSelectedTracks(0)-1 do
      data[#data+1] = reaper.GetSelectedTrack(0, ti)
    end
    builder = function(i)
      local track    = data[i]
      local _, orig  = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      local guid     = reaper.BR_GetMediaTrackGUID(track)
      local num      = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5)
      local parent = reaper.GetParentTrack(track) and select(2, reaper.GetTrackName(reaper.GetParentTrack(track), "")) or ""
      local seq      = i
      local new_name  = orig

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_tracks(rename_pattern, orig, guid, num, parent, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_tracks(replace_text, orig, guid, num, parent, seq)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_tracks(insert_text, orig, guid, num, parent, seq)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Region Manager
  elseif process_mode == 2 then
    data = get_sel_regions_mgr()
    builder = function(i)
      local region   = data[i]
      local orig     = region.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_manager(rename_pattern, orig, region.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_manager(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end

      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end

      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_manager(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Regions (Time Selection)
  elseif process_mode == 3 then
    data = get_sel_regions()
    builder = function(i)
      local region = data[i]
      local orig = region.name
      local new_name  = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_time(rename_pattern, orig, region.index, i)
      end

      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_time(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_time(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Regions for Selected Items
  elseif process_mode == 4 then
    data = get_sel_regions_for_items()
    builder = function(i)
      local region   = data[i]
      local orig     = region.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_for_items(rename_pattern, orig, region.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_for_items(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
  
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
  
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_for_items(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Marker Manager
  elseif process_mode == 5 then
    data = get_sel_markers_mgr()
    builder = function(i)
      local marker   = data[i]
      local orig     = marker.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_marker_manager(rename_pattern, orig, marker.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_marker_manager(replace_text or "", orig, marker.index, i)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
  
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
  
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_marker_manager(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Marker (Time Selection)
  elseif process_mode == 6 then
    data = get_sel_markers()
    builder = function(i)
      local marker   = data[i]
      local orig     = marker.name
      local new_name = orig

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_marker_time(rename_pattern, orig, marker.index, i)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_marker_time(replace_text or "", orig, marker.index, i)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_marker_time(insert_text, orig, marker.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Source Files (Selected Items)
  elseif process_mode == 7 then
    data = get_sorted_sources_data()
    builder = function(i)
      local data     = data[i]
      local orig     = data.orig_name
      local seq      = data.seqIndex
      local new_name = orig

      -- 1) Rename
      if enable_rename then
        new_name = build_sources(rename_pattern, orig, data.track_num, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_sources(replace_text or "", orig, data.track_num, seq)
        if occurrence_mode == 0 then
          new_name = new_name:gsub(pat, repl, 1)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = new_name:gsub(pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_sources(insert_text, orig, data.track_num, seq)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end
  else
    data = {}
    builder = function() return "", "" end
  end
  return data, builder
end

-- function transparent_link(ctx, label, url)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

--   if reaper.ImGui_Button(ctx, label) then
--     -- 在默认浏览器中打开指定链接
--     reaper.CF_ShellExecute(url)
--   end

--   reaper.ImGui_PopStyleColor(ctx, 3)
-- end

function transparent_link(ctx, label, url)
  -- 推入透明按钮样式
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  -- 计算按钮高度，让文字垂直居中
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, label)
  local button_h  = text_h + pad_y * 3.5

  -- 宽度设为 0 (自动)，高度设为 button_h
  if reaper.ImGui_Button(ctx, label, 0, button_h) then
    -- 在默认浏览器中打开指定链接
    reaper.CF_ShellExecute(url)
  end
  -- 弹出样式
  reaper.ImGui_PopStyleColor(ctx, 3)
end

function support_popup(ctx)
  -- reaper.ImGui_PushFont(ctx, font_small)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, "Support")
  local button_h  = text_h + pad_y * 3.5

  if reaper.ImGui_Button(ctx, "Support", 0, button_h) then
    reaper.ImGui_OpenPopup(ctx, "Support")
  end

  -- reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 3)

  -- 弹窗内容
  if reaper.ImGui_BeginPopupModal(ctx, "Support", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(ctx, "This tool is free and open source. And it will always be.")
    reaper.ImGui_Text(ctx, "However, I do appreciate your support via donation.")
    reaper.ImGui_Separator(ctx)

    -- “Visit” 透明按钮
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
    if reaper.ImGui_Button(ctx, "Visit soundengine.cn") then
      reaper.CF_ShellExecute("https://www.soundengine.cn")
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_Separator(ctx)
    -- 关闭按钮
    if reaper.ImGui_Button(ctx, "Close") then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

-- 旧版手动管理flag
local function preview_popup(ctx)
  -- “Preview” 按钮
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          yellow)

  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, label)
  local button_h  = text_h + pad_y * 3.5

  if reaper.ImGui_Button(ctx, "Preview##Menu", 0, button_h) then
    show_preview_window = true
  end
  reaper.ImGui_PopStyleColor(ctx, 4)

  -- 弹窗逻辑
  if show_preview_window then
    -- 首次打开时设置尺寸
    reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
    local data, builder = get_preview_data_and_builder()
    local visible, open = reaper.ImGui_Begin(ctx, "Preview Panel", show_preview_window)
    --reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, string.format("Preview - %d Object(s)", #data))
    show_preview_window = open
    -- 保存当前状态到 ExtState，下次脚本启动时恢复
    reaper.SetExtState("BatchRenamePlus", "PopupPreviewOpen", tostring(show_preview_window), true)
    if visible then
      -- 字体大小输入框（只能选预设尺寸）
      -- reaper.ImGui_SameLine(ctx)
      reaper.ImGui_PushItemWidth(ctx, -60)
      local changed, new_sz = reaper.ImGui_InputInt(
        ctx,
        "Font px",
        preview_font_size,
        2,   -- step
        10   -- fast step (Ctrl+箭头)
      )
      if changed then
        -- 限制为预设列表中的值
        for _, v in ipairs(preview_font_sizes) do
          if v == new_sz then preview_font_size = v break end
        end
      end

      -- 选用已 attach 的字体
      local f = preview_fonts[preview_font_size] or preview_fonts[12]
      reaper.ImGui_PushFont(ctx, f)

      -- 渲染预览表格
      -- local data, builder = get_preview_data_and_builder()
      render_preview_table_popup(ctx, PREVIEW_POPUP_TABLE_ID, #data, builder)

      reaper.ImGui_PopFont(ctx)
      reaper.ImGui_End(ctx)
    end
  end
end

function open_region_marker_manager(ctx, label)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

  if reaper.ImGui_Button(ctx, label) then
    reaper.Main_OnCommand(40326, 0) -- View: Region/marker manager
  end
  reaper.ImGui_PopStyleColor(ctx, 3)
end

local function get_file_name(path)
  if not path then return "" end
  if reaper.GetOS():match("Win") then
    return path:match(".*\\([^\\]+)$") or path
  else
    return path:match(".*/([^/]+)$") or path
  end
end

-- 修复 Item vs Source 列表空文件名问题，兼容 SECTION 类型
local function gather_show_list_data()
  local data = {}
  local count_sel = CountSelectedItems(0) -- reaper.CountSelectedMediaItems(0)
  -- 按开始位置分组
  local startEvents = {}
  for i = 0, count_sel - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local name = reaper.GetTakeName(take)
      startEvents[pos] = startEvents[pos] or {}
      table.insert(startEvents[pos], { item = item, take_name = name })
    end
  end

  -- 对开始位置排序
  local starts = {}
  for pos in pairs(startEvents) do table.insert(starts, pos) end
  table.sort(starts)

  -- 自定义函数：获取真实文件路径，兼容 SECTION 类型和 SWS
  local function get_full_path(src)
    -- 核心 API
    local full = reaper.GetMediaSourceFileName(src, "") or ""
    -- SECTION 类型：取父源
    if full == "" then
      local st = reaper.GetMediaSourceType(src, "") or ""
      if st == "SECTION" and reaper.GetMediaSourceParent then
        local parent = reaper.GetMediaSourceParent(src)
        if parent then
          full = reaper.GetMediaSourceFileName(parent, "") or ""
        end
      end
    end
    -- SWS 扩展回退
    if full == "" and reaper.BR_GetMediaSourceFileName then
      full = reaper.BR_GetMediaSourceFileName(src) or ""
    end
    return full
  end

  -- 扁平化并提取文件名
  for _, pos in ipairs(starts) do
    for _, ev in ipairs(startEvents[pos]) do
      local take   = reaper.GetActiveTake(ev.item)
      local source = reaper.GetMediaItemTake_Source(take)
      local full   = get_full_path(source)
      local filename = get_file_name(full)
      table.insert(data, { take_name = ev.take_name, file_name = filename })
    end
  end

  return data
end

local function item_vs_source()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

  -- 取 FramePadding 的垂直值，用来计算按钮高度
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, label)
  local button_h  = text_h + pad_y * 3.5

  if reaper.ImGui_Button(ctx, "Item vs Source", 0, button_h) then
    local cnt = reaper.CountSelectedMediaItems(0)
    if cnt > 0 then
      show_list_data   = gather_show_list_data()
      show_list_window = true
    else
      reaper.ShowMessageBox("No items selected.\nPlease select at least one media item.", "Batch Rename Plus", 0)
    end
  end
  reaper.ImGui_PopStyleColor(ctx, 3)

  if show_list_window then
    reaper.ImGui_SetNextWindowSize(ctx, 600, 300, reaper.ImGui_Cond_FirstUseEver())
    local title = string.format("Item vs Source List - %d Object(s)", #show_list_data)
    local visible, open = reaper.ImGui_Begin(ctx, title, show_list_window)
    show_list_window = open
    if visible then
      -- 把可拖拽标志合入 table_flags
      local table_flags =
          reaper.ImGui_TableFlags_Borders()     -- 带边框
        + reaper.ImGui_TableFlags_Resizable()   -- 可拖拽列分隔
  
      if reaper.ImGui_BeginTable(ctx, "show_list_table", 3, table_flags) then
        -- 第一列固定宽度
        reaper.ImGui_TableSetupColumn(ctx, "Index",
          reaper.ImGui_TableColumnFlags_WidthFixed(), 50)
        -- 后两列伸展但依然可调整
        reaper.ImGui_TableSetupColumn(ctx, "Item Name",
          reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
        reaper.ImGui_TableSetupColumn(ctx, "Source Name",
          reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
  
        reaper.ImGui_TableHeadersRow(ctx)
  
        -- for i, entry in ipairs(show_list_data) do
        --   reaper.ImGui_TableNextRow(ctx)
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, tostring(i))
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, entry.take_name)
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, entry.file_name)
        -- end
        
        k = tostring(#show_list_data)
        k = #k
        -- 支持Ctrl+鼠标左键点击复制栏目内容
        for i, entry in ipairs(show_list_window and show_list_data or {}) do
          reaper.ImGui_TableNextRow(ctx)
          -- 序号列
          reaper.ImGui_TableNextColumn(ctx)
          local idx_str = string.format("%0" .. k .. "d", i)
          reaper.ImGui_Text(ctx, idx_str)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(idx_str)
          end

          -- Item Name 列
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, entry.take_name)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(entry.take_name)
          end

          -- Source Name 列
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, entry.file_name)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(entry.file_name)
          end
        end
  
        reaper.ImGui_EndTable(ctx)
      end

      if reaper.ImGui_Button(ctx, "Copy to Clipboard") then
        local lines = {}
        for i, entry in ipairs(show_list_data) do
          -- 格式：[序号]   项目名称   源文件名称
          lines[#lines+1] = string.format("[%d]\t%s\t%s", i, entry.take_name, entry.file_name)
        end
        local clip = table.concat(lines, "\n")
        reaper.CF_SetClipboard(clip)
      end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, "Copy Items Only") then
        local lines = {}
        for _, entry in ipairs(show_list_data) do
          lines[#lines+1] = entry.take_name
        end
        reaper.CF_SetClipboard(table.concat(lines, "\n"))
      end
      reaper.ImGui_SameLine(ctx)
      help_marker(
        "Use Ctrl+LeftClick to copy cell content\n"
      )

      reaper.ImGui_End(ctx)
    end
  end
end

local function draw_wildcards(ctx, button_label, popup_id, target)
  -- 占位符按钮
  local mode_labels = {
    "Items",
    "Tracks",
    "Regions",
    "Markers",
    "Sourse Files",
  }
  local wildcards_by_mode = {
    [0] = { "$item", "$track", "$tracknumber", "$folders", "$GUID" },
    [1] = { "$track", "$tracknumber", "$folders", "$GUID" },
    [2] = { "$region", "$regionid", "$regionidx" },
    [3] = { "$marker", "$markerid", "$markeridx" },
    [4] = { "$source" },
  }

  reaper.ImGui_SameLine(ctx)
  -- 透明按钮，仅文字
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          reaper.ImGui_ColorConvertDouble4ToU32(0,0.5,0,1))
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, button_label) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)
  
  if reaper.ImGui_BeginPopup(ctx, popup_id) then
    -- 一级菜单：各模式
    for idx, modeName in ipairs(mode_labels) do
      if reaper.ImGui_BeginMenu(ctx, modeName) then
        -- 二级菜单：对应通配符
        for _, wc in ipairs(wildcards_by_mode[idx-1] or {}) do
          if reaper.ImGui_MenuItem(ctx, wc) then
            if target == "rename" then
              if rename_pattern ~= "" then rename_pattern = rename_pattern .. wc else rename_pattern = wc end
            elseif target == "replace" then
              if replace_text ~= "" then replace_text = replace_text .. wc else replace_text = wc end
            elseif target == "insert" then
              if insert_text ~= "" then insert_text = insert_text .. wc else insert_text = wc end
            end
          end
        end
        reaper.ImGui_EndMenu(ctx)
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

local function draw_specifiers(ctx, button_label, popup_id, target)
  -- 格式说明符按钮
  reaper.ImGui_SameLine(ctx)
  local specifiers = { "d=0001", "d=01-03", "d=10/2", "d=01-10/2", "a=a", "a=a-c", "r=5", "e=ABC|BCD|CDE;" }

  -- 将按钮背景设为透明，仅保留文字
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          reaper.ImGui_ColorConvertDouble4ToU32(0, 0.5, 0, 1))
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, button_label) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)

  if reaper.ImGui_BeginPopup(ctx, popup_id) then
    -- reaper.ImGui_SeparatorText(ctx, "Specifiers")
    for _, wc in ipairs(specifiers) do
      if reaper.ImGui_Selectable(ctx, wc) then
        if target == "rename" then
          if rename_pattern ~= "" then rename_pattern = rename_pattern .. wc else rename_pattern = wc end
        elseif target == "replace" then
          if replace_text ~= "" then replace_text = replace_text .. wc else replace_text = wc end
        elseif target == "insert" then
          if insert_text ~= "" then insert_text = insert_text .. wc else insert_text = wc end
        end
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

local function frame()
  reaper.ImGui_PushFont(ctx, font_large)
  reaper.ImGui_Text(ctx, 'Batch Rename Plus')
  reaper.ImGui_PopFont(ctx)

  -- Item vs Source List 弹窗
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushFont(ctx, font_small)
  item_vs_source()
  reaper.ImGui_PopFont(ctx)

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushFont(ctx, font_small)
  preview_popup(ctx)
  reaper.ImGui_PopFont(ctx)

  -- reaper.ImGui_PushFont(ctx, font_small)
  -- reaper.ImGui_SameLine(ctx)
  -- support_popup(ctx)
  -- reaper.ImGui_PopFont(ctx)

  -- reaper.ImGui_SameLine(ctx)
  -- reaper.ImGui_PushFont(ctx, font_small)
  -- transparent_link(ctx, "Zaibuyidao", "https://www.soundengine.cn")
  -- reaper.ImGui_PopFont(ctx)

  -- reaper.ImGui_SameLine(ctx)
  -- reaper.ImGui_PushFont(ctx, font_small)
  -- -- reaper.ImGui_Text(ctx, 'Script by zaibuyidao v1.0')
  -- reaper.ImGui_TextColored(ctx, reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 0.5), 'Advanced renaming for REAPER')
  -- reaper.ImGui_PopFont(ctx)

  reaper.ImGui_PushItemWidth(ctx, -90)
  reaper.ImGui_Separator(ctx)
  -- 用户预设
  local comboLabel = (selectedPreset == 1) and "No preset" or presetNames[selectedPreset]
  if reaper.ImGui_BeginCombo(ctx, "##Presets", comboLabel) then
    -- 1. Reset to factory default
    if reaper.ImGui_Selectable(ctx, "Reset to factory default", false) then
      selectedPreset = 1
      ResetState()
    end

    -- 2. 如果当前选中 Reset to factory default, 就在下面显示提示文本 No preset
    -- if selectedPreset == 1 then
    --   reaper.ImGui_TextDisabled(ctx, "No preset") -- 灰色
    --   -- reaper.ImGui_Text(ctx, "No preset")
    -- end

    -- 3. 列出所有用户预设（从 index=2 开始）
    for i = 2, #presetNames do
      local name = presetNames[i]
      local isSel = (selectedPreset == i)
      if reaper.ImGui_Selectable(ctx, name, isSel) then
        selectedPreset = i
        local dataStr = reaper.GetExtState("BatchRenamePresets", name)
        if dataStr and dataStr ~= "" then
          ApplyPreset(dataStr)
        end
      end
    end

    reaper.ImGui_EndCombo(ctx)
  end

  reaper.ImGui_SameLine(ctx)
  -- 管理预设按钮
  if reaper.ImGui_Button(ctx, " + ##PresetManagerBtn") then
    reaper.ImGui_OpenPopup(ctx, "PresetManagerPopup")
  end

  -- 管理预设列表
  if reaper.ImGui_BeginPopup(ctx, "PresetManagerPopup") then
    local canModify = (selectedPreset > 1)

    -- 1. 保存预设，始终可用
    -- if reaper.ImGui_MenuItem(ctx, "Save Preset...", nil, false, true) then
    --   newPresetName = ""
    --   showSavePopup = true
    -- end

    if reaper.ImGui_MenuItem(ctx, "Save Preset...", nil, false, true) then
      savePresetPrompt.buffer = ""
      savePresetPrompt.show   = true
    end

    -- 2. 删除预设
    if reaper.ImGui_MenuItem(ctx, "Delete Preset", nil, false, canModify) then
      local nameToDel = presetNames[selectedPreset]
      table.remove(presetNames, selectedPreset)
      SavePresetList()
      reaper.DeleteExtState("BatchRenamePresets", nameToDel, true)
      selectedPreset = 1
      ResetState()
    end

    -- 3. 重命名预设
    if reaper.ImGui_MenuItem(ctx, "Rename Preset...", nil, false, canModify) then
      renamePresetPrompt.oldName = presetNames[selectedPreset]
      renamePresetPrompt.buffer  = renamePresetPrompt.oldName
      renamePresetPrompt.show    = true
    end

    -- 4. 导出所有用户预设
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, "Export Presets") then
      local filter = "Text Files (*.txt)\0*.txt\0All Files\0*.*\0"
      local retval, file = reaper.JS_Dialog_BrowseForSaveFile(
        "Export Presets", -- 标题
        "",               -- 初始路径
        filter,           -- 过滤器
        "txt"             -- 默认后缀，不含点
      )
      -- retval==1 表示用户点了保存
      if retval == 1 and file and file ~= "" then
        -- 如果用户没加后缀就补 .txt
        if not file:match("%.[^%.]+$") then file = file .. ".txt" end
        local f, err = io.open(file, "w")
        if not f then
          reaper.MB("Failed to open file for writing:\n" .. err, "Error", 0)
        else
          for i = 2, #presetNames do
            local name = presetNames[i]
            local data = reaper.GetExtState("BatchRenamePresets", name) or ""
            f:write(name, "\t", data, "\n")
          end
          f:close()
          reaper.MB("Exported "..(#presetNames-1).." presets to:\n"..file, "Export Presets", 0)
        end
      end
    end
    -- 5. 导入用户预设
    if reaper.ImGui_MenuItem(ctx, "Import Presets") then
      local r1, r2 = reaper.GetUserFileNameForRead("", "Import Presets", "*.txt")
      local file
      if type(r1)=="string" then
        file = r1
      elseif type(r2)=="string" then
        file = r2
      end
      -- 如果用户取消或结果不是字符串就跳过
      if not file or file == "" then
        -- 无操作
      else
        local f, err = io.open(file, "r")
        if not f then
          reaper.MB("Failed to open file for reading:\n" .. err, "Error", 0)
        else
          local count = 0
          for line in f:lines() do
            local name, data = line:match("([^\t]+)\t?(.*)")
            if name and name ~= "" and name ~= presetNames[1] then
              if not TableContains(presetNames, name) then
                table.insert(presetNames, name)
              end
              reaper.SetExtState("BatchRenamePresets", name, data or "", true)
              count = count + 1
            end
          end
          f:close()
          SavePresetList()
          reaper.MB("Imported "..count.." presets from:\n"..file, "Import Presets", 0)
        end
      end
    end

    reaper.ImGui_EndPopup(ctx)
  end

  -- Save Preset 对话框
  ImGui_TextPrompt(ctx, savePresetPrompt, "##savePresetInput", 128, function(name)
    -- 确认保存时的回调
    -- 1. 插入新预设名
    table.insert(presetNames, name)
    SavePresetList()
    -- 2. 写入当前设置
    local dataStr = EncodePreset()
    reaper.SetExtState("BatchRenamePresets", name, dataStr, true)
    -- 3. 选中刚创建的预设
    for i,n in ipairs(presetNames) do
      if n == name then selectedPreset = i; break end
    end
  end)
  -- Rename Preset 对话框
  ImGui_TextPrompt(ctx, renamePresetPrompt, "##renamePresetInput", 128, function(name)
    local old = renamePresetPrompt.oldName
    if old and old ~= name then
      -- 1. 读取并迁移数据
      local dataStr = reaper.GetExtState("BatchRenamePresets", old)
      reaper.DeleteExtState("BatchRenamePresets", old, true)
      reaper.SetExtState("BatchRenamePresets", name, dataStr or "", true)
      -- 2. 更新列表
      presetNames[selectedPreset] = name
      SavePresetList()
    end
  end)

  reaper.ImGui_SeparatorText(ctx, 'Settings')
  if process_mode == 0 then
    example_text = "Example: $item_d=0001_a=E-A_r=4"
  elseif process_mode == 1 then
    example_text = "Example: $track_d=0001_a=E-A_r=4"
  elseif process_mode == 2 then
    example_text = "Example: $region_d=0001_a=E-A_r=4"
  elseif process_mode == 3 then
    example_text = "Example: $region_d=0001_a=E-A_r=4"
  elseif process_mode == 4 then
    example_text = "Example: $region_d=0001_a=E-A_r=4"
  elseif process_mode == 5 then
    example_text = "Example: $marker_d=0001_a=E-A_r=4"
  elseif process_mode == 6 then
    example_text = "Example: $marker_d=0001_a=E-A_r=4"
  elseif process_mode == 7 then
    example_text = "Example: $source_d=0001_a=E-A_r=4"
  end

  -- 1) Rename
  local ch_n, new_n = reaper.ImGui_Checkbox(ctx, "Rename", enable_rename)
  if ch_n then enable_rename = new_n end

  if enable_rename then
    draw_wildcards(ctx, 'Wildcards##1', 'wildcards_popup##1', 'rename')
    draw_specifiers(ctx, 'Specifiers##1', 'item_mode_specifiers##1', 'rename')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_rename)
  local ch_p, newPattern = reaper.ImGui_InputTextWithHint(
    ctx,
    "Pattern",
    example_text,
    rename_pattern
  )

  if ch_p then rename_pattern = newPattern end
  reaper.ImGui_EndDisabled(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)

  help_marker(
    "Items wildcards: \n" ..
    "$item for item name, $track for track name, $tracknumber for track number, $folders for track folder, $GUID for unique identifier.\n\n" ..
    "Tracks wildcards: \n" ..
    "$track for track name, $tracknumber for track number, $folders for track folder, $GUID for unique identifier.\n\n" ..
    "General tags: d=n for number increment, d=start-end for number cycle, a=c for letter increment, a=start-end for letter cycle, r=n for random string.\n\n" ..
    "Modes: rename, replace, remove or insert. Enable cycle mode to loop numbers or letters. Sorting options: track, sequential or timeline."
  )
  reaper.ImGui_Separator(ctx)

  -- 2) Replace
  local ch_rp, new_rp = reaper.ImGui_Checkbox(ctx, "Replace", enable_replace)
  if ch_rp then enable_replace = new_rp end

  if enable_replace then
    draw_wildcards(ctx, 'Wildcards##2', 'wildcards_popup##2', 'replace')
    draw_specifiers(ctx, 'Specifiers##2', 'item_mode_specifiers##2', 'replace')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_replace)
  local ch_f, new_find = reaper.ImGui_InputText(ctx, "Find what##find", find_text or "")
  if ch_f then find_text = new_find end
  local ch_w, new_repl = reaper.ImGui_InputText(ctx, "Replace with##repl", replace_text or "")
  if ch_w then replace_text = new_repl end

  -- 忽略大小写选项
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local ch_ic, new_ic = reaper.ImGui_Checkbox(ctx, "Ignore case##ic", ignore_case)
  if ch_ic then ignore_case = new_ic end
  reaper.ImGui_PopStyleVar(ctx, 2)

  reaper.ImGui_SameLine(ctx)
  -- Occurrence 列表: First, Last, All
  if reaper.ImGui_BeginCombo(ctx, "Occurrence##occ", (occurrence_mode==0 and "First") or (occurrence_mode==1 and "Last") or "All") then
    local occ_opts = {"First", "Last", "All"}
    for i = 0, 2 do
      local sel = (i == occurrence_mode)
      if reaper.ImGui_Selectable(ctx, occ_opts[i+1], sel) then occurrence_mode = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Separator(ctx)

  -- 3) Remove
  local ch_rm, new_rm = reaper.ImGui_Checkbox(ctx, "Remove", enable_remove)
  if ch_rm then enable_remove = new_rm end
  reaper.ImGui_BeginDisabled(ctx, not enable_remove)
  reaper.ImGui_PushItemWidth(ctx, -90)
  local ch_cnt, newCnt = reaper.ImGui_DragInt(ctx, "Count##rmcnt", remove_count, 1, 0, 100, "%d")
  if ch_cnt then remove_count = newCnt end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(
    "Hold Alt and drag the slider to make finer adjustments.\n\n" ..
    "For ultra-precise control, hold Alt + Shift while dragging.\n\n" ..
    "To enter a specific value, Ctrl + Left-click the slider and type it in."
  )

  reaper.ImGui_PushItemWidth(ctx, -90)
  local ch_pos, newPos = reaper.ImGui_DragInt(ctx, "At position##rmpos", remove_position, 1, 0, 100, "%d")
  if ch_pos then remove_position = newPos end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(
    "Hold Alt and drag the slider to make finer adjustments.\n\n" ..
    "For ultra-precise control, hold Alt + Shift while dragging.\n\n" ..
    "To enter a specific value, Ctrl + Left-click the slider and type it in."
  )

  if reaper.ImGui_BeginCombo(ctx, "From##rmside", (remove_side_index==0) and "Beginning" or "End") then
    local opts = { "Beginning", "End" }
    for i = 0, 1 do
      local sel = (i == remove_side_index)
      if reaper.ImGui_Selectable(ctx, opts[i+1], sel) then remove_side_index = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Separator(ctx)

  -- 4) Insert
  local ch_i, new_i = reaper.ImGui_Checkbox(ctx, "Insert", enable_insert)
  if ch_i then enable_insert = new_i end

  if enable_insert then
    draw_wildcards(ctx, 'Wildcards##3', 'wildcards_popup##3', 'insert')
    draw_specifiers(ctx, 'Specifiers##3', 'item_mode_specifiers##3', 'insert')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_insert)
  local ch_txt, newTxt = reaper.ImGui_InputText(ctx, "To insert##ins", insert_text or "")
  if ch_txt then insert_text = newTxt end

  reaper.ImGui_PushItemWidth(ctx, -90)
  local ch_ip, new_ip = reaper.ImGui_DragInt(ctx, "At position##inspos", insert_position, 1, 0, 100, "%d")
  if ch_ip then insert_position = new_ip end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(
    "Hold Alt and drag the slider to make finer adjustments.\n\n" ..
    "For ultra-precise control, hold Alt + Shift while dragging.\n\n" ..
    "To enter a specific value, Ctrl + Left-click the slider and type it in."
  )

  if reaper.ImGui_BeginCombo(ctx, "From##insside", (insert_side_index==0) and "Beginning" or "End") then
    for i = 0, 1 do
      local sel = (i == insert_side_index)
      local lbl = (i == 0) and "Beginning" or "End"
      if reaper.ImGui_Selectable(ctx, lbl, sel) then insert_side_index = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)

  -- reaper.ImGui_SeparatorText(ctx, 'Options')
  reaper.ImGui_Separator(ctx)

  local changed7, newCycle = reaper.ImGui_Checkbox(ctx, "Range Cycle Mode", use_cycle_mode)
  if changed7 then use_cycle_mode = newCycle end
  reaper.ImGui_SameLine(ctx)
  -- 帮助
  help_marker(
    "Enable Cycle Mode to continuously loop letters or numbers within a specified range.\n\n" ..
    "For example, 'a=A-C' will cycle A - B - C - A - ..., and 'd=1-3' will cycle 1 - 2 - 3 - 1 - ..., " ..
    "You can also specify a reverse range like 'a=Z-X' or 'd=9-7' to cycle in descending order."
  )

  if process_mode == 0 or process_mode == 7 then
    reaper.ImGui_SameLine(ctx)
    -- reaper.ImGui_SetNextItemWidth(ctx, 100)
    if reaper.ImGui_BeginCombo(ctx, "Sort by", (sort_index == 0 and "Track") or (sort_index == 1 and "Sequence") or "Timeline") then
      local sort_options = { "Track", "Sequence", "Timeline" }
      for i = 0, #sort_options-1 do
        local is_selected = (i == sort_index)
        if reaper.ImGui_Selectable(ctx, sort_options[i+1], is_selected) then
          sort_index = i
        end
        if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
      end
      reaper.ImGui_EndCombo(ctx)
    end
  end

  if process_mode == 2 or process_mode == 5 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushFont(ctx, font_small)
    open_region_marker_manager(ctx, "Open Region/Marker Manager")
    reaper.ImGui_PopFont(ctx)
  end

  local data, builder = get_preview_data_and_builder()
  render_preview_table(ctx, PREVIEW_TABLE_ID, #data, builder)

  -- Process 第一版 非列表
  -- reaper.ImGui_SeparatorText(ctx, "Batch Mode")

  -- -- 模式列表
  -- local mode_labels = {
  --   "Items",
  --   "Tracks",
  --   "Region Manager",
  --   "Regions (Time Selection)",
  --   "Regions (Selected Items)",
  --   "Marker Manager",
  --   "Markers (Time Selection)",
  --   "Source Files (Selected Items)",
  -- }

  -- -- 逐个绘制 RadioButton，超出右边界时自动换行
  -- for i, label in ipairs(mode_labels) do
  --   -- 在绘制前测量下一项的宽度
  --   local tw, th = reaper.ImGui_CalcTextSize(ctx, label)
  --   -- 加上一些内边距，确保不会紧贴边框
  --   local item_width = tw + th -- 高度近似为宽度的 padding
    
  --   -- 可用宽度
  --   local avail_x, _ = reaper.ImGui_GetContentRegionAvail(ctx)
  --   -- 如果剩余宽度不足以容下下一项，就换行
  --   if i > 1 and avail_x < item_width then
  --     reaper.ImGui_NewLine(ctx)
  --   end
  
  --   -- 绘制 RadioButton
  --   local clicked
  --   clicked, process_mode = reaper.ImGui_RadioButtonEx(
  --     ctx,
  --     label,
  --     process_mode,
  --     i-1
  --   )
  --   -- 绘制后再同一行
  --   if i < #mode_labels then
  --     reaper.ImGui_SameLine(ctx)
  --   end
  -- end

  -- -- 帮助
  -- reaper.ImGui_SameLine(ctx)
  -- help_marker(
  --   "Select a batch mode to rename items, tracks, regions, markers, or source files."
  -- )

  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  -- if     process_mode == 0 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your items.")
  -- elseif process_mode == 1 then reaper.ImGui_Text(ctx, "Tip: In the Track Control Panel, select a track.")
  -- elseif process_mode == 2 then reaper.ImGui_Text(ctx, "Tip: Open the Region Manager and select a region.")
  -- elseif process_mode == 3 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for regions.")
  -- elseif process_mode == 4 then reaper.ImGui_Text(ctx, "Tip: Select items in the Arrange view to target their regions.")
  -- elseif process_mode == 5 then reaper.ImGui_Text(ctx, "Tip: Open the Marker Manager and select a marker.")
  -- elseif process_mode == 6 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for markers.")
  -- elseif process_mode == 7 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your media items.")
  -- end
  -- reaper.ImGui_PopStyleColor(ctx)

  -- Process 第二版 下拉菜单版本
  -- reaper.ImGui_SeparatorText(ctx, "Batch Mode")

  -- 模式列表
  -- local mode_labels = {
  --   "Media Items",
  --   "Tracks",
  --   "Region Manager",
  --   "Regions (Time Selection)",
  --   "Regions (Selected Items)",
  --   "Marker Manager",
  --   "Markers (Time Selection)",
  --   "Source Files (Selected Items)",
  -- }

  -- -- 当前选中项文字
  -- local current_label = mode_labels[process_mode + 1] or ""

  -- -- 下拉菜单（隐藏 Combo 自身的标签，只显示当前选中项）
  -- if reaper.ImGui_BeginCombo(ctx, "Apply To##batch_mode_combo", current_label) then
  --   for i, label in ipairs(mode_labels) do
  --     local is_selected = (process_mode == i - 1)
  --     if reaper.ImGui_Selectable(ctx, label, is_selected) then
  --       process_mode = i - 1
  --     end
  --     if is_selected then
  --       reaper.ImGui_SetItemDefaultFocus(ctx)
  --     end
  --   end
  --   reaper.ImGui_EndCombo(ctx)
  -- end

  -- -- 帮助图标
  -- reaper.ImGui_SameLine(ctx)
  -- help_marker(
  --   "Select a batch mode to rename items, tracks, regions, markers, or source files."
  -- )

  -- -- 提示文字
  -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  -- if     process_mode == 0 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your items.")
  -- elseif process_mode == 1 then reaper.ImGui_Text(ctx, "Tip: In the Track Control Panel, select a track.")
  -- elseif process_mode == 2 then reaper.ImGui_Text(ctx, "Tip: Open the Region Manager and select a region.")
  -- elseif process_mode == 3 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for regions.")
  -- elseif process_mode == 4 then reaper.ImGui_Text(ctx, "Tip: Select items in the Arrange view to target their regions.")
  -- elseif process_mode == 5 then reaper.ImGui_Text(ctx, "Tip: Open the Marker Manager and select a marker.")
  -- elseif process_mode == 6 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for markers.")
  -- elseif process_mode == 7 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your media items.")
  -- end
  -- reaper.ImGui_PopStyleColor(ctx)

  -- Process 第三版 批量模式支持鼠标滚轮
  reaper.ImGui_SeparatorText(ctx, "Batch Mode")
  
  -- 模式列表
  local mode_labels = {
    "Items",
    "Tracks",
    "Region Manager",
    "Regions (Time Selection)",
    "Regions (Selected Items)",
    "Marker Manager",
    "Markers (Time Selection)",
    "Source Files (Selected Items)",
  }
  
  local wheel = reaper.ImGui_GetMouseWheel(ctx)

  -- 逐个绘制 RadioButton，超出右边界时自动换行
  for i, label in ipairs(mode_labels) do
    -- 在绘制前测量下一项的宽度
    local tw, th = reaper.ImGui_CalcTextSize(ctx, label)
    local item_width = tw + th -- 高度近似为宽度的 padding
    
    -- 可用宽度
    local avail_x, _ = reaper.ImGui_GetContentRegionAvail(ctx)
    if i > 1 and avail_x < item_width then
      reaper.ImGui_NewLine(ctx)
    end
  
    -- 绘制 RadioButton
    local clicked
    clicked, process_mode = reaper.ImGui_RadioButtonEx(
      ctx,
      label,
      process_mode,
      i-1
    )

    -- 鼠标滚轮支持 Batch Mode 前后切换
    if wheel ~= 0 and reaper.ImGui_IsItemHovered(ctx) then
      -- process_mode = (process_mode + wheel) % #mode_labels -- 反向
      process_mode = (process_mode - wheel + #mode_labels) % #mode_labels
      wheel = 0
    end

    if i < #mode_labels then
      reaper.ImGui_SameLine(ctx)
    end
  end

  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(
    "Select a batch mode to rename items, tracks, regions, markers, or source files.\n" ..
    "Hover over this area and use the mouse wheel to switch modes."
  )
  
  -- 提示文字
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  if     process_mode == 0 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your items.")
  elseif process_mode == 1 then reaper.ImGui_Text(ctx, "Tip: In the Track Control Panel, select a track.")
  elseif process_mode == 2 then reaper.ImGui_Text(ctx, "Tip: Open the Region Manager and select a region.")
  elseif process_mode == 3 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for regions.")
  elseif process_mode == 4 then reaper.ImGui_Text(ctx, "Tip: Select items in the Arrange view to target their regions.")
  elseif process_mode == 5 then reaper.ImGui_Text(ctx, "Tip: Open the Marker Manager and select a marker.")
  elseif process_mode == 6 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for markers.")
  elseif process_mode == 7 then reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your media items.")
  end
  reaper.ImGui_PopStyleColor(ctx)

  -- 检测/按下 Ctrl + Enter 快捷键
  local ctrlPressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) -- 判断 Ctrl 是否按下
  local enterPressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_Enter()) -- 判断 Enter 是否按下
  if ctrlPressed and enterPressed then
    apply_batch_rename()
  end

  -- reaper.ImGui_Separator(ctx)
  -- reaper.ImGui_Dummy(ctx, 0, 0)
  -- 计算可用宽度并分成两半（减去 SameLine 之间的间距）
  local avail_x, _     = reaper.ImGui_GetContentRegionAvail(ctx)
  local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
  local half_width     = (avail_x - item_spacing_x) * 0.5
  
  local default_h      = reaper.ImGui_GetFrameHeight(ctx)
  local button_h       = default_h + 7

  -- 左侧按钮，占一半宽度
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, "Reset to default", half_width, button_h) then
    enable_rename     = false
    enable_replace    = false
    enable_remove     = false
    enable_insert     = false
    rename_pattern    = ""
    find_text         = ""
    replace_text      = ""
    remove_count      = 0
    remove_position   = 0
    remove_side_index = 0
    insert_text       = ""
    insert_position   = 0
    insert_side_index = 0
    use_cycle_mode    = true
    ignore_case       = false
    occurrence_mode   = 2 -- All 模式
  end
  
  reaper.ImGui_SameLine(ctx)
  
  -- 右侧按钮，占一半宽度
  if reaper.ImGui_Button(ctx, "Rename All##do_rename", half_width, button_h) then
    apply_batch_rename()
  end
  reaper.ImGui_PopFont(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker("Press Ctrl+Enter to instantly perform the “Rename All” action.")

  if tables.disable_indent then
    reaper.ImGui_PopStyleVar(ctx)
  end

  return true
end

local function loop()
  reaper.ImGui_PushFont(ctx, sans_serif)
  reaper.ImGui_SetNextWindowBgAlpha(ctx, 1.0) -- 背景透明
  -- reaper.ImGui_SetNextWindowSizeConstraints(ctx, 450, 850, FLT_MAX, FLT_MAX) -- 锁定界面
  -- 在 Begin 之前推入 WindowRounding 和 FrameRounding
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 6.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),  4.0)

  -- 1) 开始窗口
  local visible, open = reaper.ImGui_Begin(ctx, "Batch Rename Plus - Extensible Batch Renaming for REAPER", true)
  if visible then
    -- 圆角处理: 弹出菜单、子区域、滚动条、滑块
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),     4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),      4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),     4.0)
    -- 2) 读取默认行间距，放大 2 倍
    local ix, iy = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), ix, iy * 2.0)
    -- 3) 绘制所有 UI
    if not frame() then
      open = false
    end
    -- 4) 恢复行间距样式
    reaper.ImGui_PopStyleVar(ctx, 5) -- 4 次圆角 + 1 次行间距
    -- 5) 结束窗口
    reaper.ImGui_End(ctx)
  end

  -- 6) Pop 最早 Push 的 WindowRounding + FrameRounding
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_PopFont(ctx)

  if open then
    reaper.defer(loop)
  else
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
  end
end

loop()
