--[[
 * ReaScript Name: Date & Time
 * Version: 1.0.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Reference: https://forum.cockos.com/showthread.php?t=165884
--]]

--[[
 * Changelog:
 * v1.0 (2022-7-23)
  + Initial release
--]]

function print(m)
  return reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

-- if reaper.GetOS():match("Win") then
-- end

local locale = tonumber(string.match(os.setlocale(), "(%d+)$"))

function locale_flag()
	if locale ~= 936 and locale ~= 950 and locale ~= nil then
		return true
	else
		return false
	end
end

local fmt_date = function(year, month, day, fmt)
	if (fmt == "DD/MM/YY") then
		return string.format("%02d/%02d/%02d", day, month, year)
  elseif (fmt == "MM/DD/YY") then
		return string.format("%s %02d, %02d", month, day, year)
	else
		return string.format("%02d年%01d月%02d日", year, month, day)
	end
end

if not locale_flag then
	amhms = "%01d:%02d:%02d AM"
	pmhms = "%01d:%02d:%02d PM"
else
	amhms = "上午 %01d:%02d:%02d"
	pmhms = "下午 %01d:%02d:%02d"
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

		if not locale_flag then
			local week = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
			local moon = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
			local w = os.date("%w", os.time{year=year, month=mon, day=mday})
			local day = math.floor(tonumber(w)) + 1
			local m = os.date("%m", os.time{year=year, month=mon, day=mday})
			local yue = math.floor(tonumber(m))
      local fmt = "MM/DD/YY"

      return string.format("%s %s %s", fmt_hms(hour, min, sec)..",", week[day]..",", fmt_date(year, tostring(moon[yue]), mday, fmt))
		else
			local week = {"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
			local w = os.date("%w", os.time{year=year, month=mon, day=mday})
			local day = math.floor(tonumber(w)) + 1
      local fmt = "YY/MM/DD"

			return string.format("%s %s %s", fmt_date(year, mon, mday), week[day]..",", fmt_hms(hour, min, sec))
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
  gui.settings.font_size = 20       -- font size
  gui.settings.docker_id = 0        -- try 0, 1, 257, 513, 1027 etc.

	if not locale_flag then
		gfx.init("Date & Time", 360, 35, gui.settings.docker_id)
	else
		gfx.init("日期和時間", 320, 35, gui.settings.docker_id)
	end
  gfx.setfont(1,"Arial", gui.settings.font_size)
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