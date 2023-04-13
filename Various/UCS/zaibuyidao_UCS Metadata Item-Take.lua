-- NoIndex: true

local count_sel_items = reaper.CountSelectedMediaItems(0)
if count_sel_items < 1 then return end

------- USER-DEFINED_AREA_START | 用户自定义开始 --------

OPEN_RENDER_METADATA_WINDOW = true -- To close the render metadata window enter : fasle | 要关闭渲染元数据窗口请输入 : fasle
ENABLE_EXTENSION_ID = false -- To enable the extension ID enter : true | 要激活扩展ID请输入 : true
INSERT_MARKERS_AT_END_OF_ITEM = false -- If this option is enabled, the Metadata markers will be inserted in the end position of the Item-Take. | 如果启用该选项，元数据标记将被写入Item-Take的末端位置。

local _TrackTitle = "$takename"
local _Description = "UCS Metadata Item-Take (for selected item-take)"
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

local TrackTitle = reaper.GetExtState("UCSMetadataItemTake", "TrackTitle")
local Description = reaper.GetExtState("UCSMetadataItemTake", "Description")
local Keywords = reaper.GetExtState("UCSMetadataItemTake", "Keywords")
local Microphone = reaper.GetExtState("UCSMetadataItemTake", "Microphone")
local MicPerspective = reaper.GetExtState("UCSMetadataItemTake", "MicPerspective")
local RecMedium = reaper.GetExtState("UCSMetadataItemTake", "RecMedium")
local Designer = reaper.GetExtState("UCSMetadataItemTake", "Designer")
local Library = reaper.GetExtState("UCSMetadataItemTake", "Library")
local URL = reaper.GetExtState("UCSMetadataItemTake", "URL")
local Location = reaper.GetExtState("UCSMetadataItemTake", "Location")
local FXName = reaper.GetExtState("UCSMetadataItemTake", "FXName")
local CatID = reaper.GetExtState("UCSMetadataItemTake", "CatID")
local VendorCategory = reaper.GetExtState("UCSMetadataItemTake", "VendorCategory")
local UserCategory = reaper.GetExtState("UCSMetadataItemTake", "UserCategory")
local ShortID = reaper.GetExtState("UCSMetadataItemTake", "ShortID")
local Show = reaper.GetExtState("UCSMetadataItemTake", "Show")

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
    local ret, str = reaper.GetSetProjectInfo_String(0, "RENDER_METADATA", k .. "|$item", true) -- item take name
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

local function Msg(str)
  reaper.ShowConsoleMsg(tostring(str).."\n")
end

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

local language = getSystemLanguage()

local show_msg = reaper.GetExtState("UCSMetadataItemTake", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  if language == "简体中文" then
    script_name = "UCS元数据对象-片段"
    text = "$takename: 片段名称\n$;: 代替半角逗号\n$trackname: 轨道名称\n$foldername: 文件夹名称\n$tracknum: 轨道编号\n$GUID: 片段 GUID\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory 可选的FXName前缀\n$usercat: UserCategory 可选的CatID后缀\n$creatorid: CreatorID 声音设计师、录音师或者发行商的名字(缩写)\n$sourceid: SourceID 项目或音效库名(缩写)\n\nv=01: 区域计数\nv=01-05 or v=05-01: 循环区域计数\na=a: 字母计数\na=a-e or a=e-a: 循环字母计数\nr=10: 随机字符串长度\n\n"
    text = text.."\n下次还显示此页面吗？"
    heading = "通配符 :\n\n"
  elseif language == "繁体中文" then
    script_name = "UCS元數據對象-片段"
    text = "$takename: 片段名稱\n$;: 代替半角逗號\n$trackname: 軌道名稱\n$foldername: 文件夾名稱\n$tracknum: 軌道編號\n$GUID: 片段 GUID\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory 可選的FXName前綴\n$usercat: UserCategory 可選的CatID后綴\n$creatorid: CreatorID 聲音設計師、錄音師或者發行商的名字(縮寫)\n$sourceid: SourceID 項目或音效庫名(縮寫)\n\nv=01: 區域計數\nv=01-05 or v=05-01: 循環區域計數\na=a: 字母計數\na=a-e or a=e-a: 循環字母計數\nr=10: 隨機字符串長度\n\n"
    text = text.."\n下次還顯示此頁面嗎？"
    heading = "通配符 :\n\n"
  else
    script_name = "UCS Metadata Item-Take"
    text = "$takename: Take name\n$;: Replace commas\n$trackname: Track name\n$foldername: Folder name\n$tracknum: Track number\n$GUID: Take GUID\n$fxname: FXName\n$catid: CatID\n$vendorcat: VendorCategory\n$usercat: UserCategory\n$creatorid: CreatorID\n$sourceid: SourceID\n\nv=01: Region count\nv=01-05 or v=05-01: Loop region count\na=a: Letter count\na=a-e or a=e-a: Loop letter count\nr=10: Random string length\n\n"
    text = text.."\nWill this list be displayed next time?"
    heading = "Wildcards :\n\n"
  end

  local box_ok = reaper.ShowMessageBox(heading .. text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("UCSMetadataItemTake", "ShowMsg", show_msg, true)
  end
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

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

local order = "2"
local reverse = "1"

title = "UCS Metadata Item-Take"
lable = "Title,Description,Keywords,Microphone,MicPerspective,RecMedium,Designer,Library,URL,Location,FXName,CatID,VendorCategory,UserCategory,CreatorID,SourceID,extrawidth=300"
default = TrackTitle ..','.. Description ..','.. Keywords ..','.. Microphone ..','.. MicPerspective ..','.. RecMedium ..','.. Designer ..','.. Library ..','.. URL ..','.. Location ..','.. FXName ..','.. CatID ..','.. VendorCategory ..','.. UserCategory ..','..ShortID ..','.. Show
local uok, uinput = reaper.GetUserInputs(title, 16, lable, default)
if not uok then return end

TrackTitle, Description, Keywords, Microphone, MicPerspective, RecMedium, Designer, Library, URL, Location, FXName, CatID, VendorCategory, UserCategory, ShortID, Show = retvals_csv:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")

reaper.SetExtState("UCSMetadataItemTake", "TrackTitle", TrackTitle, false)
reaper.SetExtState("UCSMetadataItemTake", "Description", Description, false)
reaper.SetExtState("UCSMetadataItemTake", "Keywords", Keywords, false)
reaper.SetExtState("UCSMetadataItemTake", "Microphone", Microphone, false)
reaper.SetExtState("UCSMetadataItemTake", "MicPerspective", MicPerspective, false)
reaper.SetExtState("UCSMetadataItemTake", "RecMedium", RecMedium, false)
reaper.SetExtState("UCSMetadataItemTake", "Designer", Designer, false)
reaper.SetExtState("UCSMetadataItemTake", "Library", Library, false)
reaper.SetExtState("UCSMetadataItemTake", "URL", URL, false)
reaper.SetExtState("UCSMetadataItemTake", "Location", Location, false)
reaper.SetExtState("UCSMetadataItemTake", "FXName", FXName, false)
reaper.SetExtState("UCSMetadataItemTake", "CatID", CatID, false)
reaper.SetExtState("UCSMetadataItemTake", "VendorCategory", VendorCategory, false)
reaper.SetExtState("UCSMetadataItemTake", "UserCategory", UserCategory, false)
reaper.SetExtState("UCSMetadataItemTake", "ShortID", ShortID, false)
reaper.SetExtState("UCSMetadataItemTake", "Show", Show, false)

function build_name(build_pattern, origin_name, i)
  build_pattern = build_pattern:gsub("%$takename", origin_name)
  build_pattern = build_pattern:gsub('%$trackname', track_name)
  build_pattern = build_pattern:gsub('%$tracknum', track_num)
  build_pattern = build_pattern:gsub('%$GUID', take_guid)
  build_pattern = build_pattern:gsub('%$foldername', parent_buf)

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

  build_pattern = build_pattern:gsub("$;", function (y)
    local t = ","
    return t
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
  -- reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, i, 0)
  local index = reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, -1, 0)
end

if order == "0" then
  local track_items = {}

  for i = 0, count_sel_items - 1  do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    if not track_items[track] then track_items[track] = {} end
    table.insert(track_items[track], item)
  end
  
  for _, items in pairs(track_items) do
    for i, item in ipairs(items) do
      take = reaper.GetActiveTake(item)
      track = reaper.GetMediaItem_Track(item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      parent_track = reaper.GetParentTrack(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      origin_name = reaper.GetTakeName(take)

      set_take_name(take, take_name, i - 1)
    end
  end
elseif order == "1" then
  for z = 0, count_sel_items - 1 do -- 按換行順序排序
    item = reaper.GetSelectedMediaItem(0, z)
    track = reaper.GetMediaItem_Track(item)
    track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    track_num = string.format("%0" .. 2 .. "d", track_num)
    _, track_name = reaper.GetTrackName(track)
    parent_track = reaper.GetParentTrack(track)
    if parent_track ~= nil then
      _, parent_buf = reaper.GetTrackName(parent_track)
    else
      parent_buf = ''
    end

    take = reaper.GetActiveTake(item)
    take_name = reaper.GetTakeName(take)
    take_guid = reaper.BR_GetMediaItemTakeGUID(take)
    origin_name = reaper.GetTakeName(take)

    set_take_name(take, take_name, z)
  end
elseif order == "2" then -- 按時間綫順序排序
  local startEvents = {}
  for i = 0, count_sel_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local track = reaper.GetMediaItem_Track(item)
    local pitch = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
    local startPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local take = reaper.GetActiveTake(item)
    local takeName = reaper.GetTakeName(take)
    if startEvents[startPos] == nil then startEvents[startPos] = {} end
    local event = {
      ["startPos"]=startPos,
      ["pitch"]=pitch,
      ["takeName"]=takeName,
      ["item"]=item
    }
    
    table.insert(startEvents[startPos], event)
  end

  local tempEvents = {}
  for i in pairs(startEvents) do
    table.insert(tempEvents,i)  
  end
  table.sort(tempEvents,function(a,b)return (tonumber(a) < tonumber(b)) end) -- 對key進行升序

  local result = {}
  for i,v in pairs(tempEvents) do
    table.insert(result,startEvents[v])
  end

  j = 0
  for _, list in pairs(result) do
    for i = 1, #list do
      j = j + 1
      track = reaper.GetMediaItem_Track(list[i].item)
      track_num = reaper.GetMediaTrackInfo_Value(track, 'IP_TRACKNUMBER')
      track_num = string.format("%0" .. 2 .. "d", track_num)
      _, track_name = reaper.GetTrackName(track)
      parent_track = reaper.GetParentTrack(track)
      if parent_track ~= nil then
        _, parent_buf = reaper.GetTrackName(parent_track)
      else
        parent_buf = ''
      end

      take = reaper.GetActiveTake(list[i].item)
      take_name = reaper.GetTakeName(take)
      take_guid = reaper.BR_GetMediaItemTakeGUID(take)
      origin_name = reaper.GetTakeName(take)

      item_pos = reaper.GetMediaItemInfo_Value(list[i].item, "D_POSITION")
      item_end = reaper.GetMediaItemInfo_Value(list[i].item, "D_POSITION") + reaper.GetMediaItemInfo_Value(list[i].item, "D_LENGTH")

      if INSERT_MARKERS_AT_END_OF_ITEM then item_pos = item_end + 0.001 end

      take_name = CatID
      if CatID ~= '' then
        take_name = build_name(take_name, origin_name, j)
        catid_match(take_name)
        create_marker(item_pos, item_end, 'CatID='..take_name, j)
        if Category ~= nil or SubCategory ~= nil or CategoryFull ~= nil then
          create_marker(item_pos, item_end, 'Category='..Category, j)
          create_marker(item_pos, item_end, 'SubCategory='..SubCategory, j)
          create_marker(item_pos, item_end, 'CategoryFull='..CategoryFull, j)
        end
      end
    
      take_name = VendorCategory
      if VendorCategory ~= "" then
        take_name = build_name(take_name, origin_name, j)
        create_marker(item_pos, item_end, 'VendorCategory='..take_name, j)
      end
    
      take_name = UserCategory
      if UserCategory ~= "" then
        take_name = build_name(take_name, origin_name, j)
        create_marker(item_pos, item_end, 'UserCategory='..take_name, j)
      end
    
      take_name = TrackTitle
      if TrackTitle ~= "" then
        take_name = build_name(take_name, origin_name, j)
        create_marker(item_pos, item_end, 'TrackTitle='..take_name, j)
        -- create_marker(item_pos, item_end, 'TrackYear='..(os.date("*t").year), i)
      end
    
      take_name = FXName
      if FXName ~= '' then
        take_name = build_name(take_name, origin_name, j)
        create_marker(item_pos, item_end, 'FXName='..take_name, j)
      end
    
      take_name = Description
      if Description ~= '' then
        take_name = build_name(take_name, origin_name, j)
        create_marker(item_pos, item_end, 'Description='..take_name, j)
      end
    
      take_name = Keywords
      if Keywords ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, 'Keywords='..take_name, i)
      end
    
      take_name = Microphone
      if Microphone ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, 'Microphone='..take_name, i)
      end
      
      take_name = MicPerspective
      if MicPerspective ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, 'MicPerspective='..take_name, i)
      end
    
      take_name = RecMedium
      if RecMedium ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, 'RecMedium='..take_name, i)
      end
    
      take_name = Designer
      if Designer ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "Designer="..take_name, i)
      end
    
      take_name = Library
      if Library ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "Library="..take_name, i)
      end
    
      take_name = URL
      if URL ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "URL="..take_name, i)
      end
      
      take_name = Location
      if Location ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "Location="..take_name, i)
      end
    
      take_name = ShortID
      if ShortID ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "ShortID="..take_name, i)
      end
    
      take_name = Show
      if Show ~= '' then
        take_name = build_name(take_name, origin_name, i)
        create_marker(item_pos, item_end, "Show="..take_name, i)
      end
    
      if ENABLE_EXTENSION_ID then
        take_name = build_name(take_name, origin_name, i)
        if Artist ~= "" then create_marker(item_pos, item_end, "Artist=" .. Artist, i) end
        if Notes ~= "" then create_marker(item_pos, item_end, "Notes=" .. Notes, i) end
        if RecType ~= "" then create_marker(item_pos, item_end, "RecType=" .. RecType, i) end
        if Manufacturer ~= "" then create_marker(item_pos, item_end, "Manufacturer=" .. Manufacturer, i) end
        if CDTitle ~= "" then create_marker(item_pos, item_end, "CDTitle=" .. CDTitle, i) end
        if Source ~= "" then create_marker(item_pos, item_end, "Source=" .. Source, i) end
        if Publisher ~= "" then create_marker(item_pos, item_end, "Publisher=" .. Publisher, i) end
        if Composer ~= "" then create_marker(item_pos, item_end, "Composer=" .. Composer, i) end
        if LongID ~= "" then create_marker(item_pos, item_end, "LongID=" .. LongID, i) end
      end

    end
  end
end

reaper.Undo_EndBlock(title, -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()