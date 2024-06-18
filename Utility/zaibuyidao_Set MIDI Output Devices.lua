-- @description Set MIDI Output Devices
-- @version 1.0
-- @author zaibuyidao, YS
-- @changelog
--   New Script
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

local show_msg = reaper.GetExtState("SET_MIDI_OUTPUT_DEVICES", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    pu_name = "设置MIDI输出设备"
    pu_text = "该脚本将设置MIDI硬件输出并退出REAPER,\n请确保项目已保存.\n完成后请手动重启REAPER!\n\n设置启用输出:\n\n启用 ID 0, 输入 1\n启用 ID 1, 输入 2\n启用 ID 2, 输入 4\n启用 ID 3, 输入 8\n启用 ID 4, 输入 16\n--\n启用 ID 0 和 1, 输入 3 (1+2, ID对应的值相加)\n启用 ID 1 和 2, 输入 6 (2+4)\n启用 ID 2 和 3, 输入 12 (4+8)\n启用 ID 3 和 4, 输入 24 (8+16)\n--\n启用 ID 0 和 2, 输入 5 (1+4)\n启用 ID 1 和 3, 输入 10 (2+8)\n启用 ID 2 和 4, 输入 20 (4+16)\n--\n启用 ID 0 和 3, 输入 9 (1+8)\n启用 ID 1 和 4, 输入 18 (2+16)\n--\n启用 ID 1 2 3 4, 输入 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\n下次还显示此页面吗？"
    pu_head = "注意事项: \n\n"
  elseif language == "繁體中文" then
    pu_name = "設置MIDI輸出設備"
    pu_text = "該腳本將設置MIDI硬件輸出並退出REAPER,\n請確保項目已保存.\n完畢後請手動重啟REAPER!\n\n設置啟用輸出:\n\n啟用 ID 0, 輸入 1\n啟用 ID 1, 輸入 2\n啟用 ID 2, 輸入 4\n啟用 ID 3, 輸入 8\n啟用 ID 4, 輸入 16\n--\n啟用 ID 0 和 1, 輸入 3 (1+2, ID对应的值相加)\n啟用 ID 1 和 2, 輸入 6 (2+4)\n啟用 ID 2 和 3, 輸入 12 (4+8)\n啟用 ID 3 和 4, 輸入 24 (8+16)\n--\n啟用 ID 0 和 2, 輸入 5 (1+4)\n啟用 ID 1 和 3, 輸入 10 (2+8)\n啟用 ID 2 和 4, 輸入 20 (4+16)\n--\n啟用 ID 0 和 3, 輸入 9 (1+8)\n啟用 ID 1 和 4, 輸入 18 (2+16)\n--\n啟用 ID 1 2 3 4, 輸入 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\n下次還顯示此頁面嗎？"
    pu_head = "注意事項: \n\n"
  else
    pu_name = "Set MIDI Output Devices"
    pu_text = "This script will set the MIDI hardware output and exit REAPER,\nPlease make sure the project is saved.\nPlease manually restart REAPER after finishing!\n\nSet Enable Output:\n\nEnable ID 0, input 1\nEnable ID 1, input 2\nEnable ID 2, input 4\nEnable ID 3, input 8\nEnable ID 4, input 16\n--\nEnable ID 0 and 1, input 3 (1+2, sum of corresponding ID values)\nEnable ID 1 and 2, input 6 (2+4)\nEnable ID 2 and 3, input 12 (4+8)\nEnable ID 3 and 4, input 24 (8+16)\n--\nEnable ID 0 and 2, input 5 (1+4)\nEnable ID 1 and 3, input 10 (2+8)\nEnable ID 2 and 4, input 20 (4+16)\n--\nEnable ID 0 and 3, input 9 (1+8)\nEnable ID 1 and 4, input 18 (2+16)\n--\nEnable IDs 1, 2, 3, and 4, input 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\nWill this page be displayed next time?"
    pu_head = "Attention: \n\n"
  end

  local box_ok = reaper.ShowMessageBox(pu_head .. pu_text, pu_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("SET_MIDI_OUTPUT_DEVICES", "ShowMsg", show_msg, true)
  end
end

path = reaper.GetExePath()
devout_num = 1

-- 收集当前存在的MIDI输出设备并构建ID字符串
devtb = {}
id = ''
for i = 0, reaper.GetNumMIDIOutputs()-1 do
  local retval, name = reaper.GetMIDIOutputName(i, '')
  if retval then
    table.insert(devtb, name)
    id = id .. (i) .. ',' -- 添加设备ID到id字符串
  end
end

midi_out = 15 -- 默认激活ID 0-3 的MIDI硬件输出

-- 构建用户输入界面的字符串
local input_title = ''
local input_fields = #devtb + 1 -- 设备数量 + 1（用于输入选择）
local input_caption = ''

if language == "简体中文" then
  input_title = "设置MIDI输出设备"
  enable_out = "启用设备:"
  show_msg1 = "没有进行任何修改。"
  show_msg1_t = "提示"
  show_msg2 = "禁止输入相同的ID!"
  show_msg2_t = "错误"
  show_msg3 = "ID值限定在0-"
  show_msg3_t = "错误"
elseif language == "繁體中文" then
  input_title = "設置MIDI輸出設備"
  enable_out = "啓用設備:"
  show_msg1 = "沒有進行任何修改。"
  show_msg1_t = "提示"
  show_msg2 = "禁止輸入相同的ID!"
  show_msg2_t = "錯誤"
  show_msg3 = "ID值限定在0-"
  show_msg3_t = "錯誤"
else
  input_title = "Set MIDI Output Devices"
  enable_out = "Enable Devices:"
  show_msg1 = "No changes were made."
  show_msg1_t = "Notice"
  show_msg2 = "Entering duplicate IDs is prohibited!"
  show_msg2_t = "Error"
  show_msg3 = "ID values must be between 0 and "
  show_msg3_t = "Error"
end

for i, name in ipairs(devtb) do
  input_caption = input_caption .. (i) .. ': ' .. name .. ','
end
input_caption = input_caption .. enable_out

-- 获取用户输入
ret, inp_str = reaper.GetUserInputs(input_title, input_fields, input_caption, id .. midi_out)
if not ret then return end

-- 分割用户输入的字符串
local userInputIDs = {}
for id in string.gmatch(inp_str, '([^,]+)') do
  table.insert(userInputIDs, tonumber(id))
end

-- 检查用户输入是否与当前设备ID一致
local isSame = true
for i = 1, #devtb do
  if userInputIDs[i] ~= i-1 then  -- 检查每个设备ID是否一致
    isSame = false
    break
  end
end

-- 如果用户输入与当前设备ID一致，显示提示
if isSame then
  reaper.ShowMessageBox(show_msg1, show_msg1_t, 0)
  return  -- 终止脚本
end

operatingSystem = reaper.GetOS()
if operatingSystem ~= "Win32" and operatingSystem ~= "Win64" then
  r = os.remove(path .. "/reaper-midihw.ini")
else
  r = os.remove(path .. "\\reaper-midihw.ini")
end

t = {}
for word in inp_str:gmatch("([^,]*)") do -- 获取用户输入值
  t[#t+1]=word
end

t1={}
t2=t
t3={}
-- table.sort(t2) -- 如果执行排序将导致用户输入的值被打乱
for key, v in pairs(t2) do -- 计算相同值的个数，大于 0 弹出提示
  if t1[t2[key]] == nil then
    t1[t2[key]] = 0 -- 如果没有相同的值会得到 0
  else
    t1[t2[key]] = t1[t2[key]] + 1 -- 统计相同的值的个数
  end
  if key ~= #t2 then
  if t1[t2[key]] > 0 then return reaper.MB(show_msg2, show_msg2_t, 0) end
  end
end

for i = 1, #devtb do
  if tonumber(t[i]) > #devtb-1 then return reaper.MB(show_msg3..#devtb-1, show_msg3_t, 0) end
  key = 'on' .. t[i]
  value = devtb[i]
  if os ~= "Win32" and os ~= "Win64" then
    reaper.BR_Win32_WritePrivateProfileString('mididevcache', key, value, path .. "/reaper-midihw.ini")
  else
    reaper.BR_Win32_WritePrivateProfileString('mididevcache', key, value, path .. "\\reaper-midihw.ini")
  end
end

-- 启用MIDI硬件输出
if os ~= "Win32" and os ~= "Win64" then
  file = reaper.GetResourcePath() .. "/" .. "reaper.ini"
else
  file = reaper.GetResourcePath() .. "\\" .. "reaper.ini"
end

local f = io.open(file, "r")
local content = f:read('*all')
f:close()
content = string.gsub(content, "midiouts=(%d+)", "midiouts="..t[#devtb+1]) -- 将表格最后一个参数应用到MIDI输出
f = io.open(file, "w")
f:write(content)
f:close()
reaper.Main_OnCommand(40004, 0) -- File: Quit REAPER