-- @description Set MIDI Out Devices
-- @version 1.0.2
-- @author zaibuyidao, YS
-- @changelog
--   + Add Multi-Language Support
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  for _, v in ipairs({...}) do
    reaper.ShowConsoleMsg(tostring(v) .. " ")
  end
  reaper.ShowConsoleMsg("\n")
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

local language = getSystemLanguage()

if language == "简体中文" then
  swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
  swserr = "警告"
  jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
  jstitle = "你必须安裝 JS_ReaScriptAPI"
elseif language == "繁體中文" then
  swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
  swserr = "警告"
  jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
  jstitle = "你必須安裝 JS_ReaScriptAPI"
else
  swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
  swserr = "Warning"
  jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
  jstitle = "You must install JS_ReaScriptAPI"
end

if not reaper.SN_FocusMIDIEditor then
  local retval = reaper.ShowMessageBox(swsmsg, swserr, 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Window_Find") then
  reaper.MB(jsmsg, jstitle, 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, jserr, 0)
  end
  return reaper.defer(function() end)
end

local show_msg = reaper.GetExtState("SET_MIDI_OUT_DEVICES", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    pu_name = "设置MIDI硬件输出"
    pu_text = "该脚本将设置MIDI硬件输出并退出REAPER,\n请确保项目已保存.\n完成后请手动重启REAPER!\n\n设置启用输出:\n\n启用 ID 0, 输入 1\n启用 ID 1, 输入 2\n启用 ID 2, 输入 4\n启用 ID 3, 输入 8\n启用 ID 4, 输入 16\n--\n启用 ID 0 和 1, 输入 3 (1+2, ID对应的值相加)\n启用 ID 1 和 2, 输入 6 (2+4)\n启用 ID 2 和 3, 输入 12 (4+8)\n启用 ID 3 和 4, 输入 24 (8+16)\n--\n启用 ID 0 和 2, 输入 5 (1+4)\n启用 ID 1 和 3, 输入 10 (2+8)\n启用 ID 2 和 4, 输入 20 (4+16)\n--\n启用 ID 0 和 3, 输入 9 (1+8)\n启用 ID 1 和 4, 输入 18 (2+16)\n--\n启用 ID 1 2 3 4, 输入 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\n下次还显示此页面吗？"
    pu_head = "注意事项: \n\n"
  elseif language == "繁體中文" then
    pu_name = "設置MIDI硬件輸出"
    pu_text = "該腳本將設置MIDI硬件輸出並退出REAPER,\n請確保項目已保存.\n完畢後請手動重啟REAPER!\n\n設置啟用輸出:\n\n啟用 ID 0, 輸入 1\n啟用 ID 1, 輸入 2\n啟用 ID 2, 輸入 4\n啟用 ID 3, 輸入 8\n啟用 ID 4, 輸入 16\n--\n啟用 ID 0 和 1, 輸入 3 (1+2, ID对应的值相加)\n啟用 ID 1 和 2, 輸入 6 (2+4)\n啟用 ID 2 和 3, 輸入 12 (4+8)\n啟用 ID 3 和 4, 輸入 24 (8+16)\n--\n啟用 ID 0 和 2, 輸入 5 (1+4)\n啟用 ID 1 和 3, 輸入 10 (2+8)\n啟用 ID 2 和 4, 輸入 20 (4+16)\n--\n啟用 ID 0 和 3, 輸入 9 (1+8)\n啟用 ID 1 和 4, 輸入 18 (2+16)\n--\n啟用 ID 1 2 3 4, 輸入 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\n下次還顯示此頁面嗎？"
    pu_head = "注意事項: \n\n"
  else
    pu_name = "Set MIDI Hardware Output"
    pu_text = "This script will set the MIDI hardware output and exit REAPER,\nPlease make sure the project is saved.\nPlease manually restart REAPER after finishing!\n\nSet Enable Output:\n\nEnable ID 0, input 1\nEnable ID 1, input 2\nEnable ID 2, input 4\nEnable ID 3, input 8\nEnable ID 4, input 16\n--\nEnable ID 0 and 1, input 3 (1+2, sum of corresponding ID values)\nEnable ID 1 and 2, input 6 (2+4)\nEnable ID 2 and 3, input 12 (4+8)\nEnable ID 3 and 4, input 24 (8+16)\n--\nEnable ID 0 and 2, input 5 (1+4)\nEnable ID 1 and 3, input 10 (2+8)\nEnable ID 2 and 4, input 20 (4+16)\n--\nEnable ID 0 and 3, input 9 (1+8)\nEnable ID 1 and 4, input 18 (2+16)\n--\nEnable IDs 1, 2, 3, and 4, input 15 (1+2+4+8)\n"
    pu_text = pu_text .. "\nWill this page be displayed next time?"
    pu_head = "Attention: \n\n"
  end

  local box_ok = reaper.ShowMessageBox(pu_head .. pu_text, pu_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("SET_MIDI_OUT_DEVICES", "ShowMsg", show_msg, true)
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
  enable_out = "设置启用输出:"
  show_msg1 = "没有进行任何修改。"
  show_msg1_t = "提示"
  show_msg2 = "禁止输入相同的ID!"
  show_msg2_t = "错误"
  show_msg3 = "ID值限定在0-"
  show_msg3_t = "错误"
elseif language == "繁體中文" then
  input_title = "設置MIDI輸出設備"
  enable_out = "設置啓用輸出:"
  show_msg1 = "沒有進行任何修改。"
  show_msg1_t = "提示"
  show_msg2 = "禁止輸入相同的ID!"
  show_msg2_t = "錯誤"
  show_msg3 = "ID值限定在0-"
  show_msg3_t = "錯誤"
else
  input_title = "Set MIDI Out Devices"
  enable_out = "Set Enable Output:"
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