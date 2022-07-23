--[[
 * ReaScript Name: Date & Time
 * Version: 1.0
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

local fmt_date = function(year, month, day, fmt)
	if (fmt == "DD/MM/YY") then
		return string.format("%02d/%02d/%02d", day, month, year)
	elseif (fmt == "DD/YY") then
		return string.format("%01d, %0d", day, year) -- 定义日位数
  elseif (fmt == "MM/DD/YY") then
		return string.format("%02d %02d, %02d", month, day, year)
	else
		return string.format("%02d/%02d/%02d", year, month, day)
	end
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
				return string.format("%01d:%02d:%02d AM", h, min, sec) -- 定义时位数
			else
				if (12 == h) then h = 24 end
				return string.format("%01d:%02d:%02d PM", h-12, min, sec) -- 定义时位数
			end
		end
	elseif (nil ~= min) then
		assert(nil ~= hour)
		
		if (TIME_24H_Flag) then
			return string.format("%02d:%02d", hour, min)
		else
			local h = math.floor(tonumber(hour))
			
			if (h < 12) then
				if (0 == h) then h = 12 end
				return string.format("%02d:%02d AM", h, min)
			else
				if (12 == h) then h = 24 end
				return string.format("%02d:%02d PM", h-12, min)
			end
		end
	else
		assert(nil ~= hour)
		
		if (TIME_24H_Flag) then
			return string.format("%02d", hour)
		else
			local h = math.floor(tonumber(hour))
			
			if (h < 12) then
				if (0 == h) then h = 12 end
				return string.format("%02d:00 AM", h)
			else
				if (12 == h) then h = 24 end
				return string.format("%02d:00 PM", h-12)
			end
		end
	end
end

local fmt_time = function(wday_flag, year, mon, mday, hour, min, sec)
	if ((nil ~= year) and (nil ~= mon) and (nil ~= mday) and (nil ~= hour) and (nil ~= min) and (nil ~= sec)) then
		if (("boolean" == type(wday_flag)) and (wday_flag)) then
			local week = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
			local w = os.date("%w", os.time{year=year, month=mon, day=mday})
			local day = math.floor(tonumber(w)) + 1
			local months = os.date("%B")
      local fmt = "DD/YY"
      
      return string.format("%s %s %s %s", fmt_hms(hour, min, sec)..", ", week[day]..", ", months, fmt_date(year, mon, mday, fmt))
			-- return string.format("%s %s %s %s", fmt_hms(hour, min, sec)..", ", week[day]..", ", months, fmt_date(year, mon, mday, fmt))
		else
			return string.format("%s %s", fmt_date(year, mon, mday), fmt_hms(hour, min, sec))
		end
	end
	
	if ((nil ~= year) and (nil ~= mon) and (nil ~= mday) and (nil == hour) and (nil == min) and (nil == sec)) then
		if (("boolean" == type(wday_flag)) and (wday_flag)) then
			local week = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
			local w = os.date("%w", os.time{year = year, month = mon, day = mday})
			local day = math.floor(tonumber(w)) + 1
			
      return string.format("%s %s", fmt_date(year, mon, mday), week[day])
		else
			return string.format("%s", fmt_date(year, mon, mday))
		end
	end
	
	if ((nil == year) and (nil == mon) and (nil == mday) and (nil ~= hour) and (nil ~= min)) then
		return string.format("%s", fmt_hms(hour, min, sec))
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

-- Empty GUI template

----------
-- Init --
----------

-- GUI table ----------------------------------------------------------------------------------
--   contains GUI related settings (some basic user definable settings), initial values etc. --
-----------------------------------------------------------------------------------------------

local gui = {}

function init()

  -- Add stuff to "gui" table
  gui.settings = {}                 -- Add "settings" table to "gui" table
  gui.settings.font_size = 20       -- font size
  gui.settings.docker_id = 0        -- try 0, 1, 257, 513, 1027 etc.
  
  ---------------------------
  -- Initialize gfx window --
  ---------------------------
  
  gfx.init("Date & Time", 350, 35, gui.settings.docker_id)
  gfx.setfont(1,"Arial", gui.settings.font_size)
  gfx.clear = 3355443  -- matches with "FUSION: Pro&Clean Theme :: BETA 01" http://forum.cockos.com/showthread.php?t=155329
  -- (Double click in ReaScript IDE to open the link)

  -- mainloop()
end

--------------
-- Mainloop --
--------------

function mainloop()
  local time = os.date("%Y/%m/%d %H:%M:%S", os.time())
  local year, mon, mday, hour, min, sec = string.match(time, "(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")

  -- time = os.date("*t")

  --------------
  -- Draw GUI --
  --------------
  
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