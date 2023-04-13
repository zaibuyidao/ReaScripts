-- NoIndex: true

------- USER-DEFINED_AREA_START | 用户自定义开始 --------

OPEN_RENDER_METADATA_WINDOW = true -- To close the render metadata window enter : fasle | 要关闭渲染元数据窗口请输入 : fasle
ENABLE_EXTENSION_ID = false -- To enable the extension ID enter : true | 要激活扩展ID请输入 : true
INSERT_MARKERS_AT_END_OF_REGION = false -- If this option is enabled, the Metadata markers will be inserted in the end position of the Region. | 如果启用该选项，元数据标记将被写入Region的末端位置。

local _TrackTitle = "$regionname"
local _Description = "UCS Metadata Region Manager (The Region/Marker Manager window must be focused in order to work)"
local _Keywords = "Undead$; Zombie$; Horror$; Male$; Voice$; Vocal. Male zombie gasping$; snarling and moaning raspy$; wet and tonally."
local _Microphone = "MKH416 P48"
local _MicPerspective = "CU"
local _RecMedium = "RME Fireface UFX II"
local _Designer = "zaibuyidao"
local _Library = "The Temple of Deicide"
local _URL = "www.soundengine.cn"
local _Location = "Los Angeles$; USA"
local _FXName = "$fxname"
local _CatID = "$catid"
local _VendorCategory = "$vendorcat"
local _UserCategory = "$usercat"
local _ShortID = "$creatorid"
local _Show = "$sourceid"

-- Extension ID List | 扩展ID列表
local Artist = ""
local Notes = ""
local RecType = ""
local Manufacturer = ""
local CDTitle = ""
local Source = ""
local Publisher = ""
local Composer = ""
local LongID = ""

------- USER-DEFINED_AREA_END | 用户自定义结束 -------

function getPathDelimiter()
  if not reaper.GetOS():match("^Win") then
    return "/"
  else
    return "\\"
  end
end

PATH_DELIMITER = getPathDelimiter()
base_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
loadfile(base_path .. PATH_DELIMITER .."lib" .. PATH_DELIMITER .. "catid.lua")()

local TrackTitle = reaper.GetExtState("UCSMetadataRegion", "TrackTitle")
local Description = reaper.GetExtState("UCSMetadataRegion", "Description")
local Keywords = reaper.GetExtState("UCSMetadataRegion", "Keywords")
local Microphone = reaper.GetExtState("UCSMetadataRegion", "Microphone")
local MicPerspective = reaper.GetExtState("UCSMetadataRegion", "MicPerspective")
local RecMedium = reaper.GetExtState("UCSMetadataRegion", "RecMedium")
local Designer = reaper.GetExtState("UCSMetadataRegion", "Designer")
local Library = reaper.GetExtState("UCSMetadataRegion", "Library")
local URL = reaper.GetExtState("UCSMetadataRegion", "URL")
local Location = reaper.GetExtState("UCSMetadataRegion", "Location")
local FXName = reaper.GetExtState("UCSMetadataRegion", "FXName")
local CatID = reaper.GetExtState("UCSMetadataRegion", "CatID")
local VendorCategory = reaper.GetExtState("UCSMetadataRegion", "VendorCategory")
local UserCategory = reaper.GetExtState("UCSMetadataRegion", "UserCategory")
local ShortID = reaper.GetExtState("UCSMetadataRegion", "ShortID")
local Show = reaper.GetExtState("UCSMetadataRegion", "Show")

if (TrackTitle == "") then TrackTitle = _TrackTitle end
if (Description == "") then Description = _Description end
if (Keywords == "") then Keywords = _Keywords end
if (Microphone == "") then Microphone = _Microphone end
if (MicPerspective == "") then MicPerspective = _MicPerspective end
if (RecMedium == "") then RecMedium = _RecMedium end
if (Designer == "") then Designer = _Designer end
if (Library == "") then Library = _Library end
if (URL == "") then URL = _URL end
if (Location == "") then Location = _Location end
if (FXName == "") then FXName = _FXName end
if (CatID == "") then CatID = _CatID end
if (VendorCategory == "") then VendorCategory = _VendorCategory end
if (UserCategory == "") then UserCategory = _UserCategory end
if (ShortID == "") then ShortID = _ShortID end
if (Show == "") then Show = _Show end

local MD = {}
MD["IXML:USER:CatID"]          = "CatID"
MD["IXML:USER:Category"]       = "Category"
MD["IXML:USER:SubCategory"]    = "SubCategory"
MD["IXML:USER:UserCategory"]   = "UserCategory"
MD["IXML:USER:VendorCategory"] = "VendorCategory"
MD["IXML:USER:CategoryFull"]   = "CategoryFull"
MD["IXML:USER:FXName"]         = "FXName" -- 音效名
MD["IXML:USER:Description"]    = "Description" -- 描述
MD["IXML:USER:Notes"]          = "Notes" -- 录音的附加信息
MD["IXML:USER:Microphone"]     = "Microphone" -- 麦克风
MD["IXML:USER:MicPerspective"] = "MicPerspective" -- 麦克风距离音源的大约多远，以及录音中它是在室内还是室外
MD["IXML:USER:RecType"]        = "RecType" -- 通常用于文件的类型 - 即人声、乐器、叙事、配音（Vocal, Instrumental,Narration, Voiceover）等。或者用于原始格式......录音类型--房间音，野生轨道。
MD["IXML:USER:RecMedium"]      = "RecMedium" -- 原生介质 - DVD、CD、VHS等(使用的记录仪名称)
MD["IXML:USER:Library"]        = "Library" -- 音效库
MD["IXML:USER:Designer"]       = "Designer" -- 音效创作者的名字
MD["IXML:USER:Show"]           = "Show" -- 设计声音的项目名称
MD["IXML:USER:TrackYear"]      = "TrackYear" -- 2022
MD["IXML:USER:TrackTitle"]     = "TrackTitle" -- 乐曲名称
MD["IXML:USER:Keywords"]       = "Keywords" -- 关键词
MD["IXML:USER:Location"]       = "Location" -- 在音效中很有用，可以指出声音是在哪里录制的。
MD["IXML:USER:Artist"]         = "Artist" -- 如果使用乐队材料，艺术家可能是表演者和或作曲者以外的人，请使用此字段。
MD["IXML:USER:Manufacturer"]   = "Manufacturer" -- 制造商或分销商/供应商或所有者的名称(创作者/公司名称)
MD["IXML:USER:CDTitle"]        = "CDTitle" -- CD的标题
MD["IXML:USER:URL"]            = "URL" -- 网址
MD["IXML:USER:ReleaseDate"]    = "ReleaseDate" -- 创建日期 2022-05-07
MD["IXML:USER:ShortID"]        = "ShortID" -- 保留给缩短的类别命名(制造商缩写)
MD["IXML:USER:Source"]         = "Source" -- 它被用来自动填充音量和曲目(Volume and TRACK)字段。它必须被格式化为VOLUME_TRACK。
MD["IXML:USER:Publisher"]      = "Publisher" -- 出版商的名称，应包含隶属关系和百分比信息。它应遵循一致的格式。即：MyMusicCo (ASCAP) 50%|YourMusicCo (BMI) 50%
MD["IXML:USER:Composer"]       = "Composer" -- 作曲家的名字，应包含隶属关系和百分比信息，如果有的话，还应包含IPI/CAE编号。我们建议的格式化标准如下: Johan P. Smith (ASCAP) 50% [123456789], John G. Doe (BMI) 50% [098765432] 
MD["IXML:USER:LongID"]         = "LongID" -- 通常保留备用ID，或作为V3系统的备用，该系统没有轨道标题专用字段。它也可以用于内部ID号码。
MD["INFO:INAM"]                = "Title"
MD["INFO:IKEY"]                = "Description"
MD["INFO:IART"]                = "Artist"
MD["INFO:IPRD"]                = "Album"
-- MD["XMP:dc/title"]             = "Title"
-- MD["XMP:dc/description"]       = "Description"
-- MD["XMP:dm/album"]             = "Album"
-- MD["XMP:dm/artist"]            = "Artist"

for k, v in pairs(MD) do
  if v == "ReleaseDate" then
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$date", true)
  elseif v == "TrackYear" then
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$year", true)
  elseif v == "Title" then
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$region", true) -- region name
  elseif v == "Album" then
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$marker(Library)", true)
  elseif v == "Artist" then
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$marker(Designer)", true)
  else
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$marker(" .. v .. ")", true)
  end
end
-- reaper.MB("成功添加 Soundminer iXML 元数据标记！","工程渲染元数据",0)

if OPEN_RENDER_METADATA_WINDOW then
  reaper.Main_OnCommand(42397, 0) -- File: Show project render metadata window
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

local bias = 0.002 -- 補償偏差值

function print(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
end

if not reaper.SNM_GetIntConfigVar then
  local retval = reaper.ShowMessageBox("This script requires the SWS Extension.\n該脚本需要 SWS 擴展。\n\nDo you want to download it now? \n你想現在就下載它嗎？", "Warning 警告", 1)
  if retval == 1 then
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open " .. "http://www.sws-extension.org/download/pre-release/")
    else
      os.execute("start " .. "http://www.sws-extension.org/download/pre-release/")
    end
  end
  return
end

if not reaper.APIExists("JS_Localize") then
  reaper.MB("Please right-click and install 'js_ReaScriptAPI: API functions for ReaScripts'.\n請右鍵單擊並安裝 'js_ReaScriptAPI: API functions for ReaScripts'。\n\nThen restart REAPER and run the script again, thank you!\n然後重新啟動 REAPER 並再次運行腳本，謝謝！\n", "You must install JS_ReaScriptAPI 你必須安裝JS_ReaScriptAPI", 0)
  local ok, err = reaper.ReaPack_AddSetRepository("ReaTeam Extensions", "https://github.com/ReaTeam/Extensions/raw/master/index.xml", true, 1)
  if ok then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  else
    reaper.MB(err, "錯誤", 0)
  end
  return reaper.defer(function() end)
end

function setFocusToWindow()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local hwnd = reaper.JS_Window_Find(title, 0) -- 0 代表匹配整个标题
  reaper.BR_Win32_SetFocus(hwnd)
end

function GetRegionManager()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local arr = reaper.new_array({}, 1024)
  reaper.JS_Window_ArrayFind(title, true, arr)
  local adr = arr.table()
  for j = 1, #adr do
    local hwnd = reaper.JS_Window_HandleFromAddress(adr[j])
    -- verify window by checking if it also has a specific child.
    if reaper.JS_Window_FindChildByID(hwnd, 1056) then -- 1045:ID of clear button
      return hwnd
    end 
  end
end

local hWnd = GetRegionManager()
if hWnd == nil then return end
local container = reaper.JS_Window_FindChildByID(hWnd, 1071)
local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
if sel_count == 0 then return end

function chsize(char)
  if not char then
    return 0
  elseif char > 240 then
    return 4
  elseif char > 225 then
    return 3
  elseif char > 192 then
    return 2
  else
    return 1
  end
end

function utf8_len(str)
  local len = 0
  local currentIndex = 1
  while currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    len = len + 1
  end
  return len
end

function utf8_sub1(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  newChars = utf8_len(str) - endChars
  while newChars > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    newChars = newChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8_sub2(str,startChar,endChars)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
    local char = string.byte(str,startIndex)
    startIndex = startIndex + chsize(char)
    startChar = startChar - 1
  end
  local currentIndex = startChar
  while tonumber(endChars) > 0 and currentIndex <= #str do
    local char = string.byte(str,currentIndex)
    currentIndex = currentIndex + chsize(char)
    endChars = endChars - 1
  end
  return str:sub(startIndex,currentIndex - 1)
end

function utf8_sub3(str,startChar)
  local startIndex = 1
  startChar = startChar + 1
  while startChar > 1 do
      local char = string.byte(str,startIndex)
      startIndex = startIndex + chsize(char)
      startChar = startChar - 1
  end
  return str:sub(startIndex)
end

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and isrgn then
      pos2 = string.sub(string.format("%.10f", pos), 1, -8) -- 截取到小數點3位數
      rgnend2 = string.sub(string.format("%.10f", rgnend), 1, -8) -- 截取到小數點3位數

      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos2,
        right = rgnend2,
        name = name,
        color = color,
        left_ori = pos,
        right_ori = rgnend
      })
    end
  end
  return result
end

function get_sel_regions()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end
  local sel_index = {}

  local rgn_name, rgn_left, rgn_right, mng_regions, cur = {}, {}, {}, {}, {}
  local rgn_selected_bool = false

  j = 0
  for index in string.gmatch(sel_indexes, '[^,]+') do
    j = j + 1
    local sel_item = reaper.JS_ListView_GetItemText(container, tonumber(index), 1)

    if sel_item:find("R") ~= nil then
      rgn_name[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 2)
      rgn_left[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 3)
      rgn_right[j] = reaper.JS_ListView_GetItemText(container, tonumber(index), 4)

      cur = {
        regionname = rgn_name[j],
        left = tonumber(rgn_left[j]),
        right = tonumber(rgn_right[j])
      }
    
      table.insert(mng_regions, {
        regionname = cur.regionname,
        left = cur.left,
        right = cur.right
      })

      rgn_selected_bool = true
    end
  end

  -- 标记选中区域
  for _, merged_rgn in ipairs(mng_regions) do
    local l, r = 1, #all_regions
    -- 查找第一个左端点在左侧的区域
    while l <= r do
      local mid = math.floor((l+r)/2)
      if (all_regions[mid].left - bias) > merged_rgn.left then
        r = mid - 1
      else
        l = mid + 1
      end
    end
    if math.abs( (merged_rgn.right - merged_rgn.left) - (all_regions[r].right - all_regions[r].left) ) <= bias * 2 then
      sel_index[r] = true
    end

    -- if merged_rgn.right <= all_regions[r].right + bias then
    --   sel_index[r] = true
    -- end
  end

  -- 处理结果
  local result = {}
  local indexs = {}
  for k, _ in pairs(sel_index) do table.insert(indexs, k) end
  table.sort(indexs)
  for _, v in ipairs(indexs) do table.insert(result, all_regions[v]) end

  return result
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left_ori, region.right_ori, region.name, region.color)
end

local language = getSystemLanguage()

local show_msg = reaper.GetExtState("UCSMetadataRegionManager", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "UCS元数据区域管理器"
    text = "$regionname: 区域名称\n$;: 代替半角逗号\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory 可选的FXName前缀\n$usercat: UserCategory 可选的CatID后缀\n$creatorid: CreatorID 声音设计师、录音师或者发行商的名字(缩写)\n$sourceid: SourceID 项目或音效库名(缩写)\n\nv=01: 区域计数\nv=01-05 or v=05-01: 循环区域计数\na=a: 字母计数\na=a-e or a=e-a: 循环字母计数\nr=10: 随机字符串长度\n\n"
    text = text.."\n下次还显示此页面吗？"
    heading = "通配符 :\n\n"
  elseif language == "繁体中文" then
    script_name = "UCS元數據區域管理器"
    text = "$regionname: 區域名稱\n$;: 代替半角逗號\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory 可選的FXName前綴\n$usercat: UserCategory 可選的CatID后綴\n$creatorid: CreatorID 聲音設計師、錄音師或者發行商的名字(縮寫)\n$sourceid: SourceID 項目或音效庫名(縮寫)\n\nv=01: 區域計數\nv=01-05 or v=05-01: 循環區域計數\na=a: 字母計數\na=a-e or a=e-a: 循環字母計數\nr=10: 隨機字符串長度\n\n"
    text = text.."\n下次還顯示此頁面嗎？"
    heading = "通配符 :\n\n"
  else
    script_name = "UCS Metadata Region Manager"
    text = "$regionname: Region name\n$;: Replace commas\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory\n$usercat: UserCategory\n$creatorid: CreatorID\n$sourceid: SourceID\n\nv=01: Region count\nv=01-05 or v=05-01: Loop region count\na=a: Letter count\na=a-e or a=e-a: Loop letter count\nr=10: Random string length\n\n"
    text = text.."\nWill this list be displayed next time?"
    heading = "Wildcards :\n\n"
  end

  local box_ok = reaper.ShowMessageBox(heading .. text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("UCSMetadataRegionManager", "ShowMsg", show_msg, true)
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 默認使用標尺的時間單位:秒
if reaper.GetToggleCommandStateEx(0, 40365) == 1 then -- View: Time unit for ruler: Minutes:Seconds
  minutes_seconds_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40367) == 1 then -- View: Time unit for ruler: Measures.Beats
  meas_beat_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41916) == 1 then -- View: Time unit for ruler: Measures.Beats (minimal)
  meas_beat_mini_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40368) == 1 then -- View: Time unit for ruler: Seconds
  seconds_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40369) == 1 then -- View: Time unit for ruler: Samples
  samples_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 40370) == 1 then -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
  hours_frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

if reaper.GetToggleCommandStateEx(0, 41973) == 1 then -- View: Time unit for ruler: Absolute frames
  frames_flag = true
  reaper.Main_OnCommand(40368, 0) -- View: Time unit for ruler: Seconds
end

local reverse = 1
local sel_regions = get_sel_regions()

if minutes_seconds_flag then reaper.Main_OnCommand(40365, 0) end -- View: Time unit for ruler: Minutes:Seconds
if seconds_flag then reaper.Main_OnCommand(40368, 0) end -- View: Time unit for ruler: Seconds
if meas_beat_flag then reaper.Main_OnCommand(40367, 0) end -- View: Time unit for ruler: Measures.Beats
if meas_beat_mini_flag then reaper.Main_OnCommand(41916, 0) end -- View: Time unit for ruler: Measures.Beats (minimal)
if samples_flag then reaper.Main_OnCommand(40369, 0) end -- View: Time unit for ruler: Samples
if hours_frames_flag then reaper.Main_OnCommand(40370, 0) end -- View: Time unit for ruler: Hours:Minutes:Seconds:Frames
if frames_flag then reaper.Main_OnCommand(41973, 0) end -- View: Time unit for ruler: Absolute frames

function str_split(str,delimiter)
  local dLen = string.len(delimiter)
  local newDeli = ''
  for i=1,dLen,1 do
    newDeli = newDeli .. "["..string.sub(delimiter,i,i).."]"
  end

  local locaStart,locaEnd = string.find(str,newDeli)
  local arr = {}
  local n = 1
  while locaStart ~= nil do
    if locaStart>0 then
      arr[n] = string.sub(str,1,locaStart-1)
      n = n + 1
    end

    str = string.sub(str,locaEnd+1,string.len(str))
    locaStart,locaEnd = string.find(str,newDeli)
  end
  if str ~= nil then
    arr[n] = str
  end
  return arr
end

title = "UCS Metadata Region Manager"
lable = "Title,Description,Keywords,Microphone,MicPerspective,RecMedium,Designer,Library,URL,Location,FXName,CatID,VendorCategory,UserCategory,CreatorID,SourceID,extrawidth=300"
default = TrackTitle ..','.. Description ..','.. Keywords ..','.. Microphone ..','.. MicPerspective ..','.. RecMedium ..','.. Designer ..','.. Library ..','.. URL ..','.. Location ..','.. FXName ..','.. CatID ..','.. VendorCategory ..','.. UserCategory ..','..ShortID ..','.. Show
local uok, uinput = reaper.GetUserInputs(title, 16, lable, default)
if not uok then return end

TrackTitle, Description, Keywords, Microphone, MicPerspective, RecMedium, Designer, Library, URL, Location, FXName, CatID, VendorCategory, UserCategory, ShortID, Show = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

reaper.SetExtState("UCSMetadataRegion", "TrackTitle", TrackTitle, false)
reaper.SetExtState("UCSMetadataRegion", "Description", Description, false)
reaper.SetExtState("UCSMetadataRegion", "Keywords", Keywords, false)
reaper.SetExtState("UCSMetadataRegion", "Microphone", Microphone, false)
reaper.SetExtState("UCSMetadataRegion", "MicPerspective", MicPerspective, false)
reaper.SetExtState("UCSMetadataRegion", "RecMedium", RecMedium, false)
reaper.SetExtState("UCSMetadataRegion", "Designer", Designer, false)
reaper.SetExtState("UCSMetadataRegion", "Library", Library, false)
reaper.SetExtState("UCSMetadataRegion", "URL", URL, false)
reaper.SetExtState("UCSMetadataRegion", "Location", Location, false)
reaper.SetExtState("UCSMetadataRegion", "FXName", FXName, false)
reaper.SetExtState("UCSMetadataRegion", "CatID", CatID, false)
reaper.SetExtState("UCSMetadataRegion", "VendorCategory", VendorCategory, false)
reaper.SetExtState("UCSMetadataRegion", "UserCategory", UserCategory, false)
reaper.SetExtState("UCSMetadataRegion", "ShortID", ShortID, false)
reaper.SetExtState("UCSMetadataRegion", "Show", Show, false)

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("$regionname", origin_name)

  if reverse == "1" then
    build_pattern = build_pattern:gsub("v=(%d+)%-(%d+)", function (start_idx, end_idx) -- 匹配循环数字序号
      local len = #start_idx
      start_idx = tonumber(start_idx)
      end_idx = tonumber(end_idx)
      if start_idx > end_idx then
        return string.format("%0" .. len .. "d", start_idx - ((i - 1) % (start_idx - end_idx + 1)))
      end
      return string.format("%0" .. len .. "d", start_idx + ((i - 1) % (end_idx - start_idx + 1)))
    end)
  end

  build_pattern = build_pattern:gsub("v=(%d+)", function (start_idx) -- 匹配数字序号
    return string.format("%0" .. #start_idx .. "d", tonumber(start_idx) + i - 1)
  end)

  build_pattern = build_pattern:gsub("$catid", function (x)
    local origin_name_t = str_split(origin_name,'_')
    local split
    if #origin_name_t < 4 then split = "" end
    if #origin_name_t >= 4 then
      local cat_id = origin_name_t[1] -- CatID 位置
      if string.match(cat_id, '-') then
        split = str_split(cat_id,'-')[1]
      else
        split = cat_id
      end
    end
    return split
  end)
  
  build_pattern = build_pattern:gsub("$fxname", function () -- 音效名
    local origin_name_t = str_split(origin_name,'_')
    local split = ""
    if #origin_name_t < 4 then split = "" end
    if #origin_name_t >= 4 then
      fx_name = origin_name_t[2] -- FXName 位置
      if string.match(fx_name, '-') then
        split = str_split(fx_name,'-')[2]
      else
        split = fx_name
      end
    end
    return split
  end)

  build_pattern = build_pattern:gsub("$vendorcat", function () -- VendorCategory
    local origin_name_t = str_split(origin_name,'_')
    local s = ""
    if #origin_name_t >= 2 then
      ven_cat = origin_name_t[2] -- VendorCategory 位置
      if string.match(ven_cat, '-') then
        s = str_split(ven_cat,'-')[1]
      else
        s = ""
      end
    end
    return s
  end)

  build_pattern = build_pattern:gsub("$usercat", function () -- UserCategory
    local origin_name_t = str_split(origin_name,'_')
    local split = ""
    if #origin_name_t >= 2 then
      local user_cat = origin_name_t[1] -- UserCategory 位置
      if string.match(user_cat, '-') then
        split = str_split(user_cat,'-')[2]
      else
        split = ""
      end
    end
    return split
  end)

  build_pattern = build_pattern:gsub("$creatorid", function ()
    local origin_name_t = str_split(origin_name,'_')
    local split = ""
    if #origin_name_t < 4 then split = "" end
    if #origin_name_t >= 4 then
      local cre_id = origin_name_t[3]
      split = cre_id
    end
    return split
  end)

  build_pattern = build_pattern:gsub("$sourceid", function ()
    local origin_name_t = str_split(origin_name,'_')
    local split = ""
    if #origin_name_t < 4 then split = "" end
    if #origin_name_t >= 4 then
      local sou_id = origin_name_t[4]
      split = sou_id
    end
    return split
  end)

  build_pattern = build_pattern:gsub("r=(%d+)", function (n)
    local t = {
      "0","1","2","3","4","5","6","7","8","9",
      "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
      "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    }
    local s = ""
    for i = 1, n do
      s = s .. t[math.random(#t)]
    end
    return s
  end)
  
  local ab = string.byte("a")
  local zb = string.byte("z")
  local Ab = string.byte("A")
  local Zb = string.byte("Z")

  if reverse == "1" then
    build_pattern = build_pattern:gsub("a=([A-Z])%-([A-Z])", function(c1, c2) -- 匹配循环大写字母
      local c1b = c1:byte()
      local c2b = c2:byte()
      if c1b > c2b then
        return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
      end
      return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
    end)
  
    build_pattern = build_pattern:gsub("a=([a-z])%-([a-z])", function(c1, c2) -- 匹配循环小写字母
      local c1b = c1:byte()
      local c2b = c2:byte()
      if c1b > c2b then
        return string.char(c1b - ((i - 1) % (c1b - c2b + 1)))
      end
      return string.char(c1b + ((i - 1) % (c2b - c1b + 1)))
    end)
  end

  build_pattern = build_pattern:gsub("a=([A-Za-z])", function(c) -- 匹配字母
    local cb = c:byte()
    if cb >= ab and cb <= zb then
      return string.char(ab + ((cb - ab) + (i - 1)) % 26)
    elseif cb >= Ab and cb <= Zb then
      return string.char(Ab + ((cb - Ab) + (i - 1)) % 26)
    end
  end)

  return build_pattern
end

function create_marker(reg_start, reg_end, name, i)
  if name == nil then return end
  local index = reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, -1, 0)
  -- reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, i, 0)
end

for i,region in ipairs(sel_regions) do

  local origin_name = region.name

  if INSERT_MARKERS_AT_END_OF_REGION then region.left = region.right + 0.001 end

  region.name = CatID
  if CatID ~= '' then
    region.name = build_name(region.name, origin_name, i)
    catid_match(region.name)
    -- if region.name == "$catid" then region.name = "" end
    create_marker(region.left, region.right, 'CatID='..region.name, i)
    if Category ~= nil or SubCategory ~= nil or CategoryFull ~= nil then
      create_marker(region.left, region.right, 'Category='..Category, i)
      create_marker(region.left, region.right, 'SubCategory='..SubCategory, i)
      create_marker(region.left, region.right, 'CategoryFull='..CategoryFull, i)
    end
  end

  region.name = VendorCategory
  if VendorCategory ~= "" then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'VendorCategory='..region.name, i)
  end

  region.name = UserCategory
  if UserCategory ~= "" then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'UserCategory='..region.name, i)
  end

  region.name = TrackTitle
  if TrackTitle ~= "" then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'TrackTitle='..region.name, i)
    -- create_marker(region.left, region.right, 'TrackYear='..(os.date("*t").year), i)
  end

  region.name = FXName
  if FXName ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'FXName='..region.name, i)
  end

  region.name = Description
  if Description ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'Description='..region.name, i)
  end

  region.name = Keywords
  if Keywords ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'Keywords='..region.name, i)
  end

  region.name = Microphone
  if Microphone ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'Microphone='..region.name, i)
  end
  
  region.name = MicPerspective
  if MicPerspective ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'MicPerspective='..region.name, i)
  end

  region.name = RecMedium
  if RecMedium ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, 'RecMedium='..region.name, i)
  end

  region.name = Designer
  if Designer ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "Designer="..region.name, i)
  end

  region.name = Library
  if Library ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "Library="..region.name, i)
  end

  region.name = URL
  if URL ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "URL="..region.name, i)
  end
  
  region.name = Location
  if Location ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "Location="..region.name, i)
  end

  region.name = ShortID
  if ShortID ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "ShortID="..region.name, i)
  end

  region.name = Show
  if Show ~= '' then
    region.name = build_name(region.name, origin_name, i)
    create_marker(region.left, region.right, "Show="..region.name, i)
  end

  if ENABLE_EXTENSION_ID then
    region.name = build_name(region.name, origin_name, i)
    if Artist ~= "" then create_marker(region.left, region.right, "Artist=" .. Artist, i) end
    if Notes ~= "" then create_marker(region.left, region.right, "Notes=" .. Notes, i) end
    if RecType ~= "" then create_marker(region.left, region.right, "RecType=" .. RecType, i) end
    if Manufacturer ~= "" then create_marker(region.left, region.right, "Manufacturer=" .. Manufacturer, i) end
    if CDTitle ~= "" then create_marker(region.left, region.right, "CDTitle=" .. CDTitle, i) end
    if Source ~= "" then create_marker(region.left, region.right, "Source=" .. Source, i) end
    if Publisher ~= "" then create_marker(region.left, region.right, "Publisher=" .. Publisher, i) end
    if Composer ~= "" then create_marker(region.left, region.right, "Composer=" .. Composer, i) end
    if LongID ~= "" then create_marker(region.left, region.right, "LongID=" .. LongID, i) end
  end
end

setFocusToWindow()
reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()