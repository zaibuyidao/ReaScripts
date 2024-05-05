-- @description Randomize Region Colors
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

function RegionRGB()
    local R = math.random(256) - 1
    local G = math.random(256) - 1
    local B = math.random(256) - 1
    return R, G, B
end

function RGBHexToDec(R, G, B)
    local red = string.format("%x", R)
    local green = string.format("%x", G)
    local blue = string.format("%x", B)
    if (#red < 2) then red = "0" .. red end
    if (#green < 2) then green = "0" .. green end
    if (#blue < 2) then blue = "0" .. blue end
    local color = "01" .. blue .. green .. red
    return tonumber(color, 16)
end

function Main()
    local marker_ok, num_markers, num_regions = reaper.CountProjectMarkers(0)
    if marker_ok and (num_markers or num_regions ~= 0) then
        for i = 1, num_markers + num_regions do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i - 1)
            if retval ~= nil then
                local region = {}
                region.pos = pos
                region.name = name
                region.rgnend = rgnend
                region.idx = markrgnindexnumber
                region.color = RGBHexToDec(RegionRGB())
                if isrgn == true then
                    reaper.SetProjectMarker3(0, region.idx, isrgn, region.pos, region.rgnend, region.name, region.color)
                end
            end
        end
    end
end
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Randomize Region Colors", -1)
reaper.UpdateArrange()