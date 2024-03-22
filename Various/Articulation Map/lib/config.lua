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
            style = "imgui", -- GUI Interface style settings, options: 'default', 'imgui', 'lokasenna'" ⇌ 界面风格设置, 可选项: "default", "imgui", "lokasenna"
            lock_gui = false, -- Lock GUI Interface ⇌ 是否锁定GUI界面
            vel_show = true, -- Whether or not to include Velocity information in Patch ⇌ 是否在音色名称中包含Velocity信息
            bnk_show = false, -- Whether or not to display Bank number information in Patch ⇌ 是否在音色名称中显示Bank number信息
            theme_toggle = true, -- Use rounded button style ⇌ 是否使用圆弧形的按钮样式
            -- Interface style color configuration ⇌ 界面风格颜色配置
            color = {
                default = {
                    theme_background = {240, 240, 240}, -- Background Color ⇌ 背景颜色
                    theme_font = {0/255, 0/255, 0/255, 1}, -- Text Color ⇌ 文本颜色
                    theme_bt = {210/255, 210/255, 210/255, 1}, -- Button Color ⇌ 按钮颜色
                    theme_txt = {255/255, 255/255, 255/255, 1}, -- Textbox/Checkbox Color ⇌ 文本框/复选框颜色
                    theme_brd = {0/255, 120/255, 212/255, 1}, -- Border Color ⇌ 边框颜色
                    theme_jsfx = {169/255, 169/255, 169/255, 1}, -- Default Color when JSFX is Not Loaded ⇌ JSFX未加载的默认颜色
                    theme_frame = {240/255, 240/255, 240/255, 0.1}, -- Outer Frame Color ⇌ 外框颜色
                },
                imgui = {
                    theme_background = {14, 15, 22}, -- Background Color ⇌ 背景颜色
                    theme_font = {255/255, 255/255, 255/255, 1}, -- Text Color ⇌ 文本颜色
                    theme_bt = {30/255, 57/255, 92/255, 1}, -- Button Color ⇌ 按钮颜色
                    theme_txt = {35/255, 69/255, 112/255, 1}, -- Textbox/Checkbox Color ⇌ 文本框/复选框颜色
                    theme_brd = {66/255, 150/255, 250/255, 1}, -- Border Color ⇌ 边框颜色
                    theme_jsfx = {79/255, 79/255, 79/255, 1}, -- Default Color when JSFX is Not Loaded ⇌ JSFX未加载的默认颜色
                    theme_frame = {62/255, 62/255, 74/255, 0.1}, -- Outer Frame Color ⇌ 外框颜色
                },
                lokasenna = {
                    theme_background = {64, 64, 64}, -- Background Color ⇌ 背景颜色
                    theme_font = {192/255, 192/255, 192/255, 1}, -- Text Color ⇌ 文本颜色
                    theme_bt = {96/255, 96/255, 96/255, 1}, -- Button Color ⇌ 按钮颜色
                    theme_txt = {48/255, 48/255, 48/255, 1}, -- Textbox/Checkbox Color ⇌ 文本框/复选框颜色
                    theme_brd = {64/255, 192/255, 64/255, 1}, -- Border Color ⇌ 边框颜色
                    theme_jsfx = {88/255, 144/255, 88/255, 1}, -- Default Color when JSFX is Not Loaded ⇌ JSFX未加载的默认颜色
                    theme_frame = {64/255, 64/255, 64/255, 0.1}, -- Outer Frame Color ⇌ 外框颜色
                },
            },
        }
    },
    pc_to_note = {
        short_note = 60, -- Non-holding note length (tick) ⇌ 非保持音长度
        sustain_note = 240, -- Holding note length (tick) ⇌ 保持音长度
    }
}