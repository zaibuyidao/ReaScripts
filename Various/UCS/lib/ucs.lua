-- NoIndex: true
--[[
{
    {
        name = { en = "AIR", zh = "气体" },
        children = {
            {
                name = { en = "BLOW", zh = "吹" },
                cat_id = "AIRBlow",
                synonyms = {
                    en = {"compressed air", "depressurise", "release", "puff", "sputter", "flutter"},
                    zh = {"压缩空气","减压","释放","吹气","溅射","颤动"}
                }
            }
        }
    }
}
]]

LocaleData = {__meta = {__index = {}}}
setmetatable(LocaleData, {
    __call = function (cls, tab)
        tab = tab or {}
        setmetatable(tab, LocaleData.__meta)
        return tab
    end
})
function LocaleData.__meta.__index:get(locale)
    if locale == nil then
        for _, v in pairs(self) do
            return v
        end
    end
    if self[locale] then
        return self[locale]
    end
    for _, v in pairs(self) do
        return v
    end
end

usc = {}

function usc.read_from_csv(filename, result)
    result = result or {}

    local data = csv.read(filename)
    if #data < 2 then return end

    local category_map = {}
    local function get_category_index(name)
        if category_map[name] then return category_map[name] end
        table.insert(result, {
            name = LocaleData { en = name },
            children = {}
        })
        category_map[name] = #result
        return category_map[name]
    end
    local column_names = data[1]
    for i = 2, #data do
        local index = get_category_index(data[i][1])
        result[index].name.zh = data[i][6]
        result[index].name.tw = data[i][9]
        result[index].name.ja = data[i][12]
        result[index].name.cat_short = data[i][4]
        result[index].name.cat_egory = data[i][1]
        table.insert(result[index].children, {
            name = LocaleData {
                en = data[i][2],
                zh = data[i][7],
                tw = data[i][10],
                ja = data[i][13],
            },
            cat_id = data[i][3],
            synonyms = LocaleData {
                en = table.map(string.split(data[i][5], ","), string.trim),
                zh = table.map(string.split(data[i][8], ","), string.trim),
                tw = table.map(string.split(data[i][11], ","), string.trim),
                ja = table.map(string.split(data[i][14], ","), string.trim)
            }
        })
    end
    return result
end