-- NoIndex: true
local Translator = {}
Translator.is_requesting = false
Translator.request_start_time = 0
Translator.last_poll_time = 0 
Translator.pending_text = nil
Translator.wait_frames = 0 

local is_windows = reaper.GetOS():find("Win") ~= nil

local info = debug.getinfo(1, 'S')
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]])
-- local root_path = script_path:match("(.*)lib[/\\]")
-- if not root_path then root_path = script_path end
local root_path = script_path
if is_windows then root_path = root_path:gsub("/", "\\") end
local f_output = root_path .. "temp_trans_result.txt"

-- 根据系统决定启动文件 (Windows用bat, Mac用sh)
local launcher_name = is_windows and "launcher.bat" or "launcher.sh"
local f_launcher = root_path .. launcher_name

-- 执行Python
local function ExecutePython(text)
  os.remove(f_output)
  text = text:gsub('"', '')

  local cmd = ""

  if is_windows then
    local bat_content = string.format([[
@echo off
chcp 65001 > nul
cd /d "%%~dp0"
python translator.py "%s" "temp_trans_result.txt"
]], text)

    local f_b = io.open(f_launcher, "w")
    if f_b then
        f_b:write(bat_content)
        f_b:close()
    end

    cmd = string.format('cmd.exe /C "%s"', f_launcher)

  else -- MAC
    local sh_content = string.format([[
#!/bin/sh
export LANG=en_US.UTF-8
cd "$(dirname "$0")"
python3 translator.py "%s" "temp_trans_result.txt"
]], text)

    local f_s = io.open(f_launcher, "w")
    if f_s then f_s:write(sh_content); f_s:close() end

    cmd = string.format('/bin/sh "%s"', f_launcher)
  end

  -- 执行命令 (通用)
  if reaper.ExecProcess then
    -- 屏幕上显示 Trans... 等待3帧
    reaper.ExecProcess(cmd, 0)
  else
    os.execute(cmd)
  end
end

-- 轮询与调度
function Translator.Poll(callback)
  local now = reaper.time_precise()
  -- UI刷新3帧
  if Translator.wait_frames > 0 then
    Translator.wait_frames = Translator.wait_frames - 1
    return -- 这一帧直接返回，不卡顿
  end

  -- 帧数走完，执行任务
  if Translator.pending_text then
    ExecutePython(Translator.pending_text)

    Translator.pending_text = nil
    Translator.request_start_time = now
    Translator.last_poll_time = 0
    return 
  end

  -- 检查结果
  if Translator.is_requesting then
    if (now - Translator.last_poll_time > 0.05) then
      Translator.last_poll_time = now

      if reaper.file_exists(f_output) then
        local file = io.open(f_output, "r")
        if file then
          local content = file:read("*all")
          file:close()
          os.remove(f_output)
          if content and content ~= "" and content ~= "Error" then
            if callback then callback(content) end
          end
          Translator.is_requesting = false
        end
      end
    end
    -- 超时
    if (now - Translator.request_start_time > 10.0) then
      Translator.is_requesting = false
    end
  end
end

-- 发送请求 (完全保持不变)
function Translator.SendRequest(text)
  if not text or text == "" then return end
  Translator.is_requesting = true
  Translator.pending_text = text
  -- 等待3帧
  Translator.wait_frames = 3
end

return Translator