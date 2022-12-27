--[[
@author n0ne
@version 0.7.0
@noindex
--]]

require ('REQ.j_string_functions')
require ('REQ.j_tables')
local STR_FX_CHAIN = "<FXCHAIN"

function jReadFxChainFromFile(fn)
    local file = io.open(fn, "r")
    local fxstr = file:read("a")
    file:close()
    return fxstr:match("^(.+)\n$")
end


function jFxChainAdd(t, strFxChain)
    local chunk = t:getStateChunk()
    local lines = jStringExplode(chunk, "\n")
    table.remove(lines, #lines) -- remove last empty item

    local fxChainPos = tableFind(lines, "^" .. STR_FX_CHAIN)

    if fxChainPos == 0 then
        msg("FX Chain should be created...")
        return false
    end

    local i = fxChainPos + 1
    local depth = 1
    while i <= #lines do
        if lines[i]:find("^<") then
            depth = depth + 1
        elseif lines[i]:find("^>") then
            depth = depth - 1
        end

        if depth == 0 then
            -- msg("found closing bracket at line: ".. i)
            break
        end
        i = i + 1
    end

    local newChunk = ""
    for k, v in ipairs(lines) do
        if k == i then
            -- msg("<-------- insert fx")
            newChunk = newChunk .. "\n" .. strFxChain
        end
        newChunk = newChunk .. "\n" .. v
        -- msg(k .. ": " .. v)
    end

    t:setStateChunk(newChunk)
    -- msg(t:getStateChunk())
end

function jCreateTrackChainForSelectedTracks()
    -- This is a hacky function to create empty FX chains for selected tracks, but its a lot easier than messing with the state chunk
    reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_S&M_SHOWFXCHAINSEL"),1,0) -- SWS/S&M: Show FX chain for selected tracks (selected FX)
    reaper.Main_OnCommandEx(reaper.NamedCommandLookup("_S&M_HIDEFXCHAIN"),1,0) -- SWS/S&M: Hide FX chain windows for selected tracks
end