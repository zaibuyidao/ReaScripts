--[[
 * ReaScript Name: Add Take Marker At Snap Offset
 * Version: 1.0.1
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-5-22)
  + Initial release
--]]

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

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
local count_sel_items = reaper.CountSelectedMediaItems(0)

if language == "简体中文" then
  title = "在吸附偏移处添加片段标记"
  captions_csv = "新标记,extrawidth=150"
elseif language == "繁体中文" then
  title = "在吸附偏移處添加片段標記"
  captions_csv = "新標記,extrawidth=150"
else
  title = "Add Take Marker At Snap Offset"
  captions_csv = "New Marker,extrawidth=150"
end

if count_sel_items > 0 then
  local retval, retvals_csv = reaper.GetUserInputs(title, 1, captions_csv, '')
  if not retval or not (tonumber(retvals_csv) or tostring(retvals_csv)) then return end
  for i = 0, count_sel_items - 1 do
    local color = green
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local take_start = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local item_snap = reaper.GetMediaItemInfo_Value(item, "D_SNAPOFFSET")
    local snap = take_start + item_snap
    reaper.SetTakeMarker(take, -1, retvals_csv, snap, color)
  end
end
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()