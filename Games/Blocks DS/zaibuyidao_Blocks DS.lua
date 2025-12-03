-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"
require ('lib.utils')

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

-- Check for ReaImGui dependency
if not reaper.ImGui_GetBuiltinPath then
  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('ReaImGui: ReaScript binding for Dear ImGui')
    reaper.MB(
      "ReaImGui is not installed or is out of date.\n\n" ..
      "The ReaPack package browser has been opened. Please search for 'ReaImGui' and install or update it before running this script.",
      "Batch Rename Plus", 0)
  else
    local reapackErrorMsg = 
      "ReaPack is not installed.\n\n" ..
      "To use this script, please install ReaPack first:\n" ..
      "https://reapack.com\n\n" ..
      "After installing ReaPack, use it to install 'ReaImGui: ReaScript binding for Dear ImGui'."
    reaper.MB(reapackErrorMsg, "ReaPack Not Found", 0)
  end
  return
end

local ImGui
if reaper.ImGui_GetBuiltinPath then
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  ImGui = require 'imgui' '0.10'
end

local ctx = reaper.ImGui_CreateContext('Blocks DS')
local my_font = reaper.ImGui_CreateFont('sans-serif', 24)
reaper.ImGui_Attach(ctx, my_font)

-- 配置参数
local COLS, ROWS = 10, 23 -- 总行数设置为23 (3行缓冲区 + 20行可视区)
local VISIBLE_ROWS = 20
local HIDDEN_ROWS = ROWS - VISIBLE_ROWS -- 3行隐藏
local BLOCK_SIZE = 20
local PREVIEW_BLOCK_SIZE = 15
local UI_LEFT_WIDTH = 70
local UI_RIGHT_WIDTH = 210
local NEXT_BOX_SIZE = 60
local BOX_GAP = 5
local WIN_LINES = 150 -- 实际上现在是无限玩，但保留这个作为目标参考
local MAX_LEVEL = 20  -- 最高等级
local LOCK_DELAY = 0.5 -- 锁定延迟时间(秒)
local lock_start_time = nil -- 记录触底开始的时间
local CLEAR_ANIMATION_DURATION = 0.4 -- 消除动画持续时间(秒)

-- 速度表(秒/格)
local SPEED_TABLE = {
  [1] = 0.80, [2] = 0.72, [3] = 0.64, [4] = 0.57, [5] = 0.50,
  [6] = 0.44, [7] = 0.38, [8] = 0.33, [9] = 0.28, [10] = 0.24,
  [11] = 0.20, [12] = 0.17, [13] = 0.14, [14] = 0.12, [15] = 0.10,
  [16] = 0.09, [17] = 0.08, [18] = 0.07, [19] = 0.06, [20] = 0.05
}

-- 颜色定义
local COLORS = {
  [0] = 0x222222FF, -- 背景
  [1] = 0x00FFFFFF, -- I
  [2] = 0x0000FFFF, -- J
  [3] = 0xFFA500FF, -- L
  [4] = 0xFFFF00FF, -- O
  [5] = 0x00FF00FF, -- S
  [6] = 0x800080FF, -- T
  [7] = 0xFF0000FF, -- Z
  ['border'] = 0xFFFFFF88,
  ['hold_bg'] = 0x333333FF, 
  ['next_bg'] = 0x333333FF,
  ['ghost'] = 0xFFFFFF33
}

-- 方块形状
local SHAPES = {
  [1] = {{0,0}, {-1,0}, {1,0}, {2,0}},   -- I
  [2] = {{0,0}, {-1,-1}, {-1,0}, {1,0}}, -- J
  [3] = {{0,0}, {1,-1}, {-1,0}, {1,0}},  -- L
  [4] = {{0,0}, {1,0}, {0,1}, {1,1}},    -- O
  [5] = {{0,0}, {-1,1}, {0,1}, {1,0}},   -- S
  [6] = {{0,0}, {-1,0}, {1,0}, {0,1}},   -- T
  [7] = {{0,0}, {-1,0}, {0,1}, {1,1}}    -- Z
}

-- 全局变量
local grid = {}
local next_queue = {}
local hold_piece_id = nil
local can_hold = true
local score_lines = 0
local high_score = 0    -- 最高分变量
local level = 1         -- 当前等级
local tick_speed = 0.8  -- 当前下落速度
local state = "MENU"    -- 初始状态
local last_tick = reaper.time_precise()
local current_piece = nil
local cur_x, cur_y = 5, 2
local show_ghost = true -- Ghost Piece 开关
local clear_effects = {} -- 消除特效列表
local pending_clear_lines = {} -- 等待消除的行号列表
local clear_start_time = nil   -- 消除动画开始时间

function get_random_piece_data()
  local type_id = math.random(1, 7)
  local shape_data = {}
  for i, p in ipairs(SHAPES[type_id]) do
    shape_data[i] = {x = p[1], y = p[2]}
  end
  return { id = type_id, shape = shape_data }
end

function create_piece_from_id(type_id)
  local shape_data = {}
  for i, p in ipairs(SHAPES[type_id]) do
    shape_data[i] = {x = p[1], y = p[2]}
  end
  return { id = type_id, shape = shape_data }
end

-- 帮助提示
function help_marker(desc)
  reaper.ImGui_TextDisabled(ctx, '?')
  if reaper.ImGui_BeginItemTooltip(ctx) then
    reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35)
    reaper.ImGui_Text(ctx, desc)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)
  end
end

-- 预览方块绘制 (自动居中)
function draw_preview_piece(draw_list, shape, color, box_x, box_y, box_size, blk_size)
  local min_x, max_x, min_y, max_y = 100, -100, 100, -100
  for _, p in ipairs(shape) do
    if p.x and p.y then
      if p.x < min_x then min_x = p.x end
      if p.x > max_x then max_x = p.x end
      if p.y < min_y then min_y = p.y end
      if p.y > max_y then max_y = p.y end
    end
  end

  if min_x == 100 then return end

  local piece_pixel_w = (max_x - min_x + 1) * blk_size
  local piece_pixel_h = (max_y - min_y + 1) * blk_size

  local offset_x = box_x + (box_size - piece_pixel_w) / 2
  local offset_y = box_y + (box_size - piece_pixel_h) / 2

  for _, p in ipairs(shape) do
    local draw_x = offset_x + (p.x - min_x) * blk_size
    local draw_y = offset_y + (p.y - min_y) * blk_size

    reaper.ImGui_DrawList_AddRectFilled(draw_list, draw_x, draw_y, draw_x + blk_size - 1, draw_y + blk_size - 1, color)
    reaper.ImGui_DrawList_AddRect(draw_list, draw_x, draw_y, draw_x + blk_size - 1, draw_y + blk_size - 1, 0xFFFFFF44)
  end
end

-- 更新速度
function update_level_speed()
  -- 计算等级: 每10行升1级
  level = math.floor(score_lines / 10) + 1
  if level > MAX_LEVEL then level = MAX_LEVEL end
  -- 从表中获取速度，如果没有则默认最快
  tick_speed = SPEED_TABLE[level] or 0.05
end

function init_game()
  grid = {}
  for y = 1, ROWS do
    grid[y] = {}
    for x = 1, COLS do
      grid[y][x] = 0
    end
  end

  next_queue = {}
  for i = 1, 6 do
    table.insert(next_queue, get_random_piece_data())
  end

  hold_piece_id = nil
  can_hold = true
  score_lines = 0
  current_piece = nil -- 初始化时清空当前方块
  clear_effects = {}
  pending_clear_lines = {}
  clear_start_time = nil

  -- 读取存储的最高分
  local saved_score = reaper.GetExtState("TetrisUltimate", "HighScore")
  if saved_score ~= "" then
    high_score = tonumber(saved_score) or 0
  else
    high_score = 0
  end
  update_level_speed() -- 初始化速度
end

function new_piece()
  if #next_queue == 0 then table.insert(next_queue, get_random_piece_data()) end
  current_piece = table.remove(next_queue, 1)
  table.insert(next_queue, get_random_piece_data())

  -- 动态设置生成位置
  cur_x = 5
  if current_piece.id <= 3 then
    cur_y = 3
  else
    cur_y = 2
  end

  can_hold = true
  lock_start_time = nil -- 新方块产生时，清除锁定计时

  -- 碰撞检测
  if check_collision(cur_x, cur_y, current_piece.shape) then
    state = "GAMEOVER"
  end
end

function attempt_hold()
  if not can_hold or state ~= "PLAYING" then return end

  local current_id = current_piece.id

  if hold_piece_id == nil then
    hold_piece_id = current_id
    new_piece()
    can_hold = false 
  else
    local temp_id = hold_piece_id
    hold_piece_id = current_id
    current_piece = create_piece_from_id(temp_id)

    cur_x = 5
    if current_piece.id == 1 then
      cur_y = 3
    else
      cur_y = 2
    end

    can_hold = false
    lock_start_time = nil -- Hold交换后，清除锁定计时
  end
end

function check_collision(cx, cy, shape)
  for _, p in ipairs(shape) do
    local x = cx + p.x
    local y = cy + p.y
    if x < 1 or x > COLS or y > ROWS then return true end
    if y >= 1 and grid[y] and grid[y][x] ~= 0 then return true end
  end
  return false
end

function lock_piece()
  for _, p in ipairs(current_piece.shape) do
    local x = cur_x + p.x
    local y = cur_y + p.y
    if y >= 1 and y <= ROWS and x >= 1 and x <= COLS then
      grid[y][x] = current_piece.id
    end
  end
  -- 先检查是否有行需要消除
  local lines_found = check_lines()
  if not lines_found and state == "PLAYING" then 
    new_piece() 
  end
end

-- 检测并开始消除动画
function check_lines()
  local lines_to_clear = {}
  -- 标记所有满行
  for y = 1, ROWS do
    local full = true
    for x = 1, COLS do
      if grid[y][x] == 0 then
        full = false
        break
      end
    end
    if full then
      table.insert(lines_to_clear, y)
    end
  end

  if #lines_to_clear > 0 then
    state = "CLEARING"
    pending_clear_lines = lines_to_clear
    clear_start_time = reaper.time_precise()

    for _, line_y in ipairs(lines_to_clear) do
      table.insert(clear_effects, {
        y = line_y, -- 记录视觉上的行号
        start_time = clear_start_time,
        duration = CLEAR_ANIMATION_DURATION -- 特效持续时间
      })
    end
    return true
  end
  return false
end

-- 动画结束后执行实际的数据更新
function resolve_lines()
  if #pending_clear_lines > 0 then
    -- 更新分数
    score_lines = score_lines + #pending_clear_lines
    if score_lines > high_score then
      high_score = score_lines
      reaper.SetExtState("TetrisUltimate", "HighScore", tostring(high_score), true)
    end
    update_level_speed()

    -- 重构网格 (消除行并下落)
    local new_grid = {}
    -- 在顶部填充对应数量的空行
    for i = 1, #pending_clear_lines do
      local row = {}
      for x = 1, COLS do row[x] = 0 end
      table.insert(new_grid, row)
    end
    -- 复制所有未消除的行
    for y = 1, ROWS do
      local is_cleared = false
      for _, cleared_y in ipairs(pending_clear_lines) do
        if y == cleared_y then is_cleared = true; break end
      end

      if not is_cleared then
        table.insert(new_grid, grid[y])
      end
    end

    grid = new_grid
    pending_clear_lines = {}
  end

  state = "PLAYING"
  new_piece()
end

function rotate_piece(dir)
  if current_piece.id == 4 then return false end
  local new_shape = {}
  for i, p in ipairs(current_piece.shape) do
    local nx, ny
    if dir == "right" then nx, ny = -p.y, p.x else nx, ny = p.y, -p.x end
    new_shape[i] = {x = nx, y = ny}
  end

  local rotated = false
  -- 原地
  if not check_collision(cur_x, cur_y, new_shape) then
    current_piece.shape = new_shape
    rotated = true
  -- 墙踢 Left
  elseif not check_collision(cur_x - 1, cur_y, new_shape) then
    cur_x = cur_x - 1
    current_piece.shape = new_shape
    rotated = true
  -- 墙踢 Right
  elseif not check_collision(cur_x + 1, cur_y, new_shape) then
    cur_x = cur_x + 1
    current_piece.shape = new_shape
    rotated = true
  -- I条专用墙踢 Left-2
  elseif current_piece.id == 1 and not check_collision(cur_x - 2, cur_y, new_shape) then
    cur_x = cur_x - 2
    current_piece.shape = new_shape
    rotated = true
  -- I条专用墙踢 Right-2
  elseif current_piece.id == 1 and not check_collision(cur_x + 2, cur_y, new_shape) then
    cur_x = cur_x + 2
    current_piece.shape = new_shape
    rotated = true
  -- 地板踢: 如果卡在地里，尝试向上提1格
  elseif not check_collision(cur_x, cur_y - 1, new_shape) then
    cur_y = cur_y - 1
    current_piece.shape = new_shape
    rotated = true
  -- 强力地板踢: I条竖转横可能需要提2格
  elseif not check_collision(cur_x, cur_y - 2, new_shape) then
    cur_y = cur_y - 2
    current_piece.shape = new_shape
    rotated = true
  end

  return rotated
end

function game_update()
  -- 暂停处理
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
    if state == "PLAYING" then
      state = "PAUSED"
    elseif state == "PAUSED" then
      state = "PLAYING"
      last_tick = reaper.time_precise() -- 恢复时重置计时，防止瞬间下落
    end
  end

  if state == "CLEARING" then
    local now = reaper.time_precise()
    if now - clear_start_time >= CLEAR_ANIMATION_DURATION then
      resolve_lines()
    end
    return 
  end

  if state ~= "PLAYING" then return end

  local now = reaper.time_precise()
  local action_performed = false -- 标记本帧是否有移动/旋转操作

  -- 左右移动
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_A()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow()) then
    if not check_collision(cur_x - 1, cur_y, current_piece.shape) then
      cur_x = cur_x - 1
      action_performed = true
    end
  end
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow()) then
    if not check_collision(cur_x + 1, cur_y, current_piece.shape) then
      cur_x = cur_x + 1
      action_performed = true
    end
  end
  local current_drop_interval = tick_speed
  -- 软下落
  if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_S()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
    current_drop_interval = 0.05 
  end

  -- 硬下落
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_W()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
    while not check_collision(cur_x, cur_y + 1, current_piece.shape) do cur_y = cur_y + 1 end
    lock_piece()
    last_tick = now
    return 
  end

  -- 旋转
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_J()) then
    if rotate_piece("left") then action_performed = true end
  end
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_K()) then
    if rotate_piece("right") then action_performed = true end
  end

  -- Hold
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) then 
    attempt_hold()
    last_tick = now 
  end

  -- 检查是否即将发生触底碰撞
  local is_grounded = check_collision(cur_x, cur_y + 1, current_piece.shape)

  -- 处理重力下落
  if now - last_tick > current_drop_interval then
    if not is_grounded then
      cur_y = cur_y + 1
      last_tick = now
      lock_start_time = nil -- 只要发生了下落，就重置锁定计时
      is_grounded = false   -- 更新状态
    else
      -- 即使时间到了，但因为触底无法下落，只更新时间戳，不移动，不强制锁定
      last_tick = now
    end
  end
  -- 处理锁定计时 (Infinity Rule)
  if is_grounded then
    -- 如果是刚触底，开始计时
    if not lock_start_time then
      lock_start_time = now
    end
    -- 只要移动或旋转就重置计时器
    if action_performed then
      lock_start_time = now
    end
    -- 只有超时才锁定
    if now - lock_start_time > LOCK_DELAY then
      lock_piece()
      lock_start_time = nil
    end
  else
    -- 悬空状态下清除计时
    lock_start_time = nil
  end
end

function loop()
  local total_w = UI_LEFT_WIDTH + (COLS * BLOCK_SIZE) + UI_RIGHT_WIDTH + 30
  local total_h = (VISIBLE_ROWS * BLOCK_SIZE) + 40

  reaper.ImGui_SetNextWindowSize(ctx, total_w, total_h, reaper.ImGui_Cond_FirstUseEver())

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 6.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5) -- 0.5, 0.5 为居中

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x181818FF)
  reaper.ImGui_PushFont(ctx, my_font, 14)
  local visible, open = reaper.ImGui_Begin(ctx, 'Blocks DS', true)
  reaper.ImGui_PopFont(ctx)
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
    open = false
  end

  if visible then
    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)

    local board_w = COLS * BLOCK_SIZE
    local board_h = VISIBLE_ROWS * BLOCK_SIZE

    local left_ui_x = cursor_x
    local board_x = cursor_x + UI_LEFT_WIDTH + 10
    local right_ui_x = board_x + board_w + 20

    -- 绘制左侧 HOLD 区域
    reaper.ImGui_SetCursorScreenPos(ctx, left_ui_x, cursor_y)
    reaper.ImGui_BeginGroup(ctx)
    reaper.ImGui_PushFont(ctx, my_font, 16)
    reaper.ImGui_Text(ctx, "HOLD:")

    local hold_box_x = left_ui_x + 0
    local hold_box_y = cursor_y + 30

    reaper.ImGui_DrawList_AddRectFilled(draw_list, hold_box_x, hold_box_y, hold_box_x + NEXT_BOX_SIZE, hold_box_y + NEXT_BOX_SIZE, COLORS['hold_bg'])
    local border_col = can_hold and 0xFFFFFFFF or 0x888888FF
    reaper.ImGui_DrawList_AddRect(draw_list, hold_box_x, hold_box_y, hold_box_x + NEXT_BOX_SIZE, hold_box_y + NEXT_BOX_SIZE, border_col)

    if hold_piece_id then
      local temp_piece = create_piece_from_id(hold_piece_id)
      draw_preview_piece(draw_list, temp_piece.shape, COLORS[hold_piece_id], hold_box_x, hold_box_y, NEXT_BOX_SIZE, PREVIEW_BLOCK_SIZE)
    end

    reaper.ImGui_EndGroup(ctx)
    reaper.ImGui_Dummy(ctx, 0, 260)

    reaper.ImGui_BeginGroup(ctx)
    -- reaper.ImGui_Text(ctx, "TETRIS")
    reaper.ImGui_TextColored(ctx, 0xFFFF00FF, "TOP: " .. tostring(high_score))
    reaper.ImGui_Text(ctx, "LINE: " .. tostring(score_lines))
    reaper.ImGui_Text(ctx, "LV: " .. tostring(level))
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_EndGroup(ctx)

    -- 绘制中间游戏区
    reaper.ImGui_DrawList_AddRectFilled(draw_list, board_x, cursor_y, board_x + board_w, cursor_y + board_h, 0x000000FF)
    reaper.ImGui_DrawList_AddRect(draw_list, board_x, cursor_y, board_x + board_w, cursor_y + board_h, COLORS['border'], 0.0, 0, 2.0)
    -- 设置裁切区域, 位于前3行缓冲区的方块会被ClipRect裁掉不显示
    reaper.ImGui_DrawList_PushClipRect(draw_list, board_x, cursor_y, board_x + board_w, cursor_y + board_h, true)
    -- 绘制网格
    for y = 1, ROWS do
      local draw_y = y - HIDDEN_ROWS -- 坐标变换: 逻辑第4行，视觉第1行
      -- 检查当前行是否正在消除中
      local is_clearing_row = false
      if state == "CLEARING" then
        for _, cy in ipairs(pending_clear_lines) do
          if y == cy then
            is_clearing_row = true
            break end
        end
      end

      -- 只有非消除行才绘制方块
      if not is_clearing_row then
        for x = 1, COLS do
          if grid[y][x] ~= 0 then
            local px = board_x + (x-1) * BLOCK_SIZE
            local py = cursor_y + (draw_y-1) * BLOCK_SIZE
            reaper.ImGui_DrawList_AddRectFilled(draw_list, px + 1, py + 1, px + BLOCK_SIZE - 1, py + BLOCK_SIZE - 1, COLORS[grid[y][x]])
          end
        end
      end
    end

    -- 渲染消除特效
    local now = reaper.time_precise()
    for i = #clear_effects, 1, -1 do
      local effect = clear_effects[i]
      local age = now - effect.start_time

      if age >= effect.duration then
        table.remove(clear_effects, i)
      else
        -- 计算透明度，从 255 渐变到 0
        local progress = age / effect.duration
        local alpha = math.floor((1.0 - progress) * 200) -- 最大透明度200
        local col = (0xFFFFFF << 8) | alpha
        -- 计算特效的位置
        local px = board_x
        local draw_y = effect.y - HIDDEN_ROWS
        local py = cursor_y + (draw_y - 1) * BLOCK_SIZE
        -- 绘制覆盖整行的闪光矩形
        reaper.ImGui_DrawList_AddRectFilled(draw_list, px, py, px + board_w, py + BLOCK_SIZE, col)
      end
    end

    -- 绘制 Ghost Piece
    if state == "PLAYING" and current_piece and show_ghost then
      local ghost_y = cur_y
      -- 模拟下落，找到碰撞前的最底部位置
      while not check_collision(cur_x, ghost_y + 1, current_piece.shape) do
        ghost_y = ghost_y + 1
      end

      -- 绘制幽灵方块
      for _, p in ipairs(current_piece.shape) do
        local x = cur_x + p.x
        local y = ghost_y + p.y
        if y >= 1 and y <= ROWS then
          local draw_y = y - HIDDEN_ROWS
          local px = board_x + (x-1) * BLOCK_SIZE
          local py = cursor_y + (draw_y-1) * BLOCK_SIZE
          -- 绘制半透明填充
          reaper.ImGui_DrawList_AddRectFilled(draw_list, px + 1, py + 1, px + BLOCK_SIZE - 1, py + BLOCK_SIZE - 1, COLORS['ghost'])
          -- 绘制白色虚线边框效果
          reaper.ImGui_DrawList_AddRect(draw_list, px + 1, py + 1, px + BLOCK_SIZE - 1, py + BLOCK_SIZE - 1, 0xFFFFFF66)
        end
      end
    end

    -- 绘制当前方块
    if (state == "PLAYING" or state == "PAUSED") and current_piece then
      for _, p in ipairs(current_piece.shape) do
        local x = cur_x + p.x
        local y = cur_y + p.y
        if y >= 1 and y <= ROWS then
          local draw_y = y - HIDDEN_ROWS
          local px = board_x + (x-1) * BLOCK_SIZE
          local py = cursor_y + (draw_y-1) * BLOCK_SIZE
          reaper.ImGui_DrawList_AddRectFilled(draw_list, px + 1, py + 1, px + BLOCK_SIZE - 1, py + BLOCK_SIZE - 1, COLORS[current_piece.id])
        end
      end
    end

    reaper.ImGui_DrawList_PopClipRect(draw_list)
    -- 绘制右侧 UI 面板
    reaper.ImGui_SetCursorScreenPos(ctx, right_ui_x, cursor_y)
    reaper.ImGui_BeginGroup(ctx)
    reaper.ImGui_PushFont(ctx, my_font, 16)

    reaper.ImGui_Text(ctx, "NEXT:")
    local preview_base_x, preview_base_y = reaper.ImGui_GetCursorScreenPos(ctx)

    local total_step = NEXT_BOX_SIZE + BOX_GAP 

    for i, piece in ipairs(next_queue) do
      local grid_x, grid_y

      if i <= 3 then
        grid_x = i - 1
        grid_y = 0
      else
        grid_x = 2
        grid_y = i - 3
      end

      local box_x = preview_base_x + (grid_x * total_step)
      local box_y = preview_base_y + (grid_y * total_step) + 5 

      reaper.ImGui_DrawList_AddRectFilled(draw_list, box_x, box_y, box_x + NEXT_BOX_SIZE, box_y + NEXT_BOX_SIZE, COLORS['next_bg'])
      reaper.ImGui_DrawList_AddRect(draw_list, box_x, box_y, box_x + NEXT_BOX_SIZE, box_y + NEXT_BOX_SIZE, 0xFFFFFF66)

      draw_preview_piece(draw_list, piece.shape, COLORS[piece.id], box_x, box_y, NEXT_BOX_SIZE, PREVIEW_BLOCK_SIZE)
    end

    local total_height = 4 * total_step
    reaper.ImGui_SetCursorScreenPos(ctx, right_ui_x, preview_base_y + total_height + 10)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_Dummy(ctx, 0, 5)
    reaper.ImGui_PushFont(ctx, my_font, 16)
    -- local btn_text = (state == "MENU") and "START" or "RESTART"
    -- reaper.ImGui_Button(ctx, btn_text, 100, 40)
    local start_by_key = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter())
    if start_by_key then
      init_game()
      score_lines = 0
      state = "PLAYING"
      new_piece()
    end

    local rv
    rv, show_ghost = reaper.ImGui_Checkbox(ctx, "Ghost Piece", show_ghost)

    reaper.ImGui_SameLine(ctx)
    help_marker("A/D: Move\nW: Drop\nS: Fast\nJ/K: Rotate\nSpace: Pause\nQ: HOLD\nEnter: Start\nESC: Exit")
    reaper.ImGui_PopFont(ctx)

    reaper.ImGui_EndGroup(ctx)

    if state == "GAMEOVER" or state == "WIN" or state == "PAUSED" or state == "MENU" then
      -- 绘制半透明黑色背景遮罩
      local overlay_col = 0x000000D0 
      reaper.ImGui_DrawList_AddRectFilled(draw_list, board_x, cursor_y, board_x + board_w, cursor_y + board_h, overlay_col)

      reaper.ImGui_PushFont(ctx, my_font, 24)
      local txt = "GAME OVER"
      local col = 0xFF0000FF

      if state == "WIN" then
        txt = "YOU WIN!"
        col = 0x00FF00FF
      elseif state == "PAUSED" then
        txt = "PAUSED"
        col = 0xFFFF00FF -- 黄色
      elseif state == "MENU" then -- MENU 状态下的 READY 显示
        txt = "READY"
        col = 0xFFFFFFFF
      end

      -- 计算文字居中位置
      local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, txt)
      local text_x = board_x + (board_w - text_w) / 2
      local text_y = cursor_y + board_h / 2 - text_h
      -- 绘制文字阴影，进一步增强对比度
      reaper.ImGui_SetCursorScreenPos(ctx, text_x + 2, text_y + 2)
      reaper.ImGui_TextColored(ctx, 0x000000FF, txt)
      -- 绘制前景高亮文字
      reaper.ImGui_SetCursorScreenPos(ctx, text_x, text_y)
      reaper.ImGui_TextColored(ctx, col, txt)
      reaper.ImGui_PopFont(ctx)
    end

    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopStyleVar(ctx, 3)
  reaper.ImGui_PopStyleColor(ctx, 1)
  if open then reaper.defer(main) end
end

function main()
  game_update()
  loop()
end

init_game()
new_piece()
reaper.defer(main)