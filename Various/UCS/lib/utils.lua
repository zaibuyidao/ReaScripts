-- NoIndex: true
local function print_r(t)
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

table.print = print_r

csv = {}
function csv.read(filename)
    local result = {}
    local file = io.open(filename,"r")
    for line in file:lines() do
        local last = 1
        local str_mode = false
        local cur = {}
        for i = 1, #line do
            local c = line:sub(i, i)
            if str_mode then
                if c == "\"" then
                    str_mode = false
                end
                goto continue
            end
            if c == "\"" then
                str_mode = true
                goto continue
            end
            if c == "," then
                table.insert(cur, line:sub(last, i - 1))
                last = i + 1
            end
            ::continue::
        end
        table.insert(cur, line:sub(last))
        table.insert(result, cur)
    end
    file:close()
    return result
end

function string.trim(s)
    return s:gsub("^%s*\"%s*", ""):gsub("%s*\"%s*$", ""):gsub("%s*$", ""):gsub("^%s*", "")
end

function string.split(str, ...)
    local resultStrList = {}
    string.gsub(str,'[^'..table.concat({...})..']+',function (w)
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

function table.map(tab, f)
    local result = {}
    for k, v in pairs(tab) do
        result[k] = f(v)
    end
    return result
end

function table.filter(tab, f)
    local result = {}
    for _, v in ipairs(tab) do
        if f(v) then
            table.insert(result, v)
        end
    end
    return result
end