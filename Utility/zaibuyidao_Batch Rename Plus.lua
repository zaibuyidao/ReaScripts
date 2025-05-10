-- @description Batch Rename Plus
-- @version 1.0.5
-- @author zaibuyidao
-- @changelog
--   +  Improved the Items-mode table preview to honor the “Sort by” setting, ensuring the preview order always matches the actual renaming results.
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

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3.2'
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
reaper.ImGui_SetNextWindowSize(ctx, 355, 920, reaper.ImGui_Cond_FirstUseEver())

-- 状态变量
local process_mode      = 0     -- 0 = Items, 1 = Tracks
local enable_rename     = false -- true = enable rename
local enable_replace    = false -- true = enable rename
local enable_remove     = false -- true = enable rename
local enable_insert     = false -- true = enable rename
local rename_pattern    = ""    -- pattern input
local find_text         = ""    -- find string
local replace_text      = ""    -- replace string
local remove_count      = 0     -- number of chars to remove
local remove_position   = 0     -- position for removal
local remove_side_index = 0     -- 0 = beginning, 1 = end
local insert_text       = ""    -- text to insert
local insert_position   = 0     -- position for insertion
local insert_side_index = 0     -- 0 = beginning, 1 = end
local use_cycle_mode    = true  -- cycle mode checkbox
local sort_index        = 0     -- 0 = Track, 1 = Sequence, 2 = Timeline
local preview_mode      = false -- 预览模式默认值
local ignore_case       = false -- 是否忽略大小写
local occurrence_mode   = 2     -- Occurrence 模式：0=First,1=Last,2=All
show_list_window = show_list_window or false
local show_list_data = show_list_data or {}
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
    + reaper.ImGui_TableFlags_ScrollY()
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
  id = "Global_Expand_Collapse_All" -- 这里使用全局折叠或展开，不要时直接删除或注释该行

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
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, "Resize Columns", tblFlags1, reaper.ImGui_TableFlags_Resizable())
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
          reaper.ImGui_Text(ctx, "Error: empty name")
          reaper.ImGui_PopStyleColor(ctx)
        end
      else
        -- placeholder row
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx); reaper.ImGui_Text(ctx, "Empty slot")
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
  end
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
  local count_sel = reaper.CountSelectedMediaItems(0)
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
  }
  local wildcards_by_mode = {
    [0] = { "$item", "$track", "$tracknumber", "$folders", "$GUID" },
    [1] = { "$track", "$tracknumber", "$folders", "$GUID" },
    [2] = { "$region", "$regionid", "$regionidx" },
    [3] = { "$marker", "$markerid", "$markeridx" },
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

  -- eaper.ImGui_SeparatorText(ctx, 'Options')
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

  if process_mode == 0 then
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

  -- 预览表格 - Items
  if process_mode == 0 then
    local items = get_sorted_items_data()
    render_preview_table(ctx, "itemspreview", #items, function(i)
      local data     = items[i]
      local orig     = data.orig_name
      local seq      = data.seqIndex
      local new_name = orig

      -- 1) Rename
      if enable_rename then
        new_name = build_items(rename_pattern, orig, data.tname, data.track_num, data.folders, data.take, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if ignore_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_items(replace_text or "", orig, data.tname, data.track_num, data.folders, data.take, seq)
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
        local insert_str = build_items(insert_text, orig, data.tname, data.track_num, data.folders, data.take, seq)
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
    end)
  end

  -- 表格预览 - Tracks
  if process_mode == 1 then
    local cnt = reaper.CountSelectedTracks(0)
    render_preview_table(ctx, "trackspreview", cnt, function(i)
      local track    = reaper.GetSelectedTrack(0, i - 1)
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
    end)
  end

  -- 表格预览 - Region Manager
  if process_mode == 2 then
    local preview_regions = get_sel_regions_mgr()
    render_preview_table(ctx, "region_mgr_preview", #preview_regions, function(i)
      local region   = preview_regions[i]
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
    end)
  end

  -- 表格预览 - Regions (Time Selection)
  if process_mode == 3 then
    local preview_regions = get_sel_regions()
    render_preview_table(ctx, "region_ts_preview", #preview_regions, function(i)
      local region = preview_regions[i]
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
    end)
  end

  -- 表格预览 - Regions for Selected Items
  if process_mode == 4 then
    local preview_regions = get_sel_regions_for_items()
    render_preview_table(ctx, "region_items_preview", #preview_regions, function(i)
      local region   = preview_regions[i]
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
    end)
  end

  -- 表格预览 - Marker Manager
  if process_mode == 5 then
    local preview_markers = get_sel_markers_mgr()
    render_preview_table(ctx, "marker_mgr_preview", #preview_markers, function(i)
      local marker   = preview_markers[i]
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
    end)
  end

  -- 表格预览 - Marker (Time Selection)
  if process_mode == 6 then
    local preview_markers = get_sel_markers()
    render_preview_table(ctx, "marker_ts_preview", #preview_markers, function(i)
      local marker   = preview_markers[i]
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
    end)
  end

  -- Process 标题
  reaper.ImGui_SeparatorText(ctx, "Batch Mode")

  -- 模式标签与对应值
  local mode_labels = {
    "Items",
    "Tracks",
    "Region Manager",
    "Regions (Time Selection)",
    "Regions (Selected Items)",
    "Marker Manager",
    "Markers (Time Selection)",
  }

  -- 逐个绘制 RadioButton，超出右边界时自动换行
  for i, label in ipairs(mode_labels) do
    -- 在绘制前测量下一项的宽度
    local tw, th = reaper.ImGui_CalcTextSize(ctx, label)
    -- 加上一些内边距，确保不会紧贴边框
    local item_width = tw + th -- 高度近似为宽度的 padding
    
    -- 可用宽度
    local avail_x, _ = reaper.ImGui_GetContentRegionAvail(ctx)
    -- 如果剩余宽度不足以容下下一项，就换行
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
    -- 绘制后再同一行
    if i < #mode_labels then
      reaper.ImGui_SameLine(ctx)
    end
  end
  
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(
    "Select a batch mode to rename items, tracks, regions, or markers."
  )
  
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  if process_mode == 0 then
    reaper.ImGui_Text(ctx, "Tip: In the Arrange view, select your items.")
  elseif process_mode == 1 then
    reaper.ImGui_Text(ctx, "Tip: In the Track Control Panel, select a track.")
  elseif process_mode == 2 then
    reaper.ImGui_Text(ctx, "Tip: Open the Region Manager and select a region.")
  elseif process_mode == 3 then
    reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for regions.")
  elseif process_mode == 4 then
    reaper.ImGui_Text(ctx, "Tip: Select items in the Arrange view to target their regions.")
  elseif process_mode == 5 then
    reaper.ImGui_Text(ctx, "Tip: Open the Marker Manager and select a marker.")
  elseif process_mode == 6 then
    reaper.ImGui_Text(ctx, "Tip: In the Arrange view, drag to make a time selection for markers.")
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
