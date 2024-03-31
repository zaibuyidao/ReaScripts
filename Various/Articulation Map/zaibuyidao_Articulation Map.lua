-- NoIndex: true
local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = package.path .. ";" .. script_path .. "?.lua" .. ";" .. script_path .. "/lib/?.lua"

require('core')
require('utils')
CONFIG = require('config')
gui = require('gui')
-- 导入gui类
local Button = gui.Button
local Knob = gui.Knob
local Slider = gui.Slider
local Rng_Slider = gui.Rng_Slider
local Frame = gui.Frame
local CheckBox = gui.CheckBox
local Textbox = gui.Textbox

initialTrack = getActiveMIDITrack()
EXT_SECTION = 'ARTICULATION_MAP'

local delimiter = getPathDelimiter()
local language = getSystemLanguage()

function openUrl(url)
    local osName = reaper.GetOS()
    if osName:match("^OSX") then
        os.execute('open "" "' .. url .. '"')
    else
        -- chcp 65001
        os.execute('start "" "' .. url .. '"')
    end
end

function getConfig(configName, default, convert)
	local cur = CONFIG
	for k in configName:gmatch("[^%.]+") do
		if not cur then return default end
		cur = cur[k]
	end
	if cur == nil then return default end
	if convert then
		return convert(cur)
	end
	return cur
end

if language == "简体中文" then
    WINDOW_TITLE = getConfig("ui.global.title.cn")
    GLOBAL_FONT = getConfig("ui.global.font.cn")
    FONT_SIZE = getConfig("ui.global.font_size.cn", 12)
    swsmsg = "该脚本需要 SWS 扩展，你想现在就下载它吗？"
    swserr = "警告"
    jsmsg = "请右键单击並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    jstitle = "你必须安裝 JS_ReaScriptAPI"
    checkamjs_msg = "请右键单击並安裝 'Articulation Map.jsfx' (请注意分类为JSFX)。\n然后重新启动 REAPER 並再次运行脚本，谢谢！\n"
    checkamjs_title = "你必须安裝 Articulation Map.jsfx"
    jserr = "错误"
    setpc_title = "设置音色库/程序选择"
    setpc_retvals_csv = "音色库 MSB (分组):,音色库 LSB (力度):,程序编号 (音符):"
    shift_retvals_csv = "音色库编号:,程序编号:"
    selbank_path = "选择音色表"
    patch_change_load = "加载文件"
    patch_change_OK = "确定"
    patch_change_Cancel = "取消"
    patch_change_channel = "MIDI 通道:"
    patch_change_bank = "乐库:"
    patch_change_patch = "音色:"
    setbank2_msg = "无法读取 REAPER 的 ini 文件"
    setbank2_err = "错误"
    setbank2_msg2 = "写入 ini 文件失败"
    update_rbf_msg = "ReaBank 音色表文件已更新。"
    update_rbf_ttl = "更新成功"
    bank_msb_lsb = "音色库 MSB/LSB:"
    bank_program_num = "程序编号:"
    send_now_ttl = "立即发送"
    not_loaded = "JS 未加载"
    line_velocity = "力度"
    no_patch_load = "<未加载音色文件>"
    no_bank_sel = "未选择音色库"
    no_patch_sel = "未选择音色"
elseif language == "繁體中文" then
    WINDOW_TITLE = getConfig("ui.global.title.tw")
    GLOBAL_FONT = getConfig("ui.global.font.tw")
    FONT_SIZE = getConfig("ui.global.font_size.tw", 12)
    swsmsg = "該脚本需要 SWS 擴展，你想現在就下載它嗎？"
    swserr = "警告"
    jsmsg = "請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    jstitle = "你必須安裝 JS_ReaScriptAPI"
    checkamjs_msg = "請右鍵單擊並安裝 'Articulation Map.jsfx' (請注意分類為JSFX)。\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n"
    checkamjs_title = "你必须安裝 Articulation Map.jsfx"
    jserr = "錯誤"
    setpc_title = "设置音色庫/程式選擇"
    setpc_retvals_csv = "音色庫 MSB (分組):,音色庫 LSB (力度):,程式編號 (音符):"
    shift_retvals_csv = "音色庫編號:,程式編號:"
    selbank_path = "選擇音色表"
    patch_change_load = "加載文件"
    patch_change_OK = "確定"
    patch_change_Cancel = "取消"
    patch_change_channel = "MIDI 通道:"
    patch_change_bank = "樂庫:"
    patch_change_patch = "音色:"
    setbank2_msg = "無法讀取 REAPER 的 ini 文件"
    setbank2_err = "錯誤"
    setbank2_msg2 = "寫入 ini 文件失敗"
    update_rbf_msg = "ReaBank 音色表文件已更新。"
    update_rbf_ttl = "更新成功"
    bank_msb_lsb = "音色庫 MSB/LSB:"
    bank_program_num = "程式编号:"
    send_now_ttl = "立即發送"
    not_loaded = "JS 未加載"
    line_velocity = "力度"
    no_patch_load = "<未加載音色文件>"
    no_bank_sel = "未選擇音色庫"
    no_patch_sel = "未選擇音色"
else
    WINDOW_TITLE = getConfig("ui.global.title.en")
    GLOBAL_FONT = getConfig("ui.global.font.en")
    FONT_SIZE = getConfig("ui.global.font_size.en", 14)
    swsmsg = "This script requires the SWS Extension. Do you want to download it now?"
    swserr = "Warning"
    jsmsg = "Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\nThen restart REAPER and run the script again, thank you!\n"
    jstitle = "You must install JS_ReaScriptAPI"
    checkamjs_msg = "Please right-click and install 'Articulation Map.jsfx' (Please note the category should be JSFX).\nThen restart REAPER and run the script again, thank you!\n"
    checkamjs_title = "You must install Articulation Map.jsfx"
    jserr = "Error"
    setpc_title = "Set Bank/Program select"
    setpc_retvals_csv = "Bank MSB (Group):,Bank LSB (Velocity):,Program number (Note):"
    shift_retvals_csv = "Bank number:,Program number:"
    selbank_path = "Choose a reabank"
    patch_change_load = "Load File"
    patch_change_OK = "OK"
    patch_change_Cancel = "Cancel"
    patch_change_channel = "MIDI channel:"
    patch_change_bank = "Bank :"
    patch_change_patch = "Patch:"
    setbank2_msg = "Failed to read REAPER's ini file"
    setbank2_err = "Error"
    setbank2_msg2 = "Failed to write ini file"
    update_rbf_msg = "ReaBank file has been updated."
    update_rbf_ttl = "Update Successful"
    bank_msb_lsb = "Bank MSB/LSB:"
    bank_program_num = "Program number:"
    send_now_ttl = "Send Now"
    not_loaded = "JS Not Load"
    line_velocity = "Vel "
    no_patch_load = "<no patch file loaded>"
    no_bank_sel = "no bank selected"
    no_patch_sel = "no patch selected"
end

vel_show = getConfig("ui.global.vel_show")
bnk_show = getConfig("ui.global.bnk_show")
lock_gui = getConfig("ui.global.lock_gui")

if not reaper.SNM_GetIntConfigVar then
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

-- checkArticulationMapJSFX() -- 检查是否安装 JSFX

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not take or not reaper.TakeIsMIDI(take) then return end

reabank_path, bank_name = selectReaBankFile() -- 全局REABANK
if not reabank_path then return end
if initialTrack then
    local result = applyReaBankToTrack(initialTrack, reabank_path)
    if not result then
        -- 如果 reabankPath 是 "NoReabank"，则显示特定的提示
        if reabank_path == "NoReabank" then
            bank_name = no_patch_load -- 设置提示信息
        else
            print("Failed to apply ReaBank to the active MIDI track.")
        end
    end
end

function getNote(sel) -- 根据传入的sel索引值，返回指定位置的含有音符信息的表
    local retval, selected, muted, startPos, endPos, channel, pitch, vel = reaper.MIDI_GetNote(take, sel)
    return {
        ["retval"]=retval,
        ["selected"]=selected,
        ["muted"]=muted,
        ["startPos"]=startPos,
        ["endPos"]=endPos,
        ["channel"]=channel,
        ["pitch"]=pitch,
        ["vel"]=vel,
        ["sel"]=sel
    }
end

function setNote(note,sel,arg) -- 传入一个音符信息表已经索引值，对指定索引位置的音符信息进行修改
    reaper.MIDI_SetNote(take,sel,note["selected"],note["muted"],note["startPos"],note["endPos"],note["channel"],note["pitch"],note["vel"],arg or false)
end

function selNoteIterator() -- 迭代器 用于返回选中的每一个音符信息表
    local sel=-1
    return function()
        sel=reaper.MIDI_EnumSelNotes(take, sel)
        if sel==-1 then return end
        return getNote(sel)
    end
end

function getMutiInput(title,num,lables,defaults)
    title=title or "Title"
    lables=lables or "Lable:"
    local userOK, getValue = reaper.GetUserInputs(title, num, lables, defaults)
    if userOK then return string.split(getValue,",") end
end

-- 读取 JSFX 延音控制器值
reaper.gmem_attach('gmem_articulation_map')
gmem_cc_num = reaper.gmem_read(1)
gmem_cc_num = math.floor(gmem_cc_num)
gmem_cc58_num = reaper.gmem_read(2)
gmem_cc58_num = math.floor(gmem_cc58_num)

local track = reaper.GetMediaItemTake_Track(take)
local pand = reaper.TrackFX_AddByName(track, "Articulation Map", false, 0)
if pand < 0 then
    gmem_cc_num = "119"
end

-- For Saving ExtState
function pickle(t)
	return Pickle:clone():pickle_(t)
end

Pickle = {
	clone = function (t) local nt = {}
	for i, v in pairs(t) do 
		nt[i] = v 
	end
	return nt 
end 
}

function Pickle:pickle_(root)
	if type(root) ~= "table" then 
		error("can only pickle tables, not " .. type(root) .. "s")
	end
	self._tableToRef = {}
	self._refToTable = {}
	local savecount = 0
	self:ref_(root)
	local s = ""
	while #self._refToTable > savecount do
		savecount = savecount + 1
		local t = self._refToTable[savecount]
		s = s .. "{\n"
		for i, v in pairs(t) do
			s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
		end
	s = s .. "},\n"
	end
	return string.format("{%s}", s)
end

function Pickle:value_(v)
	local vtype = type(v)
	if     vtype == "string" then return string.format("%q", v)
	elseif vtype == "number" then return v
	elseif vtype == "boolean" then return tostring(v)
	elseif vtype == "table" then return "{"..self:ref_(v).."}"
	else error("pickle a " .. type(v) .. " is not supported")
	end 
end

function Pickle:ref_(t)
	local ref = self._tableToRef[t]
	if not ref then 
		if t == self then error("can't pickle the pickle class") end
		table.insert(self._refToTable, t)
		ref = #self._refToTable
		self._tableToRef[t] = ref
	end
	return ref
end

-- unpickle
function unpickle(s)
	if type(s) ~= "string" then
		error("can't unpickle a " .. type(s) .. ", only strings")
	end
	local gentables = load("return " .. s)
	local tables = gentables()
	for tnum = 1, #tables do
		local t = tables[tnum]
		local tcopy = {}
		for i, v in pairs(t) do tcopy[i] = v end
		for i, v in pairs(tcopy) do
			local ni, nv
			if type(i) == "table" then ni = tables[i[1]] else ni = i end
			if type(v) == "table" then nv = tables[v[1]] else nv = v end
			t[i] = nil
			t[ni] = nv
		end
	end
	return tables[1]
end

-- 设置当前的界面风格
style = CONFIG.ui.global.style
local colorConfig = CONFIG.ui.global.color[style]

if colorConfig then
    theme_bt = colorConfig.theme_bt
    theme_txt = colorConfig.theme_txt
    theme_frame = colorConfig.theme_frame
    theme_jsfx = colorConfig.theme_jsfx
end

-- 边框位置顺时钟左, 上, 右, 下
-- 更新按钮创建
local btn1 = Button:new(10,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "A", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 A
local btn4 = Button:new(45,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "B", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 B
local btn5 = Button:new(80,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "<", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 左移
local btn6 = Button:new(115,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], ">", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 右移
local btn7 = Button:new(150,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "NP", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 Toggle Between Note and PC, Note-PC Toggle
local btn10 = Button:new(185,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "PC", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 程序更改
local btn9 = Button:new(220,10,25,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "ER", GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 Editing Reabank
local btn11 = Button:new(255,10,75,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], "SC:CC#" .. gmem_cc_num, GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 JSFX
local btn12 = Button:new(255,185,75,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], send_now_ttl, GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 Send Now
local btn8 = Button:new(10,255,100,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], patch_change_load, GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 加载文件
local btn2 = Button:new(120,255,100,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], patch_change_OK, GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 OK
local btn3 = Button:new(230,255,100,25, theme_bt[1], theme_bt[2], theme_bt[3], theme_bt[4], patch_change_Cancel, GLOBAL_FONT, FONT_SIZE, 0, 0) -- 按钮 取消
local Button_TB = { btn1, btn2, btn3, btn4, btn5, btn6, btn7, btn8, btn9, btn10, btn11, btn12 }

-- 更新复选框创建
local ch_box1 = CheckBox:new(50,45,280,25,  theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], patch_change_bank, GLOBAL_FONT, FONT_SIZE, 1, {})
local ch_box2 = CheckBox:new(50,80,280,25,  theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], patch_change_patch, GLOBAL_FONT, FONT_SIZE, 1, {})
local ch_box3 = CheckBox:new(170,115,160,25,  theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], patch_change_channel, GLOBAL_FONT, FONT_SIZE, 1, {"1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"})
local CheckBox_TB = { ch_box1, ch_box2, ch_box3 }

-- 更新外框创建
local W_Frame = Frame:new(10,10,320,270, theme_frame[1], theme_frame[2], theme_frame[3], theme_frame[4]) -- 外框线尺寸
local Frame_TB = { W_Frame }

-- 更新文本框创建
local text_bank = Textbox:new(10,220,320,25, theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], bank_name, GLOBAL_FONT, FONT_SIZE, 1, 0, "")
local textb_1 = Textbox:new(170,150,75,25, theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], "", GLOBAL_FONT, FONT_SIZE, 1, 0, bank_msb_lsb) -- "Bank MSB"
local textb_2 = Textbox:new(255,150,75,25, theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], "", GLOBAL_FONT, FONT_SIZE, 1, 0, "") -- "Bank LSB"
local textb_3 = Textbox:new(170,185,75,25, theme_txt[1], theme_txt[2], theme_txt[3], theme_txt[4], "", GLOBAL_FONT, FONT_SIZE, 1, 0, bank_program_num) -- "Program number"
local Textbox_TB = { text_bank, textb_1, textb_2, textb_3 }

btn3.onClick = function () -- 按钮 退出
    gfx.quit()
    reaper.SN_FocusMIDIEditor()
end

btn7.onClick = function () toggleNoteToPC() end -- 按钮 NOTE/PC 来回切

if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
local store = parse_banks(read_config_lines(reabank_path), vel_show, bnk_show) -- 模式1数据
local store_grouped = group_banks(store, vel_show, bnk_show)                   -- 模式2数据
local current_state         -- 当前选中的参数
local current_mode = "1"    -- 当前模式

local function push_current_state() -- 保存当前状态
    if current_state then -- 新增判断
        reaper.SetProjExtState(0, EXT_SECTION, "baseState", pickle(current_state))
    end
    reaper.SetProjExtState(0, EXT_SECTION, "baseStateMode", current_mode)
end

local function pop_current_state()  -- 读出当前状态
    local _, baseStateStr = reaper.GetProjExtState(0, EXT_SECTION, "baseState")
    if baseStateStr ~= "" then
        current_state = unpickle(baseStateStr)
    end

    local _, r = reaper.GetProjExtState(0, EXT_SECTION, "baseStateMode")
    if r ~= "" then
        current_mode = r
    else 
        current_mode = "1"
    end
end

local function switch_mode_1() -- 模式1 切换
    local function update_current_state()
        if not store or not ch_box1 or not ch_box2 or
            not store[ch_box1.norm_val] or 
            not store[ch_box1.norm_val].bank or
            not store[ch_box1.norm_val].notes or 
            not store[ch_box1.norm_val].notes[ch_box2.norm_val] then
            return -- 如果相关数据不存在，直接返回
        end
        current_state = {
            velocity = store[ch_box1.norm_val].bank.velocity,
            note = store[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store[ch_box1.norm_val].bank.bank
        }
        push_current_state()
    end

    -- 检查并更新 ch_box1 和 ch_box2
    if store[1] and store[1].bank and store[1].bank.full_name == no_bank_sel then
        ch_box1.norm_val2 = {no_patch_sel}
        ch_box1.norm_val = 1
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.velocity)==tonumber(current_state.velocity) and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    local bank_item = store[ch_box1.norm_val]
    if bank_item and bank_item.bank then
        textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
        textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    else
        textb_1.lbl = "N/A"
        textb_2.lbl = "N/A"
    end

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store[bank_index] or (store[1] and store[1].bank and store[1].bank.full_name == no_bank_sel) then
            -- 如果 store[bank_index] 不存在或者是 '未选择音色库' 情况
            ch_box2.norm_val = 1
            ch_box2.norm_val2 = {no_patch_sel}  -- 或者任何合适的提示
            textb_3.lbl = "N/A"
            return -- 提前结束函数
        end
    
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) then
                selected = i
            end
        end
    
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    
        -- 更新 textb_3 的标签
        if store[bank_index] and store[bank_index].notes[selected] then
            textb_3.lbl = store[bank_index].notes[selected].note
        else
            textb_3.lbl = "N/A"
        end
    end
    
    
    update_patch_box()

    ch_box1.onClick = function()
        if not store or not ch_box1 then return end -- 添加检查
        -- 更新每个 bank_item 的 msb 和 lsb 属性
        local bank_item = store[ch_box1.norm_val]
        if bank_item and bank_item.bank then
            -- 更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
            textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
            textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
        end

        update_patch_box()
        update_current_state()
    end

    ch_box2.onClick = function()
        if not store or not ch_box1 or not ch_box2 or
            not store[ch_box1.norm_val] or
            not store[ch_box1.norm_val].notes or 
            not store[ch_box1.norm_val].notes[ch_box2.norm_val] then
                return -- 如果相关数据不存在，直接返回
        end

        -- 更新 textb_3 的标签
        local selected_note = store[ch_box1.norm_val].notes[ch_box2.norm_val]
        if selected_note then
            textb_3.lbl = selected_note.note
        end

        update_current_state()
    end

    btn2.onClick = function () -- 插入音色
        local bank_item = store[ch_box1.norm_val]
        -- 检查是否有选中的bank_item和note_item
        if not bank_item or not bank_item.notes or not bank_item.notes[ch_box2.norm_val] then
            -- reaper.ShowMessageBox("没有选中有效的音色库或程序。", "错误", 0)
            return
        end
    
        local note_item = bank_item.notes[ch_box2.norm_val]
        -- 这里bank_item和note_item都已经验证为非nil
        inset_patch(bank_item.bank.bank, note_item.note, bank_item.bank.velocity, midi_chan)
        -- gfx.quit()
    end

    btn12.onClick = function () -- 立即发送
        local bank_item = store[ch_box1.norm_val]
        -- 检查是否有选中的bank_item和note_item
        if not bank_item or not bank_item.notes or not bank_item.notes[ch_box2.norm_val] then
            -- reaper.ShowMessageBox("没有选中有效的音色库或程序。", "错误", 0)
            return
        end

        local note_item = bank_item.notes[ch_box2.norm_val]
        local channel = ch_box3.norm_val

        reaper.StuffMIDIMessage(0, 0xB0 + (channel - 1), 0x00, tonumber(bank_item.bank.bank)) -- MSB
        reaper.StuffMIDIMessage(0, 0xB0 + (channel - 1), 0x20, tonumber(bank_item.bank.velocity)) -- LSB
        reaper.StuffMIDIMessage(0, 0xC0 + (channel - 1), tonumber(note_item.note), 0) -- Program

        -- reaper.MB("Bank and Program have been sent successfully", "Confirmation", 0)
    end
end

local function switch_mode_2() -- 模式2 切换
    local function update_current_state()
        if not store_grouped or not ch_box1 or not ch_box2 or
            not store_grouped[ch_box1.norm_val] or
            not store_grouped[ch_box1.norm_val].notes or
            not store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val] then
            return -- 如果相关数据不存在，直接返回
        end

        current_state = {
            velocity = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].velocity,
            note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].bank
        }
        push_current_state()
    end

    -- 检查并更新 ch_box1 和 ch_box2（如果需要）
    if store_grouped[1] and store_grouped[1].bank and store_grouped[1].bank.full_name == no_bank_sel then
        ch_box1.norm_val2 = {no_bank_sel}
        ch_box1.norm_val = 1
        ch_box2.norm_val2 = {no_bank_sel}  -- 如果ch_box2也需要更新
        ch_box2.norm_val = 1
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store_grouped) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    -- local bank_item = store_grouped[ch_box1.norm_val]
    -- if bank_item and bank_item.bank then
    --     textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
    --     textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    -- else
    --     textb_1.lbl = "N/A"
    --     textb_2.lbl = "N/A"
    -- end

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store_grouped[bank_index] or (store_grouped[1] and store_grouped[1].bank and store_grouped[1].bank.full_name == no_bank_sel) then
            -- 没有有效的bank数据或未选择音色库
            ch_box2.norm_val = 1
            ch_box2.norm_val2 = {no_patch_sel}
            textb_1.lbl = "N/A"  -- MSB
            textb_2.lbl = "N/A"  -- LSB
            textb_3.lbl = "N/A"  -- Program
            return
        end

        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store_grouped[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) and tonumber(note_item.velocity) == tonumber(current_state.velocity) then
                selected = i
            end
        end

        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles

        local selected_note = store_grouped[bank_index].notes[selected]
        if selected_note then
            textb_1.lbl = tostring(selected_note.bank)      -- MSB
            textb_2.lbl = tostring(selected_note.velocity)  -- LSB
            textb_3.lbl = tostring(selected_note.note)      -- Note
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
            textb_3.lbl = "N/A"
        end
    end
    
    update_patch_box()

    ch_box1.onClick = function()
        if not store_grouped or not ch_box1 then return end -- 添加检查
        -- 更新每个 bank_item 的 msb 和 lsb 属性
        local bank_item = store_grouped[ch_box1.norm_val]
        if bank_item and bank_item.bank then
            textb_1.lbl = tostring(bank_item.bank.bank) -- 更新 MSB
        end

        update_patch_box() -- 更新 patch box 和 textb_3.lbl
        update_current_state()
    end

    ch_box2.onClick = function()
        if not store_grouped or not ch_box1 or not ch_box2 or
            not store_grouped[ch_box1.norm_val] or
            not store_grouped[ch_box1.norm_val].notes or
            not store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val] then
                return -- 如果相关数据不存在，直接返回
        end
        -- 更新 textb_3 的标签和 textb_2.lbl（LSB）
        local selected_note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
        if selected_note then
            textb_3.lbl = selected_note.note

            -- 如果 LSB 存在于 selected_note 中，则更新 textb_2.lbl
            if selected_note.velocity then
                textb_2.lbl = tostring(selected_note.velocity)
            else
                textb_2.lbl = "N/A"
            end
        end

        update_current_state()
    end

    btn2.onClick = function ()
        local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
        if not note_item then
            -- reaper.ShowMessageBox("没有选中有效的音色。", "错误", 0)
            return
        end
        inset_patch(note_item.bank, note_item.note, note_item.velocity, midi_chan)
        -- gfx.quit()
    end

    btn12.onClick = function () -- 立即发送
        local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
        if not note_item then
            -- reaper.ShowMessageBox("没有选中有效的音色。", "错误", 0)
            return
        end
        local channel = ch_box3.norm_val

        reaper.StuffMIDIMessage(0, 0xB0 + (channel - 1), 0x00, tonumber(note_item.bank)) -- MSB
        reaper.StuffMIDIMessage(0, 0xB0 + (channel - 1), 0x20, tonumber(note_item.velocity)) -- LSB
        reaper.StuffMIDIMessage(0, 0xC0 + (channel - 1), tonumber(note_item.note), 0) -- Program

        -- reaper.MB("Bank and Program have been sent successfully", "Confirmation", 0)
    end
end

local function setCheckBoxMode1()
    local function update_current_state()
        current_state = {
            velocity = store[ch_box1.norm_val].bank.velocity,
            note = store[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store[ch_box1.norm_val].bank.bank
        }
        push_current_state()
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.velocity)==tonumber(current_state.velocity) and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    local bank_item = store[ch_box1.norm_val]
    if bank_item and bank_item.bank then
        textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
        textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    else
        textb_1.lbl = "N/A"
        textb_2.lbl = "N/A"
    end

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) then
                selected = i
            end
        end
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    
        -- 更新 textb_3 的标签
        if store[bank_index] and store[bank_index].notes[selected] then
            textb_3.lbl = store[bank_index].notes[selected].note
        else
            textb_3.lbl = "N/A" -- 或者其他默认值
        end
    end

    -- 检查是否有有效的 bank、velocity 和 program
    if textb_1.lbl == "N/A" or textb_2.lbl == "N/A" or textb_3.lbl == "N/A" then
        return -- 没有有效的 bank、velocity 和 program，直接返回
    end

    local uok, uinput = reaper.GetUserInputs(setpc_title, 3, setpc_retvals_csv, textb_1.lbl ..','.. textb_2.lbl ..','.. textb_3.lbl)

    if uok then
        local msb, lsb, note = uinput:match("([^,]+),([^,]+),([^,]+)")
        msb = tonumber(msb)
        lsb = tonumber(lsb)
        note = tonumber(note)

        -- 查找匹配的 bank_item
        local new_bank_index
        for i, bank_item in ipairs(store) do
            if tonumber(bank_item.bank.bank) == msb and tonumber(bank_item.bank.velocity) == lsb then
                new_bank_index = i
                break
            end
        end

        -- 查找匹配的 note_item
        local new_note_index
        if new_bank_index and store[new_bank_index] and store[new_bank_index].notes then
            for i, note_item in ipairs(store[new_bank_index].notes) do
                if tonumber(note_item.note) == note then
                    new_note_index = i
                    break
                end
            end
        end

        -- 更新 ch_box1 和 ch_box2
        if new_bank_index and new_note_index then
            ch_box1.norm_val = new_bank_index
            ch_box2.norm_val = new_note_index

            -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
            local new_bank_item = store[new_bank_index]
            if new_bank_item and new_bank_item.bank then
                textb_1.lbl = tostring(new_bank_item.bank.bank) -- MSB
                textb_2.lbl = tostring(new_bank_item.bank.velocity) -- LSB
            else
                textb_1.lbl = "N/A"
                textb_2.lbl = "N/A"
            end

            -- 更新 textb_3 的标签
            local new_note_item = store[new_bank_index].notes[new_note_index]
            if new_note_item then
                textb_3.lbl = tostring(new_note_item.note)
            else
                textb_3.lbl = "N/A"
            end

            -- 可以在这里调用 update_current_state 和其他更新界面的函数
            update_current_state()
            update_patch_box() -- 假设这是更新UI的函数
        end
    end
end

local function setCheckBoxMode1Shift()
    local function update_current_state()
        current_state = {
            velocity = store[ch_box1.norm_val].bank.velocity,
            note = store[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store[ch_box1.norm_val].bank.bank
        }
        push_current_state()
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.velocity)==tonumber(current_state.velocity) and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    local bank_item = store[ch_box1.norm_val]
    if bank_item and bank_item.bank then
        textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
        textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    else
        textb_1.lbl = "N/A"
        textb_2.lbl = "N/A"
    end

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) then
                selected = i
            end
        end
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    
        -- 更新 textb_3 的标签
        if store[bank_index] and store[bank_index].notes[selected] then
            textb_3.lbl = store[bank_index].notes[selected].note
        else
            textb_3.lbl = "N/A" -- 或者其他默认值
        end
    end

    -- 检查是否有有效的 bank、velocity 和 program
    if textb_1.lbl == "N/A" or textb_2.lbl == "N/A" or textb_3.lbl == "N/A" then
        return -- 没有有效的 bank、velocity 和 program，直接返回
    end

    local bankNumber = tonumber(textb_1.lbl) * 128 + tonumber(textb_2.lbl)
    local uok, uinput = reaper.GetUserInputs(setpc_title, 2, shift_retvals_csv, tostring(bankNumber) .. ',' .. textb_3.lbl)

    if uok then
        bankNumber, note = uinput:match("([^,]+),([^,]+)")
        bankNumber = tonumber(bankNumber)
        note = tonumber(note)
        msb = math.floor(bankNumber / 128)
        lsb = bankNumber % 128

        -- 查找匹配的 bank_item
        local new_bank_index
        for i, bank_item in ipairs(store) do
            if tonumber(bank_item.bank.bank) == msb and tonumber(bank_item.bank.velocity) == lsb then
                new_bank_index = i
                break
            end
        end

        -- 查找匹配的 note_item
        local new_note_index
        if new_bank_index and store[new_bank_index] and store[new_bank_index].notes then
            for i, note_item in ipairs(store[new_bank_index].notes) do
                if tonumber(note_item.note) == note then
                    new_note_index = i
                    break
                end
            end
        end

        -- 更新 ch_box1 和 ch_box2
        if new_bank_index and new_note_index then
            ch_box1.norm_val = new_bank_index
            ch_box2.norm_val = new_note_index

            -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
            local new_bank_item = store[new_bank_index]
            if new_bank_item and new_bank_item.bank then
                textb_1.lbl = tostring(new_bank_item.bank.bank) -- MSB
                textb_2.lbl = tostring(new_bank_item.bank.velocity) -- LSB
            else
                textb_1.lbl = "N/A"
                textb_2.lbl = "N/A"
            end

            -- 更新 textb_3 的标签
            local new_note_item = store[new_bank_index].notes[new_note_index]
            if new_note_item then
                textb_3.lbl = tostring(new_note_item.note)
            else
                textb_3.lbl = "N/A"
            end

            -- 可以在这里调用 update_current_state 和其他更新界面的函数
            update_current_state()
            update_patch_box() -- 假设这是更新UI的函数
        end
    end
end

local function setCheckBoxMode2()
    local function update_current_state()
        current_state = {
            velocity = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].velocity,
            note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].bank
        }
        push_current_state()
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store_grouped) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    -- local bank_item = store_grouped[ch_box1.norm_val]
    -- if bank_item and bank_item.bank then
    --     textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
    --     --textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    -- else
    --     textb_1.lbl = "N/A"
    --     --textb_2.lbl = "N/A"
    -- end

    local function update_patch_box() -- 1
        local bank_index = ch_box1.norm_val
        if not store_grouped[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store_grouped[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) and tonumber(note_item.velocity) == tonumber(current_state.velocity) then
                selected = i
            end
        end

        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles

        local selected_note = store_grouped[bank_index].notes[selected]
        if selected_note then
            textb_1.lbl = tostring(selected_note.bank)      -- MSB
            textb_2.lbl = tostring(selected_note.velocity)  -- LSB
            textb_3.lbl = tostring(selected_note.note)      -- Note
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
            textb_3.lbl = "N/A"
        end
    end

    -- 检查是否有有效的 bank、velocity 和 program
    if textb_1.lbl == "N/A" or textb_2.lbl == "N/A" or textb_3.lbl == "N/A" then
        return -- 没有有效的 bank、velocity 和 program，直接返回
    end

    local uok, uinput = reaper.GetUserInputs(setpc_title, 3, setpc_retvals_csv, textb_1.lbl ..','.. textb_2.lbl ..','.. textb_3.lbl)

    if uok then
        local msb, lsb, note = uinput:match("([^,]+),([^,]+),([^,]+)")
        msb = tonumber(msb)
        lsb = tonumber(lsb)
        note = tonumber(note)

        -- 查找匹配的 bank_item (根据 MSB)
        local new_bank_index
        for i, bank_item in ipairs(store_grouped) do
            if tonumber(bank_item.bank.bank) == msb then
                new_bank_index = i
                break
            end
        end
    
        -- 查找匹配的 note_item (根据 LSB 和 Note)
        local new_note_index
        if new_bank_index and store_grouped[new_bank_index] and store_grouped[new_bank_index].notes then
            for i, note_item in ipairs(store_grouped[new_bank_index].notes) do
                if tonumber(note_item.note) == note and tonumber(note_item.velocity) == lsb then
                    new_note_index = i
                    break
                end
            end
        end
    
        -- 更新 ch_box1 和 ch_box2
        if new_bank_index and new_note_index then
            ch_box1.norm_val = new_bank_index
            ch_box2.norm_val = new_note_index
    
            -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
            local new_note_item = store_grouped[new_bank_index].notes[new_note_index]
            if new_note_item then
                textb_1.lbl = tostring(new_note_item.bank) -- MSB
                textb_2.lbl = tostring(new_note_item.velocity) -- LSB
                textb_3.lbl = tostring(new_note_item.note) -- Note
            else
                textb_1.lbl = "N/A"
                textb_2.lbl = "N/A"
                textb_3.lbl = "N/A"
            end
    
            update_current_state()
            update_patch_box() -- 更新UI
        end
    end
end

local function setCheckBoxMode2Shift()
    local function update_current_state()
        current_state = {
            velocity = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].velocity,
            note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].bank
        }
        push_current_state()
    end

    local bank_titles = {}
    local box1_index = 1
    for i, bank_item in ipairs(store_grouped) do
        table.insert(bank_titles, bank_item.bank.full_name)
        if current_state and tonumber(bank_item.bank.bank)==tonumber(current_state.bank) then
            box1_index = i
        end
    end

    ch_box1.norm_val = box1_index
    ch_box1.norm_val2 = bank_titles

    -- 在初始化时更新 textb_1 和 textb_2 的标签为 MSB 和 LSB
    -- local bank_item = store_grouped[ch_box1.norm_val]
    -- if bank_item and bank_item.bank then
    --     textb_1.lbl = tostring(bank_item.bank.bank) -- MSB
    --     --textb_2.lbl = tostring(bank_item.bank.velocity) -- LSB
    -- else
    --     textb_1.lbl = "N/A"
    --     --textb_2.lbl = "N/A"
    -- end

    local function update_patch_box() -- 1
        local bank_index = ch_box1.norm_val
        if not store_grouped[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store_grouped[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) and tonumber(note_item.velocity) == tonumber(current_state.velocity) then
                selected = i
            end
        end

        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles

        local selected_note = store_grouped[bank_index].notes[selected]
        if selected_note then
            textb_1.lbl = tostring(selected_note.bank)      -- MSB
            textb_2.lbl = tostring(selected_note.velocity)  -- LSB
            textb_3.lbl = tostring(selected_note.note)      -- Note
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
            textb_3.lbl = "N/A"
        end
    end

    -- 检查是否有有效的 bank、velocity 和 program
    if textb_1.lbl == "N/A" or textb_2.lbl == "N/A" or textb_3.lbl == "N/A" then
        return -- 没有有效的 bank、velocity 和 program，直接返回
    end

    local bankNumber = tonumber(textb_1.lbl) * 128 + tonumber(textb_2.lbl)
    local uok, uinput = reaper.GetUserInputs(setpc_title, 2, shift_retvals_csv, tostring(bankNumber) .. ',' .. textb_3.lbl)

    if uok then
        bankNumber, note = uinput:match("([^,]+),([^,]+)")
        bankNumber = tonumber(bankNumber)
        note = tonumber(note)
        msb = math.floor(bankNumber / 128)
        lsb = bankNumber % 128

        -- 查找匹配的 bank_item (根据 MSB)
        local new_bank_index
        for i, bank_item in ipairs(store_grouped) do
            if tonumber(bank_item.bank.bank) == msb then
                new_bank_index = i
                break
            end
        end
    
        -- 查找匹配的 note_item (根据 LSB 和 Note)
        local new_note_index
        if new_bank_index and store_grouped[new_bank_index] and store_grouped[new_bank_index].notes then
            for i, note_item in ipairs(store_grouped[new_bank_index].notes) do
                if tonumber(note_item.note) == note and tonumber(note_item.velocity) == lsb then
                    new_note_index = i
                    break
                end
            end
        end
    
        -- 更新 ch_box1 和 ch_box2
        if new_bank_index and new_note_index then
            ch_box1.norm_val = new_bank_index
            ch_box2.norm_val = new_note_index
    
            -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
            local new_note_item = store_grouped[new_bank_index].notes[new_note_index]
            if new_note_item then
                textb_1.lbl = tostring(new_note_item.bank) -- MSB
                textb_2.lbl = tostring(new_note_item.velocity) -- LSB
                textb_3.lbl = tostring(new_note_item.note) -- Note
            else
                textb_1.lbl = "N/A"
                textb_2.lbl = "N/A"
                textb_3.lbl = "N/A"
            end
    
            update_current_state()
            update_patch_box() -- 更新UI
        end
    end
end

function setBankProgram()
    local function update_current_state()
        current_state = {
            velocity = store[ch_box1.norm_val].bank.velocity,
            note = store[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store[ch_box1.norm_val].bank.bank
        }
        push_current_state()
    end

    local function update_patch_box()
        local bank_index = ch_box1.norm_val
        if not store[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) then
                selected = i
            end
        end
        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles
    
        -- 更新 textb_3 的标签
        if store[bank_index] and store[bank_index].notes[selected] then
            textb_3.lbl = store[bank_index].notes[selected].note
        else
            textb_3.lbl = "N/A" -- 或者其他默认值
        end
    end

    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    local cnt, index = 0, {}
    local val = reaper.MIDI_EnumSelCC(take, -1)
    while val ~= - 1 do
      cnt = cnt + 1
      index[cnt] = val
      val = reaper.MIDI_EnumSelCC(take, val)
    end
  
    if cnt == 0 then
        return
    end
  
    local bank_msb, note_vel, note_pitch = {}, {}, {}
  
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
        if chanmsg == 176 and msg2 == 0 then -- GET BANK NUM
            bank_msb_num = msg3
            bank_msb[#bank_msb+1] = bank_msb_num
        end
        if chanmsg == 176 and msg2 == 32 then -- CC#32
            note_vel_num = msg3
            note_vel[#note_vel+1] = note_vel_num
        end
        if chanmsg == 192 then -- Program Change
            note_pitch_num = msg2
            note_pitch[#note_pitch+1] = note_pitch_num
        end
    end
  
    if bank_msb[1] == nil or note_vel[1] == nil then return reaper.SN_FocusMIDIEditor() end

    msb = tonumber(bank_msb[1])
    lsb = tonumber(note_vel[1])
    note = tonumber(note_pitch[1])

    -- 查找匹配的 bank_item
    local new_bank_index
    for i, bank_item in ipairs(store) do
        if tonumber(bank_item.bank.bank) == msb and tonumber(bank_item.bank.velocity) == lsb then
            new_bank_index = i
            break
        end
    end

    -- 查找匹配的 note_item
    local new_note_index
    if new_bank_index and store[new_bank_index] and store[new_bank_index].notes then
        for i, note_item in ipairs(store[new_bank_index].notes) do
            if tonumber(note_item.note) == note then
                new_note_index = i
                break
            end
        end
    end

    -- 更新 ch_box1 和 ch_box2
    if new_bank_index and new_note_index then
        ch_box1.norm_val = new_bank_index
        ch_box2.norm_val = new_note_index

        -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
        local new_bank_item = store[new_bank_index]
        if new_bank_item and new_bank_item.bank then
            textb_1.lbl = tostring(new_bank_item.bank.bank) -- MSB
            textb_2.lbl = tostring(new_bank_item.bank.velocity) -- LSB
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
        end

        -- 更新 textb_3 的标签
        local new_note_item = store[new_bank_index].notes[new_note_index]
        if new_note_item then
            textb_3.lbl = tostring(new_note_item.note)
        else
            textb_3.lbl = "N/A"
        end

        -- 调用 update_current_state 和其他更新界面的函数
        update_current_state()
        update_patch_box() -- 假设这是更新UI的函数
    end
end

function setBankProgram2()
    local function update_current_state()
        current_state = {
            velocity = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].velocity,
            note = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].note,
            bank = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val].bank
        }
        push_current_state()
    end

    local function update_patch_box() -- 1
        local bank_index = ch_box1.norm_val
        if not store_grouped[bank_index] then bank_index = 1 end
        local selected = 1
        local note_titles = {}
        for i, note_item in ipairs(store_grouped[bank_index].notes) do
            table.insert(note_titles, note_item.full_name)
            if current_state and tonumber(note_item.note) == tonumber(current_state.note) and tonumber(note_item.velocity) == tonumber(current_state.velocity) then
                selected = i
            end
        end

        ch_box2.norm_val = selected
        ch_box2.norm_val2 = note_titles

        local selected_note = store_grouped[bank_index].notes[selected]
        if selected_note then
            textb_1.lbl = tostring(selected_note.bank)      -- MSB
            textb_2.lbl = tostring(selected_note.velocity)  -- LSB
            textb_3.lbl = tostring(selected_note.note)      -- Note
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
            textb_3.lbl = "N/A"
        end
    end

    local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
    if not take or not reaper.TakeIsMIDI(take) then return end
    local cnt, index = 0, {}
    local val = reaper.MIDI_EnumSelCC(take, -1)
    while val ~= - 1 do
      cnt = cnt + 1
      index[cnt] = val
      val = reaper.MIDI_EnumSelCC(take, val)
    end

    if cnt == 0 then
        return
    end
  
    local bank_msb, note_vel, note_pitch = {}, {}, {}
  
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, index[i])
        if chanmsg == 176 and msg2 == 0 then -- GET BANK NUM
            bank_msb_num = msg3
            bank_msb[#bank_msb+1] = bank_msb_num
        end
        if chanmsg == 176 and msg2 == 32 then -- CC#32
            note_vel_num = msg3
            note_vel[#note_vel+1] = note_vel_num
        end
        if chanmsg == 192 then -- Program Change
            note_pitch_num = msg2
            note_pitch[#note_pitch+1] = note_pitch_num
        end
    end
  
    if bank_msb[1] == nil or note_vel[1] == nil then return reaper.SN_FocusMIDIEditor() end

    msb = tonumber(bank_msb[1])
    lsb = tonumber(note_vel[1])
    note = tonumber(note_pitch[1])

    -- 查找匹配的 bank_item (根据 MSB)
    local new_bank_index
    for i, bank_item in ipairs(store_grouped) do
        if tonumber(bank_item.bank.bank) == msb then
            new_bank_index = i
            break
        end
    end

    -- 查找匹配的 note_item (根据 LSB 和 Note)
    local new_note_index
    if new_bank_index and store_grouped[new_bank_index] and store_grouped[new_bank_index].notes then
        for i, note_item in ipairs(store_grouped[new_bank_index].notes) do
            if tonumber(note_item.note) == note and tonumber(note_item.velocity) == lsb then
                new_note_index = i
                break
            end
        end
    end

    -- 更新 ch_box1 和 ch_box2
    if new_bank_index and new_note_index then
        ch_box1.norm_val = new_bank_index
        ch_box2.norm_val = new_note_index

        -- 更新 textb_1 和 textb_2 的标签为新的 MSB 和 LSB
        local new_note_item = store_grouped[new_bank_index].notes[new_note_index]
        if new_note_item then
            textb_1.lbl = tostring(new_note_item.bank) -- MSB
            textb_2.lbl = tostring(new_note_item.velocity) -- LSB
            textb_3.lbl = tostring(new_note_item.note) -- Note
        else
            textb_1.lbl = "N/A"
            textb_2.lbl = "N/A"
            textb_3.lbl = "N/A"
        end

        update_current_state()
        update_patch_box() -- 更新UI
    end
end

function update_reabank_file()
    local track = getActiveMIDITrack()
    if not track then return end

    local nonexistent_path = reaper.GetResourcePath() .. delimiter .. "Data" .. delimiter .. "nonexistent.reabank"
    
    -- 创建一个临时 reabank
    local file = io.open(nonexistent_path, "w+")
    if not file then
        reaper.ShowMessageBox("Couldn't create file:\n" .. nonexistent_path, "Error", 0)
        return
    end

    file:write("Bank 0 1 1\n0 1\n")
    file:close()

    -- 应用临时的reabank
    applyReaBankToTrack(track, nonexistent_path)

    -- 暂停一段时间以确保REAPER处理了切换
    reaper.defer(function() end)

    -- 删除临时的reabank
    os.remove(nonexistent_path)

    -- 重新读取和解析reabank文件
    if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then 
        return 
    end
    store = parse_banks(read_config_lines(reabank_path), vel_show, bnk_show) -- 模式1数据
    store_grouped = group_banks(store, vel_show)                             -- 模式2数据

    -- 应用更新后的reabank
    applyReaBankToTrack(track, reabank_path)

    -- 根据当前模式刷新界面
    if current_mode == "1" then
        switch_mode_1()
    else
        switch_mode_2()
    end

    -- 更新界面上的 bank 名称
    bank_name = getFileName(reabank_path)
    text_bank.lbl = bank_name

    -- 刷新 bank
    refresh_bank()
end

pop_current_state() -- 读取数据
if current_mode == "2" then
    switch_mode_2()
else 
    switch_mode_1()
end

btn1.onClick = function () -- 切换模式1
    state_getter = switch_mode_1()
    current_mode = "1"
    push_current_state()

end

btn4.onClick = function () -- 切换模式2
    state_getter = switch_mode_2()
    current_mode = "2"
    push_current_state()
end

btn8.onRClick = function () -- 右键点击
    reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40950 ) -- Insert bank/program select event...
end

-- text_bank.onClick = function () -- 音色表左键点击
-- end

function DRAW()
    -- 绘制所有按钮
    for key, btn in pairs(Button_TB) do
        btn:draw()
    end

    -- 绘制所有复选框
    for key, ch_box in pairs(CheckBox_TB) do
        ch_box:draw()
    end

    -- 绘制所有文本框
    for key, textb in pairs(Textbox_TB) do
        textb:draw()
    end

    -- 绘制所有外框线
    for key, frame in pairs(Frame_TB) do
        frame:draw()
    end
end

function saveExtState() -- 保存窗口信息
    local d,x,y,w,h=gfx.dock(-1,0,0,0,0)
    reaper.SetProjExtState(0, EXT_SECTION, "pExtState", pickle({
        x = x,y = y, d = d, w = w, h = h
    }))
end

function readExtState() -- 读取窗口信息
    local __, pExtStateStr = reaper.GetProjExtState(0, EXT_SECTION, "pExtState")
    local pExtState
    if pExtStateStr ~= "" then
        pExtState = unpickle(pExtStateStr)
    end 
    return pExtState
end

function Init()
    -- Some gfx Wnd Default Values
    local style = CONFIG.ui.global.style
    local theme_background = CONFIG.ui.global.color[style].theme_background
    local R1, G1, B1 = table.unpack(theme_background)
    local Wnd_bgd = R1 + G1*256 + B1*65536 -- red+green*256+blue*65536

    local Wnd_Dock, Wnd_X, Wnd_Y = 0, 800, 320
    default_Wnd_W, default_Wnd_H = 340, 290 -- 默认窗口尺寸
    Wnd_W, Wnd_H = default_Wnd_W, default_Wnd_H -- 设置当前窗口尺寸为默认尺寸

    -- Init window
    gfx.clear = Wnd_bgd
    local pExtState = readExtState()
    if pExtState then
        gfx.init(WINDOW_TITLE, pExtState.w, pExtState.h, pExtState.d, pExtState.x, pExtState.y)
    else 
        gfx.init(WINDOW_TITLE, Wnd_W, Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y)
    end

    -- Init mouse last
    last_mouse_cap = 0
    last_x, last_y = 0, 0
    mouse_ox, mouse_oy = -1, -1

    if reaper.JS_Window_FindEx then
        hwnd = reaper.JS_Window_Find(WINDOW_TITLE, true)
        if hwnd then reaper.JS_Window_AttachTopmostPin(hwnd) end
    end

    midi_chan = reaper.GetExtState(EXT_SECTION, "MIDIChannel")
    if midi_chan == "" then midi_chan = 1 end
    ch_box3.norm_val = tonumber(midi_chan)
    ch_box3.onClick = function()
        midi_chan = ch_box3.norm_val
        reaper.SetExtState(EXT_SECTION, "MIDIChannel", midi_chan, false)
    end
    midi_chan = tonumber(midi_chan)

    -- 如果启动脚本前刚好有PC被选中，则加载该音色的bank和program
    if current_mode == "2" then
        setBankProgram2()
    else
        setBankProgram()
    end
end

function mainloop()
    if lock_gui then
        -- 使用锁定界面尺寸
        local cur_w, cur_h = gfx.w, gfx.h
        if cur_w ~= default_Wnd_W or cur_h ~= default_Wnd_H then
            local pExtState = readExtState()
            if pExtState then
                gfx.init(nil, default_Wnd_W, default_Wnd_H, pExtState.d, pExtState.x, pExtState.y)
            else
                gfx.init(nil, default_Wnd_W, default_Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y)
            end
        end
    else
        -- 使用缩放级别
        Z_w, Z_h = gfx.w/Wnd_W, gfx.h/Wnd_H
        if Z_w<0.6 then Z_w = 0.6 elseif Z_w>2 then Z_w = 2 end
        if Z_h<0.6 then Z_h = 0.6 elseif Z_h>2 then Z_h = 2 end
    end

    -- mouse and modkeys
    if gfx.mouse_cap&1==1   and last_mouse_cap&1==0  or   -- L mouse
       gfx.mouse_cap&2==2   and last_mouse_cap&2==0  or   -- R mouse
       gfx.mouse_cap&64==64 and last_mouse_cap&64==0 then -- M mouse
       mouse_ox, mouse_oy = gfx.mouse_x, gfx.mouse_y 
    end

    Ctrl  = gfx.mouse_cap&4==4
    Shift = gfx.mouse_cap&8==8
    Alt   = gfx.mouse_cap&16==16 -- Shift state

    DRAW() -- Main()

    -- 读取 gmem_cc_num 的最新值
    gmem_cc_num = reaper.gmem_read(1)
    gmem_cc_num = math.floor(gmem_cc_num)
    if gmem_cc_num == 0 then
        btn11.r = theme_jsfx[1]
        btn11.g = theme_jsfx[2]
        btn11.b = theme_jsfx[3]
        btn11.a = theme_jsfx[4]
        btn11.lbl = not_loaded
    else
        btn11.r = theme_bt[1]
        btn11.g = theme_bt[2]
        btn11.b = theme_bt[3]
        btn11.a = theme_bt[4]
        btn11.lbl = "SC:CC#" .. gmem_cc_num
    end

    gmem_cc58_num = reaper.gmem_read(2)
    gmem_cc58_num = math.floor(gmem_cc58_num)

    last_mouse_cap = gfx.mouse_cap
    last_x, last_y = gfx.mouse_x, gfx.mouse_y
    gfx.mouse_wheel = 0 -- reset gfx.mouse_wheel

    char = gfx.getchar()
    if char == 13 then -- Enter
        if current_mode == "1" then
            local bank_item = store[ch_box1.norm_val]
            local note_item = bank_item.notes[ch_box2.norm_val]
            inset_patch(bank_item.bank.bank, note_item.note, bank_item.bank.velocity, midi_chan)
        elseif current_mode == "2" then
            local note_item = store_grouped[ch_box1.norm_val].notes[ch_box2.norm_val]
            inset_patch(note_item.bank, note_item.note, note_item.velocity, midi_chan)
        end
        gfx.quit()
    end
    
    if char == 26161 then -- F1 打开音色表
        local rea_patch = '\"'..reabank_path..'\"'
        if not OS then local OS = reaper.GetOS() end
        if OS=="OSX32" or OS=="OSX64" then
            edit_reabank = 'open "" '..rea_patch
        else
            edit_reabank = 'start "" '..rea_patch
        end
        os.execute(edit_reabank)
    end

    if char == 26162 then -- F2 编辑配置表
        openUrl(script_path .. "lib" .. delimiter .. "config.lua")
    end

    if char == 26163 then -- F3 向左移动MIDI事件 10 ticks
        slideF10()
    end

    if char == 26164 then -- F4 向右移动MIDI事件 10 ticks
        slideZ10()
    end

    if char == 26165 then -- F5 刷新音色表
        update_reabank_file()
        reaper.MB(update_rbf_msg, update_rbf_ttl, 0)
    end

    if char == 26166 then -- F6 音符-PC模式切换
        toggleNoteToPC()
    end

    if char == 26167 then -- F7 设置PC事件
        set_group_velocity()
    end

    if char == 26168 then -- F8 切换音色表显示模式
        local function switch_mode_A()
            -- 实现模式1的功能
            state_getter = switch_mode_1()
            current_mode = "1"
            push_current_state()
        end
        
        local function switch_mode_B()
            -- 实现模式2的功能
            state_getter = switch_mode_2()
            current_mode = "2"
            push_current_state()
        end
        
        local function toggle_mode()
            if current_mode == "1" then
                switch_mode_B()
                current_mode = "2"
            else
                switch_mode_A()
                current_mode = "1"
            end
        end
        toggle_mode()
    end

    if char == 26169 then -- F9 
        add_or_toggle_articulation_map_jsfx()
    end

    if char == 6697264 then -- F10
        local track = getActiveMIDITrack()
        local retval, reaini_path = reaper.GetUserFileNameForRead("", selbank_path, ".reabank")
        if retval then
            set_reabank_file(reaini_path) -- 将reabank路径写到reaper.ini
            reabank_path = reaini_path
    
            if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
            store = parse_banks(read_config_lines(reabank_path), vel_show, bnk_show) -- 模式1数据
            store_grouped = group_banks(store, vel_show)                             -- 模式2数据
        
            state_getter = switch_mode_1()
            current_mode = "1"
            push_current_state()
    
            applyReaBankToTrack(track, reabank_path)
            text_bank.lbl = getFileName(reabank_path)
        end
    end

    if char == 6697265 then -- F11 恢复界面原始尺寸
        local cur_w, cur_h = gfx.w, gfx.h
        if cur_w ~= default_Wnd_W or cur_h ~= default_Wnd_H then
            local pExtState = readExtState()
            if pExtState then
                gfx.init(nil, default_Wnd_W, default_Wnd_H, pExtState.d, pExtState.x, pExtState.y)
            else
                gfx.init(nil, default_Wnd_W, default_Wnd_H, Wnd_Dock, Wnd_X, Wnd_Y)
            end
        end
    end

    if char == 6697266 then -- F12 打开simul-arts.txt
        local txt_path = reaper.GetResourcePath() .. delimiter .. "Data" .. delimiter .. "zaibuyidao_articulation_map" .. delimiter .. "simul-arts.txt"
        openUrl(txt_path)
    end

    text_bank.onRClick = function () -- 刷新音色表
        -- 检查模式1和模式2是否有有效的银行数据
        local isBankLoaded = (store and store[1] and store[1].bank and store[1].bank.full_name ~= no_bank_sel) or
        (store_grouped and store_grouped[1] and store_grouped[1].bank and store_grouped[1].bank.full_name ~= no_bank_sel)
    
        -- 如果没有加载任何银行数据，则直接返回
        if not isBankLoaded then
            -- reaper.MB("没有加载任何音色库文件，无法更新。", "提示", 0)
            return
        end

        if Shift then
            reaper.MIDIEditor_OnCommand( reaper.MIDIEditor_GetActive(), 40950 ) -- Insert bank/program select event...
        else
            update_reabank_file()
            reaper.MB(update_rbf_msg, update_rbf_ttl, 0)
        end
    end

    btn8.onClick = function () -- 选择音色表
        if Shift then
            local track = getActiveMIDITrack()
            local retval, reaini_path = reaper.GetUserFileNameForRead("", selbank_path, ".reabank")
            if retval then
                set_reabank_file(reaini_path) -- 将reabank路径写到reaper.ini
                reabank_path = reaini_path
    
                if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
                store = parse_banks(read_config_lines(reabank_path), vel_show, bnk_show) -- 模式1数据
                store_grouped = group_banks(store, vel_show)                             -- 模式2数据
            
                state_getter = switch_mode_1()
                current_mode = "1"
                push_current_state()
    
                applyReaBankToTrack(track, reabank_path)
                text_bank.lbl = getFileName(reabank_path)
            end
        else
            local track = getActiveMIDITrack()
            reabank_path, bank_name = reSelectReaBankFile()
            if not reabank_path then return end
        
            if read_config_lines(reabank_path) == 1 or read_config_lines(reabank_path) == 0 then return end
            store = parse_banks(read_config_lines(reabank_path), vel_show, bnk_show) -- 模式1数据
            store_grouped = group_banks(store, vel_show)                             -- 模式2数据
        
            state_getter = switch_mode_1()
            current_mode = "1"
            push_current_state()
        
            applyReaBankToTrack(track, reabank_path)
            text_bank.lbl = bank_name -- 更新文本框 textb 的标签的音色表名称
        end
        refresh_bank()
    end

    btn5.onClick = function ()
        if Shift then
            move_evnet_to_left(1)
        else
            move_evnet_to_left(10)
        end
    end -- 按钮 -x Tick

    btn6.onClick = function ()
        if Shift then
            move_evnet_to_right(1)
        else
            move_evnet_to_right(10)
        end
    end -- 按钮 +x Tick

    btn9.onClick = function () -- 编辑音色表, 按住Shift编辑键位映射表
        if Shift then
            local txt_path = reaper.GetResourcePath() .. delimiter .. "Data" .. delimiter .. "zaibuyidao_articulation_map" .. delimiter .. "simul-arts.txt"
            openUrl(txt_path)
        else
            local rea_patch = '\"'..reabank_path..'\"'
            edit_reabank = 'start "" '..rea_patch
            os.execute(edit_reabank)
        end
    end

    btn10.onClick = function ()
        if Shift then
            togglePCToCC() -- 切换PC转CC
        else
            set_group_velocity() -- 设置乐器组参数
        end
    end

    btn11.onClick = function ()
        if Shift then
            toggle_pre_trigger_jsfx() -- 切换浮动预触发事件插件
        else
            add_or_toggle_articulation_map_jsfx() -- 添加表情映射插件
        end
    end

    textb_1.onRClick = function () -- MSB
        if Shift then
            if current_mode == "2" then
                setCheckBoxMode2Shift()
            else
                setCheckBoxMode1Shift()
            end
        else
            if current_mode == "2" then
                setCheckBoxMode2()
            else
                setCheckBoxMode1()
            end
        end
    end
    
    textb_2.onRClick = function () -- LSB
        if Shift then
            if current_mode == "2" then
                setCheckBoxMode2Shift()
            else
                setCheckBoxMode1Shift()
            end
        else
            if current_mode == "2" then
                setCheckBoxMode2()
            else
                setCheckBoxMode1()
            end
        end
    end
    
    textb_3.onRClick = function () -- Program
        if Shift then
            if current_mode == "2" then
                setCheckBoxMode2Shift()
            else
                setCheckBoxMode1Shift()
            end
        else
            if current_mode == "2" then
                setCheckBoxMode2()
            else
                setCheckBoxMode1()
            end
        end
    end
    
    if char == -1 or char == 27 then saveExtState() end -- saveState (window position)
    if char ~= -1 then reaper.defer(mainloop) end -- defer
    gfx.update()
end

Init()
mainloop()