-- @description Humanize Take Pan
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
if count_sel_items > 0 then

  local strength = reaper.GetExtState("HUMANIZE_TAKE_PAN", "STRENGTH")
  if (strength == "") then strength = "30" end

  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  
  local function check_locale(locale)
    if locale == 936 then
      return true
    elseif locale == 950 then
      return true
    end
    return false
  end

  default = strength

  if reaper.GetOS():match("Win") then
    if check_locale(locale) == false then
      title = "Humanize Take Pan"
      lable = "Strength %:"
    else
      title = "片段聲像人性化"
      lable = "强度 %:"
    end
  else
    title = "Humanize Take Pan"
    lable = "Strength %:"
  end

  local uok, uinput = reaper.GetUserInputs(title, 1, lable, default)
  if not uok then return end

  strength = uinput:match("(.*)")
  strength = tonumber(strength)
  if strength == 0 then return end

  reaper.SetExtState("HUMANIZE_TAKE_PAN", "STRENGTH", strength, false)
  
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local take_pan = reaper.GetMediaItemTakeInfo_Value(take, 'D_PAN')
      local input = (strength+1)*2
      local rand = math.floor(math.random()*(input-1)-(input/2))+1
      rand = take_pan+rand/100
      if rand > 100 then rand = 100
      elseif rand < -100 then
        rand = -100
      end
      if not reaper.TakeIsMIDI(take) then
        reaper.SetMediaItemTakeInfo_Value(take, 'D_PAN', rand)
      end
    end
    reaper.UpdateItemInProject(item)
  end
  reaper.Undo_EndBlock(title, -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end