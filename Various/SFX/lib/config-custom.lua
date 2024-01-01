-- NoIndex: true
return {
    ui = {
        global = {
            font = "SimSun", -- Font Setting ⇌ 字体设置: "Calibri", "SimSun", "华文宋体", "华文仿宋", "微软雅黑"
            size_unit = 14, -- Control Unit Size ⇌ 控件单位大小, 所有控件大小以此为基准
        },
        window = {
            title = "SFX Tag Search (Custom)", -- Title (标题)
            background_color = { r = 220, g = 222, b = 222 }, -- Background color ⇌ 背景颜色
            width = 250, -- Initial width ⇌ 初始宽度
            height = 500, -- Initial height ⇌ 初始高度
            x = 50, -- Initial horizontal coordinates ⇌ 初始横坐标
            y = 50 -- Initial vertical coordinate ⇌ 初始纵坐标
        },
        search_box = {
            -- Status Label Configuration ⇌ 右上角状态标签配置
            state_label = {
                -- Status label color ⇌ 状态标签颜色
                colors_label = {
                    normal = {36/255, 43/255, 43/255, 0.7},
                    hover = {6/255, 43/255, 43/255, 1},
                    focus = {6/255, 43/255, 43/255, 0.5},
                    active = {6/255, 43/255, 43/255, 0.5}
                },
                border = false -- Whether the status label displays a border ⇌ 状态标签是否显示边框
            },
            -- Filter Frame Configuration (过滤框配置)
            colors_label = {
                normal = {30/255, 34/255, 34/255, 1}, -- Text color ⇌ 文字颜色
                hover = {0/255, 120/255, 212/255, 1}, -- Border color on mouse over ⇌ 鼠标经过时边框颜色
                focus = {111/255, 111/255, 111/255, 1}, -- Border color when no operation ⇌ 无操作时边框颜色
                active = {0/255, 120/255, 212/255, 0.5} -- Border color when clicking ⇌ 点击时边框颜色
            },
            border_focus = false, -- Whether to display the border when focusing ⇌ 聚焦时是否显示边框
            color_focus_border = {105/255, 105/255, 105/255, 1}, -- Border color when focusing ⇌ 聚焦时边框颜色
            carret_color = {0, 0, 0, 1}, -- Cursor color ⇌ 光标颜色
        },
        result_list = {
            include_key = true, -- Whether to display the second column in the list, otherwise only the first column is displayed ⇌ 是否在列表中显示第二列, 否则只显示第一列
            -- Set a color for the third column grouping ⇌ 为第三列分组设置一个颜色
            remark_color = {
                ["My Favorite"] = {36/255, 43/255, 43/255, 1}
            },
            -- If no color is set for the grouping, one of the following colors is automatically selected ⇌ 如果没有为分组设置颜色，则自动选择下面的颜色之一
            default_colors = {
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1}
            },
            color_highlight = {0/255, 120/255, 212/255, 0.3}, -- Keyword Highlight Color ⇌ 关键词高亮颜色
            color_focus_border = {105/255, 105/255, 105/255, 1},  -- Border color when focusing ⇌ 聚焦时边框颜色
        }
    },
    search = {
        sort_result = true, -- Whether to sort the list ⇌ 是否对列表进行排序
        cn_first = false, -- Whether to prioritize Chinese when sorting, available parameters: true, false, nil ⇌ 排序时是否中文优先, 可填参数: true, false, nil
        case_sensitive = false, -- Case-sensitive searching ⇌ 搜索时是否区分大小写
        include_name = true, -- Whether the second column is included in the search ⇌ 搜索时是否包含第二列
        include_remark = true -- Whether the third column is included in the search ⇌ 搜索时是否包含第三列
    }
}