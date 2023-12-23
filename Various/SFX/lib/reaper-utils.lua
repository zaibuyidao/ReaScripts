-- NoIndex: true
function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
end

function table.print(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
end

function getCmdID(offset)
    local base_cmd_id = 42193
    return base_cmd_id + offset
end

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end
    reaper.JS_Window_SetTitle(search, text)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    -- reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
    -- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE key
end

function string.split(szFullString, szSeparator)  
    local nFindStartIndex = 1  
    local nSplitIndex = 1  
    local nSplitArray = {}  
    while true do  
       local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
       if not nFindLastIndex then  
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
        break  
       end  
       nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
       nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
       nSplitIndex = nSplitIndex + 1  
    end  
    return nSplitArray  
end

function prompt(attr)
    local labels = {}
    local defaults = {}
    local converters = {}
    local defaultConverter = function (...) return ... end
    local remember = attr.remember or {}

    for _, input in ipairs(attr.inputs or {}) do
        if not input.default then 
            table.insert(defaults, "")
        else
            table.insert(defaults, tostring(input.default))
        end
        table.insert(labels, input.label or "")
        table.insert(converters, input.converter or defaultConverter)
    end

    local defaultCsv = table.concat(defaults, ",")
    if remember.enable then
        if  reaper.HasExtState(remember.section, remember.key) then
            defaultCsv = reaper.GetExtState(remember.section, remember.key)
        end
    end

    local ok, resCsv = reaper.GetUserInputs(attr.title or "", #labels, table.concat(labels, ","), defaultCsv)
    if not ok then return nil end

    local res = string.split(resCsv, ",")
    for i=1, #res do
        res[i] = converters[i](res[i])
    end

    if remember.enable and (not remember.preValidation or remember.preValidation(res)) then
        reaper.SetExtState(remember.section, remember.key, resCsv, remember.persist)
    end

    return res
end

function getPathDelimiter()
    local os = reaper.GetOS()
    if os ~= "Win32" and os ~= "Win64" then
        return "/"
    else
        return "\\"
    end
end

function openUrl(url)
    local osName = reaper.GetOS()
    if osName:match("^OSX") then
        os.execute('open "" "' .. url .. '"')
    else
        -- chcp 65001
        os.execute('start "" "' .. url .. '"')
    end
end

function countReaperFileList(reaper_explorer)
    local count = {}
    for k, v in pairs(reaper_explorer) do
        if k:match("^Shortcut%d+$") and v:find("^%d+%.ReaperFileList$") then
            count[v] = (count[v] or 0) + 1
        end
    end
    return count
end

function getDbList()
    local reaperConfig = LIP.load(reaper.GetResourcePath() .. PATH_DELIMITER .. "reaper.ini")
    local reaper_explorer = reaperConfig.reaper_explorer
    if reaper_explorer == nil then 
        print("reaper_explorer is nil")
        return false 
    end

    local res = {}

    for i = 0, tonumber(reaper_explorer.NbShortcuts) - 1 do
        local shortcutKey = string.format("Shortcut%d", i)
        local shortcutTKey = string.format("ShortcutT%d", i)
        local shortcutValue = reaper_explorer[shortcutKey]
        local shortcutTValue = reaper_explorer[shortcutTKey]

        -- 排除特定的项
        if (shortcutValue == "<Track Templates>" or shortcutValue == "<Project Directory>") then
            goto continue
        end

        if shortcutValue and shortcutTValue then
            if shortcutValue:find("^.+%.ReaperFileList$") or shortcutValue:find("^<.+>$") then
                res[shortcutValue] = {
                    path = reaper.GetResourcePath() .. PATH_DELIMITER .. "MediaDB" .. PATH_DELIMITER .. shortcutValue,
                    name = shortcutTValue,
                    i = i
                }
            end
        end

        ::continue::
    end

    -- 对结果进行排序
    local sortedRes = {}
    for _, v in pairs(res) do
        table.insert(sortedRes, v)
    end
    table.sort(sortedRes, function(a, b)
        return a.i < b.i
    end)
    
    return sortedRes
end

local GLOBAL_STATE_SECTION

function setGlobalStateSection(section)
    GLOBAL_STATE_SECTION = section
end

function getState(key, default, convert)
	local value = reaper.GetExtState(GLOBAL_STATE_SECTION, key)
    if not value or value == "" then return default end
    if convert then return convert(value) end
    return value
end

function setState(tab)
    for k, v in pairs(tab) do
        reaper.SetExtState(GLOBAL_STATE_SECTION, k, v, true)
    end
end

PATH_DELIMITER = getPathDelimiter()

local function PostText(hwnd, str) -- https://docs.microsoft.com/en-us/windows/win32/inputdev/wm-char
    for char in string.gmatch(str, ".") do
        ret = reaper.JS_WindowMessage_Post(hwnd, "WM_CHAR", string.byte(char),0,0,0)
        if not ret then break end
    end
end

function SetExplorerPath(hwnd, folder)
    local cbo = reaper.JS_Window_FindChildByID(hwnd, 1002)
    local edit = reaper.JS_Window_FindChildByID(cbo, 1001)
    if edit then
        reaper.JS_Window_SetTitle(edit, "")
        -- PostText(edit, folder) -- 中文乱码
        reaper.JS_Window_SetTitle(edit, folder)
        -- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
        reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x20, 0, 0, 0) -- SPACEBAR
        reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x08, 0, 0, 0) -- BACKSPACE key
        -- reaper.JS_WindowMessage_Post(edit, "WM_KEYDOWN", 0x28, 0,0,0) -- DOWN ARROW key
        -- reaper.JS_WindowMessage_Post(edit, "WM_KEYUP", 0x28, 0,0,0) -- DOWN ARROW key
    end
end

function setReaperExplorerPath(f)
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    SetExplorerPath(hwnd, f)
end

function getReaperExplorerPath()
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local path_hwnd = reaper.JS_Window_FindChildByID(hWnd, 1002)
    return reaper.JS_Window_GetTitle(path_hwnd, "", 255)
end

function interval(f, t)
    local _last = os.clock()
    local active = true
    local function iv()
        if (os.clock() - _last >= t) then
            _last = os.clock()
            f()
        end
        if active then
            reaper.defer(iv)
        end
    end
    reaper.defer(iv)
    return function () active = false end
end