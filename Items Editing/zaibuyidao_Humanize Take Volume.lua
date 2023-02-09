-- @description Humanize Take Volume
-- @version 1.0.1
-- @author zaibuyidao
-- @changelog Optimized code
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Not Requires SWS Extensions

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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)
local log10 = function(x) return math.log(x, 10) end

local strength = reaper.GetExtState("HUMANIZE_TAKE_VOLUME", "STRENGTH")
if (strength == "") then strength = "3" end
local toggle = reaper.GetExtState("HUMANIZE_TAKE_VOLUME", "TOGGLE")
if (toggle == "") then toggle = "n" end

local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))

function check_locale(locale)
  if locale == 936 then
    return true
  elseif locale == 950 then
    return true
  end
  return false
end

if count_sel_items > 0 then
  default = strength ..','.. toggle

  if reaper.GetOS():match("Win") then
    if check_locale(locale) == false then
      title = "Humanize Take Volume"
      lable = "Strength dB:,Use integer? (y/n)"
    else
      title = "片段音量人性化"
      lable = "强度 dB:,是否使用整數 (y/n)"
    end
  else
    title = "Humanize Take Volume"
    lable = "Strength dB:,Use integer? (y/n)"
  end

  local uok, uinput = reaper.GetUserInputs(title, 2, lable, default)
  if not uok then return end

  strength, toggle = uinput:match("(.*),(.*)")
  strength, toggle = tonumber(strength), tostring(toggle)

  reaper.SetExtState("HUMANIZE_TAKE_VOLUME", "STRENGTH", strength, false)
  reaper.SetExtState("HUMANIZE_TAKE_VOLUME", "TOGGLE", toggle, false)
  strength = math.abs(strength-1)

  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)

    if take then
      local take_vol = reaper.GetMediaItemTakeInfo_Value(take, 'D_VOL')
      local take_db = 20*log10(take_vol)
      local delta_db = strength - take_db
      local input = (strength+1)*2

      if not reaper.TakeIsMIDI(take) then
        if toggle == "y" then
          rand = math.floor(math.random()*(input+1)-(input/2)) -- 隨機整數
        else
          rand = math.random()*(input)-(input/2)
        end

        local new_db = take_vol*10^(0.05*rand)
        reaper.SetMediaItemTakeInfo_Value(take, 'D_VOL', new_db)
        reaper.UpdateItemInProject(item)
      end
    end
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()