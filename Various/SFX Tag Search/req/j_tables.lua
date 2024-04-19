--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function tableToString(st, iLevel)
    iLevel = iLevel or 0
    if iLevel == 0 and type(st) ~= "table" then
        msg("TableToString ERROR: did not get table, value: " .. tostring(st))
        return false
    end
    sResult = ""
	for i,v in pairs(st) do
        sResult = sResult .. string.rep("\t", iLevel) .. tostring(i) .. " => "
        if type(v) == "table" then
            sResult = sResult .. "[]" .. "\n"
            sResult = sResult .. tableToString(v, iLevel+1)
    	else sResult = sResult .. (tostring(v)) .. "\n"
        end
	end
    return sResult
end

function tableMultiConcat(t, sSeperator)
    --iLevel = iLevel or 0
    sResult = ""
    for i,v in pairs(t) do
        if type(v) == "table" then
            sResult = sResult .. tableMultiConcat(v, sSeperator)
        else
            sResult = sResult .. v .. sSeperator
        end
    end
    return sResult    
end

function tableMultiGet(t, i)
    if type(t) ~= "table" then
        msg("tableMutliGet() error: Was expecting a table, didn't get one.")
        return false
    end
    
    if #i == 1 then
        -- this is what we are looking for
        return t[i[1]]
    elseif #i > 1 then  
        j = table.remove(i, 1)
        return tableMultiGet(t[j], i)
    else
        msg("tableMultiGet() Error: Not in table.")
        return false
    end
end

function tableMultiSet(t, i, v)
    if type(t) ~= "table" then
        msg("tableMultiSet() error: Was expecting a table, didn't get one.")
        --msg(t)
        return false
    end
    
    if #i == 1 then
        -- this is what we are looking for
        t[i[1]] = v
        return true
    elseif #i > 1 then  
        j = table.remove(i, 1)
        return tableMultiSet(t[j], i, v)
    else
        msg("tableMultiSet() error: Not in table.")
        return false
    end
end

function tableMultiCount(t, s)
    -- counts occurences of s in table t. Does brach search.
    -- uses string:find for compare
    iResult = 0
    for i, v in pairs(t) do
        if type(v) == "table" then
            -- go in branch
            iResult = iResult + tableMultiCount(v, s)
        elseif v:find(s) then
            iResult = iResult + 1
        end
    end
    return iResult
end
-- function stringExplode(s, sep)
--     tResult = {}
    
--     for st in string.gmatch(s, "(.-)"..sep) do
--         table.insert(tResult, st)
--     end
    
--     return tResult
-- end



function tablePrint(t)
    if type(t) ~= "table" then
        msg("TablePrint, got no table, value: " .. tostring(t))
        return false
    else
        msg(tableToString(t))
    end
end

function tableSearch(t, string) -- NOT TESTED YET, works so far...
    if type(t) ~= "table" then
        msg("tableSearch(), got no table, value: " .. tostring(t))
        return false
    else
        for i, v in pairs(t) do
            if v == string then
                return i
            end
        end
    end
    
    -- Default string not found
    return false -- Used to be 0
end

function tableFind(t, string) -- NOT TESTED YET, works so far... This one uses string.find() instead of == for comparison
    if type(t) ~= "table" then
        msg("tableSearch(), got no table, value: " .. tostring(t))
        return false
    else
        for i, v in pairs(t) do
            if v:find(string) then
                return i
            end
        end
    end
    
    -- Default string not found
    return 0
end

function tableSearchHeader(t, string)
    if type(t) ~= "table" then
        msg("tableSearch(), got no table, value: " .. tostring(t))
        return false
    else
        for i, v in pairs(t) do
            if tostring(i) == string then
                msg("found" .. tostring(i))
                return i
            end
        end
    end
    
    -- Default string not found
    return false
end

function jTablesGlue(t1, t2)
    -- Join together two tables, sticking t2 begin t1. Returns the result
	return table.move(t2, 1, #t2, #t1 + 1, t1)
end
