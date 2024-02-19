-- NoIndex: true
return {
    ui = {
        global = {
            font = "SimSun", -- Font Setting ⇌ 字体设置: "Calibri", "SimSun", "华文宋体", "华文仿宋", "微软雅黑"
            size_unit = 14, -- Control Unit Size ⇌ 控件单位大小, 所有控件大小以此为基准
        },
        window = {
            title = "SFX Tag Search", -- Title (标题)
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
            show_keyword_origin = false, -- Whether to display keyword column content, such as File, Custom Tags, Description, Keywords ⇌ 是否显示关键词栏目内容, 如File, Custom Tags, Description, Keywords
            -- Set a color for each database ⇌ 为每一个数据库设置颜色
            db_color = {
                ["DB: 00"] = {36/255, 43/255, 43/255, 1}
            },
            -- If no color is set for the database, one of the following colors is automatically selected ⇌ 如果没有为数据库设置颜色, 则自动选择下面的颜色之一
            default_colors = {
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1}
            },
            -- The number of records to be scrolled when the page is turned. If there is no configuration, the number of records in one page of the current list will be used by default.
            -- 翻页时滚动的记录条数, 不存在配置时则默认使用当前列表一页的条数
            -- page_up_down_size = 50,
            
            color_highlight = {0/255, 120/255, 212/255, 0.3}, -- Keyword Highlight Color ⇌ 关键词高亮颜色
            color_focus_border = {105/255, 105/255, 105/255, 1} -- Border color when selected ⇌ 选中时边框颜色
        }
    },
    db = {
        exclude_db = {}, -- Exclude loaded databases, example exclude = { "DB: 00", "DB: 01" } ⇌ 排除加载的数据库, 示例 exclude = { "DB: 00", "DB: 01" }
        exclude_keyword_origin = { "File", "Description", "Keywords" }, -- Keyword column content to be excluded, example exclude = { "File", "Custom Tags", "Description", "Keywords" } ⇌ 需要排除的关键词栏目内容，示例 exclude = { "File", "Custom Tags", "Description", "Keywords" }
        delimiters = {
            ["Custom Tags"] = {}, -- List of separators for Custom Tags ⇌ Custom Tags 的分隔符列表
            ["Description"] = {}, -- List of separators for Description ⇌ Description 的分隔符列表
            ["Keywords"] = {}, -- List of separators for Keywords ⇌  Keywords 的分隔符列表
            ["File"] = {}, -- List of separators for File ⇌ File 的分隔符列表
            default = {}, -- When no separator is found above, this list of separators is used by default ⇌ 当上面找不到分隔符时, 默认使用该分隔符列表
        }
    },
    rating = {
        max_record = 20 -- Keyword Ranking Save Limit ⇌ 关键词排行保存条数限制
    },
    search = {
        async = false, -- Whether to enable asynchronous search (not recommended) ⇌ 是否开启异步搜索(不建议开启)
        sort_result = true, -- Whether to sort the list ⇌ 是否对列表进行排序
        cn_first = false, -- Whether to prioritize Chinese when sorting, available parameters: true, false, nil ⇌ 排序时是否中文优先, 可填参数: true, false, nil
        switch_database = true, -- When clicking on a keyword, does it switch databases at the same time? ⇌ 点击关键词时, 是否同时切换数据库
        case_sensitive = false, -- Case-sensitive searching ⇌ 搜索时是否区分大小写
        file = {
            contains_all_parent_directories = false -- Whether to keyword the parent folder name ⇌ 是否将上级文件夹名称加入关键词
        }
    }
}