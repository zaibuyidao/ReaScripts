-- NoIndex: true
function print_r(t)
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

function parseCSVLine(line, sep)
	local res = {}
	local pos = 1
	sep = sep or ','
	while true do 
		local c = string.sub(line,pos,pos)
		if (c == "") then break end
        if (c == "`") then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,"^%b``",pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == "`") then txt = txt.."`" end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= "`")
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
        elseif (c == "'") then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,"^%b''",pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == "'") then txt = txt.."'" end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= "'")
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
		elseif (c == '"') then
			-- quoted value (ignore separator within)
			local txt = ""
			repeat
				local startp,endp = string.find(line,'^%b""',pos)
				txt = txt..string.sub(line,startp+1,endp-1)
				pos = endp + 1
				c = string.sub(line,pos,pos) 
				if (c == '"') then txt = txt..'"' end 
				-- check first char AFTER quoted string, if it is another
				-- quoted string without separator, then append it
				-- this is the way to "escape" the quote char in a quote. example:
				--   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
			until (c ~= '"')
			table.insert(res,txt)
            -- if (c ~= sep and c ~= "") then print(line, sep) end
			assert(c == sep or c == "")
			pos = pos + 1
		else	
			-- no quotes used, just look for the first separator
			local startp,endp = string.find(line,sep,pos)
			if (startp) then 
				table.insert(res,string.sub(line,pos,startp-1))
				pos = endp + 1
			else
				-- no separator found -> use rest of string and terminate
				table.insert(res,string.sub(line,pos))
				break
			end 
		end
	end
	return res
end

function readReaperFileList(path, processItem)
    local file = io.open(path, "r")
    if not file then return false end
    while true do
        local line = file:read()
        if line == nil then break end
        processItem(line:match("(%w+) (.+)"))
    end
    return true
end

function readReaperFileListAsync(path)
    local file = io.open(path, "r")
    if not file then return end

    local line = file:read()

    local function nextItem()
        if line ~= nil then
            return line:match("(%w+) (.+)")
        end
        line = file:read()
    end

    local function hasNext()
        return line ~= nil
    end

    return hasNext, nextItem
end

function readDataItemEntry(entry)
    return entry:match("(%w+):(.+)")
end

function string.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function string.trimFileExtension(s)
    return (s:gsub("%..+$", ""))
end

function simplifyPath(path)
    local delimiter = path:match("[/%\\]")
    local parts = {}
    for part in path:gmatch("[^/%\\]+") do
        table.insert(parts, part)
    end
    if #parts <= 3 then
        return path
    end
    return table.concat({ parts[1], "...", parts[#parts - 1], parts[#parts] }, delimiter)
end

function table.keys(tab)
    local keys = {}
    for k, _ in pairs(tab) do
        table.insert(keys, k)
    end
    return keys
end

function table.map(tab, f)
    local res = {}
    for k, v in pairs(tab) do
        res[k] = f(v)
    end
    return res
end

function table.arrayToTable(tab)
    local r = {}
	for k, v in ipairs(tab) do
		r[v] = true
	end
	return r
end

function table.bininsert(t, value, fcomp)
    --  Initialise numbers
    local iStart,iEnd,iMid,iState = 1,#t,1,0
    -- Get insert position
    while iStart <= iEnd do
        -- calculate middle
        iMid = math.floor( (iStart+iEnd)/2 )
        -- compare
        if fcomp( value,t[iMid] ) then
        iEnd,iState = iMid - 1,0
        else
        iStart,iState = iMid + 1,1
        end
    end
    table.insert( t,(iMid+iState),value )
    return (iMid+iState)
end

function table.assign(target, source)
    for k, v in pairs(source) do
        target[k] = v
    end
    return target
end

function readViewModelFromReaperFileList(dbPath, config, async)
    config = config or {}
    local excludeOrigin = config.excludeOrigin or {}
    local delimiters = config.delimiters or {}

    local function iteratorOf(origin, source)
        if not delimiters[origin] then
            if not delimiters.default or #delimiters.default == 0 then
                return source:gmatch(".+")
            end
            return source:gmatch("[^" .. table.concat(delimiters.default) .. "]+")
        end
        if #delimiters[origin] == 0 then
            return source:gmatch(".+")
        end
        return source:gmatch("[^" .. table.concat(delimiters[origin]) .. "]+")
    end

    local keywords = {}

    local function processItem(itemType, content)
        if itemType == "FILE" and not excludeOrigin["File"] then
            local p = (parseCSVLine(content, " "))[1]
            local matchPattern = "[^/%\\]+$"
            if config.containsAllParentDirectories then
                matchPattern = "[^/%\\]+"
            end
            for w in p:gmatch(matchPattern) do
                if not w:match("^%w+:$") then
                    local value = w:trimFileExtension()
                    keywords[value] = keywords[value] or { value = value, from = {} }
                    keywords[value].from["File"] = true
                end
            end
        elseif itemType == "DATA" then
            local ok, entries = pcall(parseCSVLine, content, " ")
            if not ok then
                goto continue
            end
            for _, entry in ipairs(entries) do
                local k, v = readDataItemEntry(entry)
                if k and v and k:lower() == 'u' and not excludeOrigin["Custom Tags"] then
                    for w in iteratorOf("Custom Tags", v) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["Custom Tags"] = true
                    end
                elseif k and v and k:lower() == 'd' and not excludeOrigin["Description"] then
                    for w in iteratorOf("Description", v) do
                        local value = w:trim():trimFileExtension()
                        keywords[value] = keywords[value] or { value = value, from = {} }
                        keywords[value].from["Description"] = true
                    end
                end
            end
        elseif itemType == "USER" and not excludeOrigin["Keywords"] then
            local ok, entries = pcall(parseCSVLine, content, " ")
            if not ok then
                goto continue
            end
            if entries[1] and entries[1]:find("IXML:USER:Keywords") and entries[2] then
                for w in iteratorOf("Keywords", entries[2]) do
                    local value = w:trim():trimFileExtension()
                    keywords[value] = keywords[value] or { value = value, from = {} }
                    keywords[value].from["Keywords"] = true
                end
            end
        end
        ::continue::
    end

    if async then
        local hasNext, _nextItem = readReaperFileList(dbPath)
        local function nextItem()
            return processItem(_nextItem)
        end
        return hasNext, nextItem
    end
    
    if readReaperFileList(dbPath, processItem) then
        return keywords
    end
end