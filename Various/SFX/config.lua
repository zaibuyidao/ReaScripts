-- NoIndex: true
return {
    ui = {
        global = {
            font = "微软雅黑", -- 默认字体名
            size_unit = 22, -- 控件单位大小，所有控件大小以此为基准
        },
        window = {
            title = "音效標簽搜索", -- 窗口标题
            background_color = { r = 10, g = 10, b = 10 },  -- 窗口背景颜色
        },
        search_box = {
            colors_label = {
                normal = {.8, .8, .8, .8},
                hover = {.8, .8, .8, 1},
                focus = {.5, .5, .5, 1},
                active = {1, .9, 0, .5}
            },
            color_focus_border = {1, .9, 0, .5}
        },
        result_list = {
            show_keyword_origin = false, -- 是否显示关键词的栏目信息，如File、Custom Tags、Description、Keywords
            db_color = { -- 为每一个数据库设置一个颜色
                ["DB: 00"] = {0.5, 0.7, 0.7, 1}
            },
            default_colors = { -- 如果没有为数据库设置颜色，则自动选择下面的颜色之一
                {.6, .6, .6, 1},
                {0.8, 0.8, 0.5, 1},
                {0.5, 0.5, 0.8, 1},
                {0.5, 0.7, 0.5, 1},
                {0.7, 0.5, 0.5, 1},
                {0.5, 0.5, 0.7, 1},
                {0.5, 0.7, 0.7, 1},
                {0.8, 0.5, 0.5, 1}
            },
            -- 翻页时，滚动的记录条数，不存在配置时则默认使用当前列表一页的条数
            -- page_up_down_size = 50
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
        switch_database = true, -- 点击关键词时，是否同时切换数据库
        case_sensitive = false -- 搜索时是否区分大小写
    }
}