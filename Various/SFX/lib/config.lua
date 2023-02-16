-- NoIndex: true
return {
    ui = {
        global = {
            font = "微软雅黑", -- 默认字体名
            size_unit = 22, -- 控件单位大小，所有控件大小以此为基准
        },
        window = {
            title = "SFX Tag Search", -- 窗口标题
            background_color = { r = 220, g = 222, b = 222 }, -- 窗口背景颜色
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
                normal = {30/255, 34/255, 34/255, 1}, -- 过滤框文字颜色
                hover = {0/255, 120/255, 212/255, 1}, -- 过滤框颜色，鼠标经过
                focus = {188/255, 188/255, 188/255, 1}, -- 过滤框颜色，无操作
                active = {0/255, 120/255, 212/255, 0.5} -- 过滤框颜色，点击时
            },
            border_focus = true, -- 聚焦时是否显示边框
            color_focus_border = {105/255, 105/255, 105/255, 1}, -- 聚焦时边框的颜色
            carret_color = {0, 0, 0, 1}, -- 光标颜色
        },
        result_list = {
            show_keyword_origin = false, -- 是否显示关键词的栏目信息，如File、Custom Tags、Description、Keywords
            db_color = { -- 为每一个数据库设置一个颜色
                ["DB: 00"] = {36/255, 43/255, 43/255, 1}
            },
            default_colors = { -- 如果没有为数据库设置颜色，则自动选择下面的颜色之一
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1},
                {36/255, 43/255, 43/255, 1}
            },
            -- 翻页时，滚动的记录条数，不存在配置时则默认使用当前列表一页的条数
            -- page_up_down_size = 50,
            
            color_highlight = {105/255, 105/255, 105/255, 0.1}, -- 关键词高亮颜色
            color_focus_border = {105/255, 105/255, 105/255, 1} -- 聚焦时边框的颜色（列表项）
        }
    },
    db = {
        exclude_db = {}, -- 排除加载的数据库，示例 exclude = { "DB: 00", "DB: 01" }
        exclude_keyword_origin = { "File", "Description", "Keywords" }, -- 需要排除的关键词栏目信息，示例 exclude = { "File", "Custom Tags", "Description", "Keywords" }
        delimiters = {
            ["Custom Tags"] = { ",", ";" }, -- Custom Tags 的分隔符列表
            ["Description"] = {}, -- Description 的分隔符列表
            ["Keywords"] = {}, -- Keywords 的分隔符列表
            ["File"] = {}, -- File 的分隔符列表
            default = {}, -- 当上面找不到分隔符时，默认使用该分隔符列表
        }
    },
    rating = {
        max_record = 50 -- 关键词排行保存条数限制
    },
    search = {
        async = false, -- 是否开启异步搜索
        switch_database = true, -- 点击关键词时，是否同时切换数据库
        case_sensitive = false, -- 搜索时是否区分大小写
        file = {
            contains_all_parent_directories = false -- 是否将上级文件夹名称加入关键词
        }
    }
}