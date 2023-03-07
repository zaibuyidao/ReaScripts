-- @description Date & Time
-- @version 1.0.8
-- @author zaibuyidao
-- @changelog Initial release
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Not Requires JS_ReaScriptAPI & SWS Extension

function print(...)
  local args = {...}
  local str = ""
  for i = 1, #args do
    str = str .. string.format("%s\t", tostring(args[i]))
  end
  reaper.ShowConsoleMsg(str .. "\n")
end

function getSystemLanguage()
  local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))
  local os = reaper.GetOS()
  local lang

  if os == "Win32" or os == "Win64" then -- Windows
    if locale == 936 then -- Simplified Chinese
      lang = "简体中文"
    elseif locale == 950 then -- Traditional Chinese
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "OSX32" or os == "OSX64" then -- macOS
    local handle = io.popen("/usr/bin/defaults read -g AppleLocale")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("_", "-"):match("[a-z]+%-[A-Z]+")
    if lang == "zh-CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh-TW" then -- 繁体中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  elseif os == "Linux" then -- Linux
    local handle = io.popen("echo $LANG")
    local result = handle:read("*a")
    handle:close()
    lang = result:gsub("%\n", ""):match("[a-z]+%-[A-Z]+")
    if lang == "zh_CN" then -- 简体中文
      lang = "简体中文"
    elseif lang == "zh_TW" then -- 繁體中文
      lang = "繁體中文"
    else -- English
      lang = "English"
    end
  end

  return lang
end

local language = getSystemLanguage()

local fmt_date = function(year, month, day, fmt)
  if (fmt == "DD/MM/YY") then
    return string.format("%02d/%02d/%02d", day, month, year)
  elseif (fmt == "MM/DD/YY") then
    return string.format("%s %02d, %02d", month, day, year)
  else
    return string.format("%02d年%01d月%02d日", year, month, day)
  end
end

if language == "简体中文" or language == "繁体中文" then
  amhms = "上午 %01d:%02d:%02d"
  pmhms = "下午 %01d:%02d:%02d"
else
  amhms = "%01d:%02d:%02d AM"
  pmhms = "%01d:%02d:%02d PM"
end

local fmt_hms = function(hour, min, sec, TIME_24H_Flag)  
  if (nil ~= sec) then
    assert((nil ~= hour) and (nil ~= min))
    
    if (TIME_24H_Flag) then
      return string.format("%02d:%02d:%02d", hour, min, sec)
    else
      local h = math.floor(tonumber(hour))
      
      if (h < 12) then
        if (0 == h) then h = 12 end
        return string.format(amhms, h, min, sec)
      else
        if (12 == h) then h = 24 end
        return string.format(pmhms, h-12, min, sec)
      end
    end
  end
end

local fmt_time = function(wday_flag, year, mon, mday, hour, min, sec)
  if ((nil ~= year) and (nil ~= mon) and (nil ~= mday) and (nil ~= hour) and (nil ~= min) and (nil ~= sec)) then
    if language == "简体中文" or language == "繁体中文" then
      local week = {"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
      local w = os.date("%w", os.time{year=year, month=mon, day=mday})
      local day = math.floor(tonumber(w)) + 1
      local fmt = "YY/MM/DD"

      return string.format("%s %s %s", fmt_date(year, mon, mday), week[day]..",", fmt_hms(hour, min, sec))
    else
      local week = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
      local moon = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
      local w = os.date("%w", os.time{year=year, month=mon, day=mday})
      local day = math.floor(tonumber(w)) + 1
      local m = os.date("%m", os.time{year=year, month=mon, day=mday})
      local yue = math.floor(tonumber(m))
      local fmt = "MM/DD/YY"

      return string.format("%s %s %s", fmt_hms(hour, min, sec)..",", week[day]..",", fmt_date(year, tostring(moon[yue]), mday, fmt))
    end
  end
end

defer_cnt = 0

function cooldown()
  if defer_cnt >= 30 then -- run mainloop() every ~900ms
    defer_cnt = 0
    reaper.PreventUIRefresh(1)
    mainloop()
    reaper.PreventUIRefresh(-1)
  else
    defer_cnt = defer_cnt+1
  end
  reaper.defer(cooldown)
end

local gui = {}

function init()

  -- Add stuff to "gui" table
  gui.settings = {}                 -- Add "settings" table to "gui" table
  gui.settings.docker_id = 0        -- try 0, 1, 257, 513, 1027 etc.

  if language == "简体中文" then
    gui.settings.font_size = 21    -- font size
    gfx.init("日期和时间", 300, 35, gui.settings.docker_id)
    gfx.setfont(1,"Microsoft YaHei UI", gui.settings.font_size) -- Microsoft YaHei, Microsoft YaHei UI, Microsoft YaHei UI Light
  elseif language == "繁体中文" then
    gui.settings.font_size = 21    -- font size
    gfx.init("日期和時間", 300, 35, gui.settings.docker_id)
    gfx.setfont(1,"Microsoft YaHei UI", gui.settings.font_size)
  else
    gui.settings.font_size = 20     -- font size
    gfx.init("Date & Time", 360, 35, gui.settings.docker_id)
    gfx.setfont(1,"Arial", gui.settings.font_size) -- Arial
  end

  gfx.clear = 3355443  -- matches with "FUSION: Pro&Clean Theme :: BETA 01" http://forum.cockos.com/showthread.php?t=155329

  -- mainloop()
end

function mainloop()
  local time = os.date("%Y/%m/%d %H:%M:%S", os.time())
  local year, mon, mday, hour, min, sec = string.match(time, "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")

  -- time = os.date("*t")

  gfx.x = 10
  gfx.y = 10
  
  gfx.printf(fmt_time(true, year, mon, mday, hour, min, sec))

  -- uncomment this if you want hh:mm::ss
  -- gfx.printf(("%02d:%02d"):format(time.hour, time.min))
  -- gfx.printf(("%02d:%02d:%02d"):format(time.hour, time.min, time.sec))
  -- gfx.printf(("%04d/%02d/%02d %02d:%02d:%02d"):format(time.year, time.month, time.day, time.hour, time.min, time.sec))

  gfx.update()
  -- if gfx.getchar() >= 0 then reaper.defer(mainloop) end
end

init()
cooldown()