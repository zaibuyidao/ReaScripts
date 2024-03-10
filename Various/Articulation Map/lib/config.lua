-- NoIndex: true
return {
    ui = {
        global = {
            -- Script Name ⇌ 脚本名称 
            title = {
                cn = "技法映射 (Script by 再補一刀)",
                tw = "技法映射 (Script by 再補一刀)",
                en = "Articulation Map (Script by zaibuyidao)"
            },
            -- Change Font ⇌ 更改字体
            font = {
                cn = "SimSun", -- 可选项: "Microsoft YaHei", "SimSun", "华文宋体", "华文仿宋", "微软雅黑"
                tw = "PMingLiU", -- 可選項: "PMingLiU", "Microsoft JhengHei", "DFKai-SB", "Apple LiGothic Medium", "LiHei Pro"
                en = "Arial" -- Option: "Arial", "Verdana", "Helvetica", "Times New Roman", "Calibri", "Roboto"
            },
            -- Change Font Size ⇌ 更改字体大小
            font_size = {
                cn = 12,
                tw = 12,
                en = 14
            },
            lock_gui = false, -- Lock GUI Interface ⇌ 是否锁定GUI界面
            vel_show = true, -- Whether or not to include Velocity information in Patch ⇌ 是否在音色名称中包含Velocity信息
            bnk_show = true, -- Whether or not to display Bank number information in Patch ⇌ 是否在音色名称中显示Bank number信息
            theme_toggle = true, -- 切换主題按钮样式
            -- Change Color Configuration ⇌ 更改颜色配置
            color = {
                theme_background = {240, 240, 240}, -- Background Color ⇌ 背景颜色
                theme_font = {0/255, 0/255, 0/255, 1}, -- Text Color ⇌ 文本颜色
                theme_bt = {210/255, 210/255, 210/255, 1}, -- Button Color ⇌ 按钮颜色
                theme_txt = {255/255, 255/255, 255/255, 1}, -- Textbox/Checkbox Color ⇌ 文本框/复选框颜色
                theme_brd = {0/255, 120/255, 212/255, 1}, -- Border Color ⇌ 边框颜色
                theme_jsfx = {169/255, 169/255, 169/255, 1}, -- Default Color when JSFX is Not Loaded ⇌ JSFX未加载的默认颜色
                theme_frame = {240/255, 240/255, 240/255, 0.1}, -- Outer Frame Color ⇌ 外框颜色
            },
        }
    }
}