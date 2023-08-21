-- NoIndex: true
return {
    ui = {
        global = {
            font = "SimSun", -- 字体名："Calibri"、"宋体"、"华文宋体"、"华文仿宋"、"微软雅黑"
            size_unit = 14, -- 控件单位大小, 所有控件大小以此为基准
        },
        window = {
            title = "SFX Tag Search UCS", -- 窗口标题
            background_color = { r = 220, g = 222, b = 222 }, -- 窗口背景颜色
            width = 250, -- 初次启动时的窗口宽度
            height = 500, -- 初次启动时的窗口高度
            x = 50, -- 初次启动时的窗口位置横坐标
            y = 50 -- 初次启动时的窗口位置纵坐标
        },
        search_box = {
            state_label = { -- 右上角状态标签配置
                colors_label = { -- 右上角状态标签颜色
                    normal = {36/255, 43/255, 43/255, 0.7},
                    hover = {6/255, 43/255, 43/255, 1},
                   focus = {6/255, 43/255, 43/255, 0.5},
                    active = {6/255, 43/255, 43/255, 0.5}
                },
                border = false -- 右上角状态标签是否显示边框
            },
            colors_label = { -- 过滤框配置
                normal = {30/255, 34/255, 34/255, 1}, -- 文字颜色
                hover = {0/255, 120/255, 212/255, 1}, -- 边框颜色, 鼠标经过
                focus = {111/255, 111/255, 111/255, 1}, -- 边框颜色, 无操作
                active = {0/255, 120/255, 212/255, 0.5} -- 边框颜色, 点击时
            },
            border_focus = false, -- 聚焦时是否显示边框
            color_focus_border = {105/255, 105/255, 105/255, 1}, -- 聚焦时边框的颜色
            carret_color = {0, 0, 0, 1}, -- 光标颜色
        },
        result_list = {
            include_key = true, -- 是否在列表中显示第二列, 否则只显示第一列
            remark_color = { -- 为第三列分组设置一个颜色
                ["我最喜欢"] = {36/255, 43/255, 43/255, 1}
            },
            default_colors = { -- 如果没有为分组设置颜色, 则自动选择下面的颜色之一
            {36/255, 43/255, 43/255, 1},
            {36/255, 43/255, 43/255, 1},
            {36/255, 43/255, 43/255, 1}
            },
            color_highlight = {0/255, 120/255, 212/255, 0.3}, -- 关键词高亮颜色
            color_focus_border = {105/255, 105/255, 105/255, 1},  -- 选中项边框的颜色
        }
    },
    search = {
        case_sensitive = false, -- 搜索时是否区分大小写
        include_name = true, -- 搜索是否包含第二列
        include_remark = true -- 搜索是否包含第三列
    },
    ucs = {
        write_catid = true, -- 是否写入 CatID
        write_category = true, -- 是否写入 Category
        write_sub_category = true, -- 是否写入 SubCategory
        write_category_full = false, -- 是否写入 CategoryFull
        write_category_ch = false, -- 是否写入中文标签 Category_ch
        write_sub_category_ch = false, -- 是否写入中文标签 SubCategory_ch
        write_category_full_ch = true, -- 是否写入中文标签 CategoryFull_ch
        -- 对于用户创建列的编号的动作命令(请注意 REAPER只支持10个用户创建列):
        -- 从上往下排序 1 = 42194, 2 = 42195, 3 = 42196, 4 = 42197, 5 = 42198, 6 = 42199, 7 = 42200, 8 = 42201, 9 = 42202, 10 = 42203
        cmd_id_catid = getCmdID(1), -- CatID 对于用户创建列的编号
        cmd_id_category = getCmdID(2), -- Category 对于用户创建列的编号
        cmd_id_sub_category = getCmdID(3), -- SubCategory 对于用户创建列的编号
        cmd_id_category_full = getCmdID(4), -- CategoryFull 对于用户创建列的编号
        cmd_id_category_ch = getCmdID(5), -- Category_ch 对于用户创建列的编号
        cmd_id_sub_category_ch = getCmdID(6), -- SubCategory_ch 对于用户创建列的编号
        cmd_id_category_full_ch = getCmdID(7), -- CategoryFull_ch 对于用户创建列的编号
        tag_write_delay = 0.1 -- 单位: 秒. 每个标签之间的处理时间间隔. 如果无法顺利写入标签, 则需要将延迟时间调大.
    }
}