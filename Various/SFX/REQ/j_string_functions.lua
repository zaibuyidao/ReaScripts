--[[
@author n0ne
@version 0.7.0
@noindex
--]]

function jStringExplodeOld(s, sep)
    -- Explode a string by seperator
    -- Returns #1: Table with parts
    -- Returns #2: Amount of times the seperator can be found
    -- If the seperator is NOT found it will return a table with 1 element and 0.
    local tResult = {}
    local i = 0
    
    -- Check if the seperator  is found
    -- if not s:find(sep, 1, true) then
    --     table.insert(tResult, s)
    --     return tResult, i
    -- end


    local run = true
    local start = 1
    while run do
        local begin, fin = s:find(sep, start, true)
        if begin then
            table.insert(tResult, s:sub(start, fin - #sep))
            start = fin + 1
            i = i + 1
        else
            table.insert(tResult, s:sub(start, s:len()))
            run = false
        end
    end


    return tResult, i
end


function jStringExplode(s, sep, bIgnoreCase)
    -- Explode a string by seperator
    -- Returns #1: Table with parts
    -- Returns #2: Amount of times the seperator can be found
    -- If the seperator is NOT found it will return a table with 1 element and 0.
    -- Default is case sensitive, use bIgnoreCase to turn off

    -- Potential bug: two consequitive occurances of sep will insert an empty element. Is that correct?

    local bIgnoreCase = false or bIgnoreCase

    local tResult = {}
    local i = 0
    local sOrig = s

    if bIgnoreCase then
        s = s:lower()
        sep = sep:lower()
    end


    local run = true
    local start = 1
    while run do
        local begin, fin = s:find(sep, start, true)
        if begin then
            table.insert(tResult, sOrig:sub(start, fin - #sep))
            start = fin + 1
            i = i + 1
        else
            table.insert(tResult, sOrig:sub(start, s:len()))
            run = false
        end
    end


    return tResult, i
end




function jStringTrim(s)
    return s:match "^%s*(.-)%s*$"
end

function jStringIsInt(s)
    local r = s:match("^(%d+)$")
    return r ~= nil
end