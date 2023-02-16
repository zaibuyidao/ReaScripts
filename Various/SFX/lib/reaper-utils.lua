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

function send_search_text(text) -- 开始搜索
    local title = reaper.JS_Localize("Media Explorer", "common")
    local hwnd = reaper.JS_Window_Find(title, true)
    local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
    if search == nil then return end
    reaper.JS_Window_SetTitle(search, text)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
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

function getDbList()
    local reaperConfig = LIP.load(reaper.GetResourcePath() .. PATH_DELIMITER .. "reaper.ini")
    local i = 1
    local reaper_explorer = reaperConfig.reaper_explorer
    local res = {}
    while true do
        if not reaper_explorer["Shortcut" .. i] then
            break
        end
        if reaper_explorer["Shortcut" .. i]:find("^%d+%.ReaperFileList$") then
            table.insert(res, {
                path = reaper.GetResourcePath() .. PATH_DELIMITER .. "MediaDB" .. PATH_DELIMITER .. reaper_explorer["Shortcut" .. i],
                name = reaper_explorer["ShortcutT" .. i]
            })
        end
        i = i + 1
    end
    return res
end

local GLOBAL_STATE_SECTION

function setGlobalStateSection(section)
    GLOBAL_STATE_SECTION = section
end

function getState(key, default, convert)
	local value = reaper.GetExtState(GLOBAL_STATE_SECTION, key)
    if not value then return default end
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
        PostText(edit, folder)
        -- https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
        reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", 0x28, 0,0,0)
        reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", 0x26, 0,0,0)
    end
end

function setReaperExplorerPath(f)
    SetExplorerPath(reaper.JS_Window_Find("Media Explorer", true), f)
end

function getReaperExplorerPath()
    local hWnd = reaper.JS_Window_Find("Media Explorer", true)
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