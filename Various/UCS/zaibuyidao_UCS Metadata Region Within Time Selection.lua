-- NoIndex: true

local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
if time_sel_start == time_sel_end then return end

------- USER-DEFINED_AREA_START | 用户自定义开始 --------

OPEN_RENDER_METADATA_WINDOW = true -- To close the render metadata window enter : fasle | 要关闭渲染元数据窗口请输入 : fasle
ENABLE_EXTENSION_ID = false -- To enable the extension ID enter : true | 要激活扩展ID请输入 : true
INSERT_MARKERS_AT_END_OF_REGION = false -- If this option is enabled, the Metadata markers will be inserted in the end position of the Region. | 如果启用该选项，元数据标记将被写入Region的末端位置。

local _TrackTitle = "$regionname"
local _Description = "UCS Metadata Region Within Time Selection"
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

local bias = 0.002 -- 补偿偏差值

function Msg(param) 
  reaper.ShowConsoleMsg(tostring(param) .. "\n") 
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

function get_all_regions()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval ~= nil and isrgn then
      table.insert(result, {
        index = markrgnindexnumber,
        isrgn = isrgn,
        left = pos,
        right = rgnend,
        name = name,
        color = color
      })
    end
  end
  return result
end

function get_sel_regions()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end
  local sel_index = {}

  local time_regions = {}

  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions-1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
  
    if retval ~= nil and isrgn then
      cur = { left = pos, right = rgnend }
      table.insert(time_regions, cur)
    end
  end

  -- 标记选中区域
  for _, merged_rgn in ipairs(time_regions) do
    local l, r = 1, #all_regions
    -- 查找第一个左端点在item左侧的区域
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
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

local show_msg = reaper.GetExtState("UCSMetadataRegionWithinTimeSelection", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "UCS元數據區域"
  text = "$regionname: Region name 區域名稱\n$;: Comma 逗號。由於輸入框無法輸入逗號，該通配符用於轉換逗號\n$fxname: FXName 簡短描述或標題\n$catid: CatID 分類和子分類的縮寫\n$vendorcat: VendorCategory 可選的FXName前綴\n$usercat: UserCategory 可選的CatID后綴\n$creatorid: CreatorID 聲音設計師、錄音師或者發行商的名字(縮寫)\n$sourceid: SourceID 項目或素材庫名(縮寫)\n\nv=01: Region count 區域計數\nv=01-05 or v=05-01: Loop region count 循環區域計數\na=a: Letter count 字母計數\na=a-e or a=e-a: Loop letter count 循環字母計數\nr=10: Random string length 隨機字符串長度\n\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符:\n\n"..text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("UCSMetadataRegionWithinTimeSelection", "ShowMsg", show_msg, true)
  end
end

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

local reverse = 1
local sel_regions = get_sel_regions()

local retval, retvals_csv = reaper.GetUserInputs("UCS Metadata Region Within Time Selection", 16, "Title 標題,Description 描述,Keywords 關鍵詞,Microphone 麥克風,MicPerspective 麥克風視角,RecMedium 錄音設備,Designer 設計師,Library 素材庫,URL 網址,Location 地點,FXName 音效名稱,CatID UCS核心字段,VendorCategory FXName前綴,UserCategory CatID后綴,CreatorID 創造者ID(縮寫),SourceID 項目ID(縮寫),extrawidth=300", TrackTitle ..','.. Description ..','.. Keywords ..','.. Microphone ..','.. MicPerspective ..','.. RecMedium ..','.. Designer ..','.. Library ..','.. URL ..','.. Location ..','.. FXName ..','.. CatID ..','.. VendorCategory ..','.. UserCategory ..','..ShortID ..','.. Show)
if not retval then return end

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
  local index = reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, -1, 0)
  -- reaper.AddProjectMarker2(0, false, reg_start, reg_end, name, i, 0)
end

j = {}
for i, region in ipairs(sel_regions) do

  if region.left >= time_sel_start then
    if region.isrgn and region.right <= time_sel_end or not region.isrgn and region.left <= time_sel_end then
      j[#j+1] = i

      local origin_name = region.name

      if INSERT_MARKERS_AT_END_OF_REGION then region.left = region.right + 0.001 end

      region.name = CatID
      if CatID ~= '' then
        region.name = build_name(region.name, origin_name, #j)
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
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'VendorCategory='..region.name, i)
      end
    
      region.name = UserCategory
      if UserCategory ~= "" then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'UserCategory='..region.name, i)
      end
    
      region.name = TrackTitle
      if TrackTitle ~= "" then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'TrackTitle='..region.name, i)
        -- create_marker(region.left, region.right, 'TrackYear='..(os.date("*t").year), i)
      end
    
      region.name = FXName
      if FXName ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'FXName='..region.name, i)
      end
    
      region.name = Description
      if Description ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'Description='..region.name, i)
      end
    
      region.name = Keywords
      if Keywords ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'Keywords='..region.name, i)
      end
    
      region.name = Microphone
      if Microphone ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'Microphone='..region.name, i)
      end
      
      region.name = MicPerspective
      if MicPerspective ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'MicPerspective='..region.name, i)
      end
    
      region.name = RecMedium
      if RecMedium ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, 'RecMedium='..region.name, i)
      end
    
      region.name = Designer
      if Designer ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "Designer="..region.name, i)
      end
    
      region.name = Library
      if Library ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "Library="..region.name, i)
      end
    
      region.name = URL
      if URL ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "URL="..region.name, i)
      end
      
      region.name = Location
      if Location ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "Location="..region.name, i)
      end
    
      region.name = ShortID
      if ShortID ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "ShortID="..region.name, i)
      end
    
      region.name = Show
      if Show ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        create_marker(region.left, region.right, "Show="..region.name, i)
      end
    
      if ENABLE_EXTENSION_ID then
        region.name = build_name(region.name, origin_name, #j)
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
  end
end

reaper.Undo_EndBlock('UCS Metadata Region Within Time Selection', -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()