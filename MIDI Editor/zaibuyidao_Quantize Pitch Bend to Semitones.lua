-- @description Quantize Pitch Bend to Semitones
-- @version 1.0
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Pitch Bend Script Series, filter "zaibuyidao pitch bend" in ReaPack or Actions to access all scripts.
--   Requires JS_ReaScriptAPI & SWS Extension

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local language = getSystemLanguage()

function equals(a, b)
    return math.abs(a - b) < 0.0000001
end

function getSegments(n)
    local x = 8192
    local p = math.floor((x / n) + 0.5) -- 四舍五入
    local arr = {}
    local cur = 0
    for i = 1, n do
        cur = cur + p
        table.insert(arr, math.min(cur, x))
    end
    local res = {}
    for i = #arr, 1, -1 do
        table.insert(res, -arr[i])
    end
    table.insert(res, 0)
    for i = 1, #arr do
        table.insert(res, arr[i])
    end
    res[#res] = 8191 -- 将最后一个点强制设为8191，否则8192会被reaper处理为-8192
    return res
end

function alignTo(origin, targets)
    if #targets == 0 then error() end
    if origin < targets[1] then return targets[1] end
    for i = 2, #targets do
        if equals(origin, targets[i - 1]) then return targets[i - 1] end
        if (origin < targets[i - 1]) then goto continue end
        if equals(origin, targets[i]) then return targets[i] end

        if origin > targets[i - 1] and origin < targets[i] then
            local mid = (targets[i] + targets[i-1]) / 2
            if equals(origin, mid) then
                if mid < 0 then return targets[i-1] end
                return targets[i]
            end
            if origin < mid then return targets[i-1] end
            return targets[i]
        end
        ::continue::
    end
    return targets[#targets]
end

-- a = getSegments(6)
-- table.print(a)
-- b = 4096
-- print(alignTo(b, a))
-- os.exit()

local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())

local cnt, index = 0, {}
local val = reaper.MIDI_EnumSelCC(take, -1)
while val ~= -1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
end

if #index > 0 then
    local n = reaper.GetExtState("QuantizePitchBendtoSemitones", "PitchRange")
    if (n == "") then n = "2" end

    if language == "简体中文" then
        title = "将弯音量化为半音"
        captions_csv = "弯音范围:"
    elseif language == "繁體中文" then
        title = "將彎音量化為半音"
        captions_csv = "彎音範圍:"
    else
        title = "Quantize Pitch Bend to Semitones"
        captions_csv = "Pitchwheel Range:"
    end

    local uok, n = reaper.GetUserInputs(title, 1, captions_csv, n)
    
    if not uok or not tonumber(n) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("QuantizePitchBendtoSemitones", "PitchRange", n, false)
    n = tonumber(n)
    local seg = getSegments(n)

    reaper.Undo_BeginBlock()
    for i = 1, #index do
        local retval, selected, muted, ppqpos, chanmsg, chan, LSB, MSB = reaper.MIDI_GetCC(take, index[i])
        local pitch = (MSB - 64) * 128 + LSB -- 获取 LSB（低7位）MSB（高7位）的弯音值

        -- print(LSB, MSB)
        -- print(pitch)
        -- local pitchbend = pitch + 8192

        -- print(pitch, alignTo(pitch, seg))

        pitch = alignTo(pitch, seg)
        
        LSB = pitch & 0x7F
        MSB = (pitch >> 7) + 64

        reaper.MIDI_SetCC(take, index[i], selected, muted, ppqpos, chanmsg, chan, LSB, MSB, false)
        reaper.Undo_EndBlock(title, -1)
    end
end

reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()