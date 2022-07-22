-- NoIndex: true

local time_sel_start, time_sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
if time_sel_start == time_sel_end then return end

local TrackTitle = reaper.GetExtState("UCSiXMLMetadata", "TrackTitle")
local Description = reaper.GetExtState("UCSiXMLMetadata", "Description")
local Keywords = reaper.GetExtState("UCSiXMLMetadata", "Keywords")
local Microphone = reaper.GetExtState("UCSiXMLMetadata", "Microphone")
local MicPerspective = reaper.GetExtState("UCSiXMLMetadata", "MicPerspective")
local RecMedium = reaper.GetExtState("UCSiXMLMetadata", "RecMedium")
local Designer = reaper.GetExtState("UCSiXMLMetadata", "Designer")
local Library = reaper.GetExtState("UCSiXMLMetadata", "Library")
local URL = reaper.GetExtState("UCSiXMLMetadata", "URL")
local Location = reaper.GetExtState("UCSiXMLMetadata", "Location")
local FXName = reaper.GetExtState("UCSiXMLMetadata", "FXName")
local CatID = reaper.GetExtState("UCSiXMLMetadata", "CatID")
local VendorCategory = reaper.GetExtState("UCSiXMLMetadata", "VendorCategory")
local UserCategory = reaper.GetExtState("UCSiXMLMetadata", "UserCategory")
local ShortID = reaper.GetExtState("UCSiXMLMetadata", "ShortID")
local Show = reaper.GetExtState("UCSiXMLMetadata", "Show")

------- USER-DEFINED_AREA_START | 用户自定义开始 --------

OPEN_RENDER_METADATA_WINDOW = true -- To close the render metadata window enter : fasle | 要关闭渲染元数据窗口请输入 : fasle
ENABLE_EXTENSION_ID = false -- To enable the extension ID enter : true | 要激活扩展ID请输入 : true

if (TrackTitle == "") then TrackTitle = "$regionname" end
if (Description == "") then Description = "UCS Metadata Region Within Time Selection" end
if (Keywords == "") then Keywords = "Undead$; Zombie$; Horror$; Male$; Voice$; Vocal. Male zombie gasping$; snarling and moaning raspy$; wet and tonally." end
if (Microphone == "") then Microphone = "MKH416 P48" end
if (MicPerspective == "") then MicPerspective = "CU" end
if (RecMedium == "") then RecMedium = "RME Fireface UFX II" end
if (Designer == "") then Designer = "zaibuyidao" end
if (Library == "") then Library = "The Temple of Deicide" end
if (URL == "") then URL = "www.soundengine.cn" end
if (Location == "") then Location = "Los Angeles$; USA" end
if (FXName == "") then FXName = "$fxname" end
if (CatID == "") then CatID = "$catid" end
if (VendorCategory == "") then VendorCategory = "$vendorcat" end
if (UserCategory == "") then UserCategory = "$usercat" end
if (ShortID == "") then ShortID = "$creatorid" end
if (Show == "") then Show = "$sourceid" end

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

local show_msg = reaper.GetExtState("UCSMetadataRegion", "ShowMsg")
if (show_msg == "") then show_msg = "true" end

if show_msg == "true" then
  script_name = "UCS元數據區域"
  text = "$regionname: Region name 區域名稱\n$;: Comma 逗號。由於輸入框無法輸入逗號，該通配符用於轉換逗號\n$fxname: FXName 簡短描述或標題\n$catid: CatID 分類和子分類的縮寫\n$vendorcat: VendorCategory 可選的FXName前綴\n$usercat: UserCategory 可選的CatID后綴\n$creatorid: CreatorID 聲音設計師、錄音師或者發行商的名字(縮寫)\n$sourceid: SourceID 項目或素材庫名(縮寫)\n\nv=01: Region count 區域計數\nv=01-05 or v=05-01: Loop region count 循環區域計數\na=a: Letter count 字母計數\na=a-e or a=e-a: Loop letter count 循環字母計數\nr=10: Random string length 隨機字符串長度\n\n"
  text = text.."\nWill this list be displayed next time?\n下次還顯示此列表嗎？"
  local box_ok = reaper.ShowMessageBox("Wildcards 通配符:\n\n"..text, script_name, 4)

  if box_ok == 7 then
    show_msg = "false"
    reaper.SetExtState("UCSMetadataRegion", "ShowMsg", show_msg, true)
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

reaper.SetExtState("UCSiXMLMetadata", "TrackTitle", TrackTitle, false)
reaper.SetExtState("UCSiXMLMetadata", "Description", Description, false)
reaper.SetExtState("UCSiXMLMetadata", "Keywords", Keywords, false)
reaper.SetExtState("UCSiXMLMetadata", "Microphone", Microphone, false)
reaper.SetExtState("UCSiXMLMetadata", "MicPerspective", MicPerspective, false)
reaper.SetExtState("UCSiXMLMetadata", "RecMedium", RecMedium, false)
reaper.SetExtState("UCSiXMLMetadata", "Designer", Designer, false)
reaper.SetExtState("UCSiXMLMetadata", "Library", Library, false)
reaper.SetExtState("UCSiXMLMetadata", "URL", URL, false)
reaper.SetExtState("UCSiXMLMetadata", "Location", Location, false)
reaper.SetExtState("UCSiXMLMetadata", "FXName", FXName, false)
reaper.SetExtState("UCSiXMLMetadata", "CatID", CatID, false)
reaper.SetExtState("UCSiXMLMetadata", "VendorCategory", VendorCategory, false)
reaper.SetExtState("UCSiXMLMetadata", "UserCategory", UserCategory, false)
reaper.SetExtState("UCSiXMLMetadata", "ShortID", ShortID, false)
reaper.SetExtState("UCSiXMLMetadata", "Show", Show, false)

function catid_fun(CatID)
  -- Update (Aug 8th, 2021): Version 8.1
  if CatID == "AIRBlow" then Category = "AIR" SubCategory = "BLOW" CatShort = "AIR" CategoryFull = "AIR-BLOW" end
  if CatID == "AIRBrst" then Category = "AIR" SubCategory = "BURST" CatShort = "AIR" CategoryFull = "AIR-BURST" end
  if CatID == "AIRHiss" then Category = "AIR" SubCategory = "HISS" CatShort = "AIR" CategoryFull = "AIR-HISS" end
  if CatID == "AIRMisc" then Category = "AIR" SubCategory = "MISC" CatShort = "AIR" CategoryFull = "AIR-MISC" end
  if CatID == "AIRSuck" then Category = "AIR" SubCategory = "SUCTION" CatShort = "AIR" CategoryFull = "AIR-SUCTION" end
  if CatID == "AEROHeli" then Category = "AIRCRAFT" SubCategory = "HELICOPTER" CatShort = "AERO" CategoryFull = "AIRCRAFT-HELICOPTER" end
  if CatID == "AEROInt" then Category = "AIRCRAFT" SubCategory = "INTERIOR" CatShort = "AERO" CategoryFull = "AIRCRAFT-INTERIOR" end
  if CatID == "AEROMech" then Category = "AIRCRAFT" SubCategory = "MECHANISM" CatShort = "AERO" CategoryFull = "AIRCRAFT-MECHANISM" end
  if CatID == "AEROMil" then Category = "AIRCRAFT" SubCategory = "MILITARY" CatShort = "AERO" CategoryFull = "AIRCRAFT-MILITARY" end
  if CatID == "AEROMisc" then Category = "AIRCRAFT" SubCategory = "MISC" CatShort = "AERO" CategoryFull = "AIRCRAFT-MISC" end
  if CatID == "AEROProp" then Category = "AIRCRAFT" SubCategory = "PROP" CatShort = "AERO" CategoryFull = "AIRCRAFT-PROP" end
  if CatID == "AERORadio" then Category = "AIRCRAFT" SubCategory = "RADIO CONTROLLED" CatShort = "AERO" CategoryFull = "AIRCRAFT-RADIO CONTROLLED" end
  if CatID == "AERORckt" then Category = "AIRCRAFT" SubCategory = "ROCKET" CatShort = "AERO" CategoryFull = "AIRCRAFT-ROCKET" end
  if CatID == "ALRMBell" then Category = "ALARMS" SubCategory = "BELL" CatShort = "ALRM" CategoryFull = "ALARMS-BELL" end
  if CatID == "ALRMBuzr" then Category = "ALARMS" SubCategory = "BUZZER" CatShort = "ALRM" CategoryFull = "ALARMS-BUZZER" end
  if CatID == "ALRMClok" then Category = "ALARMS" SubCategory = "CLOCK" CatShort = "ALRM" CategoryFull = "ALARMS-CLOCK" end
  if CatID == "ALRMElec" then Category = "ALARMS" SubCategory = "ELECTRONIC" CatShort = "ALRM" CategoryFull = "ALARMS-ELECTRONIC" end
  if CatID == "ALRMMisc" then Category = "ALARMS" SubCategory = "MISC" CatShort = "ALRM" CategoryFull = "ALARMS-MISC" end
  if CatID == "ALRMSirn" then Category = "ALARMS" SubCategory = "SIREN" CatShort = "ALRM" CategoryFull = "ALARMS-SIREN" end
  if CatID == "AMBAir" then Category = "AMBIENCE" SubCategory = "AIR" CatShort = "AMB" CategoryFull = "AMBIENCE-AIR" end
  if CatID == "AMBAlpn" then Category = "AMBIENCE" SubCategory = "ALPINE" CatShort = "AMB" CategoryFull = "AMBIENCE-ALPINE" end
  if CatID == "AMBAmus" then Category = "AMBIENCE" SubCategory = "AMUSEMENT" CatShort = "AMB" CategoryFull = "AMBIENCE-AMUSEMENT" end
  if CatID == "AMBBird" then Category = "AMBIENCE" SubCategory = "BIRDSONG" CatShort = "AMB" CategoryFull = "AMBIENCE-BIRDSONG" end
  if CatID == "AMBCele" then Category = "AMBIENCE" SubCategory = "CELEBRATION" CatShort = "AMB" CategoryFull = "AMBIENCE-CELEBRATION" end
  if CatID == "AMBCnst" then Category = "AMBIENCE" SubCategory = "CONSTRUCTION" CatShort = "AMB" CategoryFull = "AMBIENCE-CONSTRUCTION" end
  if CatID == "AMBDsrt" then Category = "AMBIENCE" SubCategory = "DESERT" CatShort = "AMB" CategoryFull = "AMBIENCE-DESERT" end
  if CatID == "AMBDsgn" then Category = "AMBIENCE" SubCategory = "DESIGNED" CatShort = "AMB" CategoryFull = "AMBIENCE-DESIGNED" end
  if CatID == "AMBEmrg" then Category = "AMBIENCE" SubCategory = "EMERGENCY" CatShort = "AMB" CategoryFull = "AMBIENCE-EMERGENCY" end
  if CatID == "AMBFarm" then Category = "AMBIENCE" SubCategory = "FARM" CatShort = "AMB" CategoryFull = "AMBIENCE-FARM" end
  if CatID == "AMBForst" then Category = "AMBIENCE" SubCategory = "FOREST" CatShort = "AMB" CategoryFull = "AMBIENCE-FOREST" end
  if CatID == "AMBGras" then Category = "AMBIENCE" SubCategory = "GRASSLAND" CatShort = "AMB" CategoryFull = "AMBIENCE-GRASSLAND" end
  if CatID == "AMBHist" then Category = "AMBIENCE" SubCategory = "HISTORICAL" CatShort = "AMB" CategoryFull = "AMBIENCE-HISTORICAL" end
  if CatID == "AMBTech" then Category = "AMBIENCE" SubCategory = "HITECH" CatShort = "AMB" CategoryFull = "AMBIENCE-HITECH" end
  if CatID == "AMBHosp" then Category = "AMBIENCE" SubCategory = "HOSPITAL" CatShort = "AMB" CategoryFull = "AMBIENCE-HOSPITAL" end
  if CatID == "AMBInd" then Category = "AMBIENCE" SubCategory = "INDUSTRIAL" CatShort = "AMB" CategoryFull = "AMBIENCE-INDUSTRIAL" end
  if CatID == "AMBLake" then Category = "AMBIENCE" SubCategory = "LAKESIDE" CatShort = "AMB" CategoryFull = "AMBIENCE-LAKESIDE" end
  if CatID == "AMBMrkt" then Category = "AMBIENCE" SubCategory = "MARKET" CatShort = "AMB" CategoryFull = "AMBIENCE-MARKET" end
  if CatID == "AMBMisc" then Category = "AMBIENCE" SubCategory = "MISC" CatShort = "AMB" CategoryFull = "AMBIENCE-MISC" end
  if CatID == "AMBNaut" then Category = "AMBIENCE" SubCategory = "NAUTICAL" CatShort = "AMB" CategoryFull = "AMBIENCE-NAUTICAL" end
  if CatID == "AMBOffc" then Category = "AMBIENCE" SubCategory = "OFFICE" CatShort = "AMB" CategoryFull = "AMBIENCE-OFFICE" end
  if CatID == "AMBPark" then Category = "AMBIENCE" SubCategory = "PARK" CatShort = "AMB" CategoryFull = "AMBIENCE-PARK" end
  if CatID == "AMBPrisn" then Category = "AMBIENCE" SubCategory = "PRISON" CatShort = "AMB" CategoryFull = "AMBIENCE-PRISON" end
  if CatID == "AMBPrtst" then Category = "AMBIENCE" SubCategory = "PROTEST" CatShort = "AMB" CategoryFull = "AMBIENCE-PROTEST" end
  if CatID == "AMBPubl" then Category = "AMBIENCE" SubCategory = "PUBLIC PLACE" CatShort = "AMB" CategoryFull = "AMBIENCE-PUBLIC PLACE" end
  if CatID == "AMBRlgn" then Category = "AMBIENCE" SubCategory = "RELIGIOUS" CatShort = "AMB" CategoryFull = "AMBIENCE-RELIGIOUS" end
  if CatID == "AMBRest" then Category = "AMBIENCE" SubCategory = "RESTAURANT & BAR" CatShort = "AMB" CategoryFull = "AMBIENCE-RESTAURANT & BAR" end
  if CatID == "AMBRoom" then Category = "AMBIENCE" SubCategory = "ROOM TONE" CatShort = "AMB" CategoryFull = "AMBIENCE-ROOM TONE" end
  if CatID == "AMBRurl" then Category = "AMBIENCE" SubCategory = "RURAL" CatShort = "AMB" CategoryFull = "AMBIENCE-RURAL" end
  if CatID == "AMBSchl" then Category = "AMBIENCE" SubCategory = "SCHOOL" CatShort = "AMB" CategoryFull = "AMBIENCE-SCHOOL" end
  if CatID == "AMBSea" then Category = "AMBIENCE" SubCategory = "SEASIDE" CatShort = "AMB" CategoryFull = "AMBIENCE-SEASIDE" end
  if CatID == "AMBSprt" then Category = "AMBIENCE" SubCategory = "SPORT" CatShort = "AMB" CategoryFull = "AMBIENCE-SPORT" end
  if CatID == "AMBSubn" then Category = "AMBIENCE" SubCategory = "SUBURBAN" CatShort = "AMB" CategoryFull = "AMBIENCE-SUBURBAN" end
  if CatID == "AMBSwmp" then Category = "AMBIENCE" SubCategory = "SWAMP" CatShort = "AMB" CategoryFull = "AMBIENCE-SWAMP" end
  if CatID == "AMBTraf" then Category = "AMBIENCE" SubCategory = "TRAFFIC" CatShort = "AMB" CategoryFull = "AMBIENCE-TRAFFIC" end
  if CatID == "AMBTran" then Category = "AMBIENCE" SubCategory = "TRANSPORTATION" CatShort = "AMB" CategoryFull = "AMBIENCE-TRANSPORTATION" end
  if CatID == "AMBTndra" then Category = "AMBIENCE" SubCategory = "TUNDRA" CatShort = "AMB" CategoryFull = "AMBIENCE-TUNDRA" end
  if CatID == "AMBUndr" then Category = "AMBIENCE" SubCategory = "UNDERGROUND" CatShort = "AMB" CategoryFull = "AMBIENCE-UNDERGROUND" end
  if CatID == "AMBUndwtr" then Category = "AMBIENCE" SubCategory = "UNDERWATER" CatShort = "AMB" CategoryFull = "AMBIENCE-UNDERWATER" end
  if CatID == "AMBUrbn" then Category = "AMBIENCE" SubCategory = "URBAN" CatShort = "AMB" CategoryFull = "AMBIENCE-URBAN" end
  if CatID == "AMBWar" then Category = "AMBIENCE" SubCategory = "WARFARE" CatShort = "AMB" CategoryFull = "AMBIENCE-WARFARE" end
  if CatID == "ANMLAmph" then Category = "ANIMALS" SubCategory = "AMPHIBIAN" CatShort = "ANML" CategoryFull = "ANIMALS-AMPHIBIAN" end
  if CatID == "ANMLAqua" then Category = "ANIMALS" SubCategory = "AQUATIC" CatShort = "ANML" CategoryFull = "ANIMALS-AQUATIC" end
  if CatID == "ANMLBat" then Category = "ANIMALS" SubCategory = "BAT" CatShort = "ANML" CategoryFull = "ANIMALS-BAT" end
  if CatID == "ANMLCat" then Category = "ANIMALS" SubCategory = "CAT DOMESTIC" CatShort = "ANML" CategoryFull = "ANIMALS-CAT DOMESTIC" end
  if CatID == "ANMLWcat" then Category = "ANIMALS" SubCategory = "CAT WILD" CatShort = "ANML" CategoryFull = "ANIMALS-CAT WILD" end
  if CatID == "ANMLDog" then Category = "ANIMALS" SubCategory = "DOG" CatShort = "ANML" CategoryFull = "ANIMALS-DOG" end
  if CatID == "ANMLFarm" then Category = "ANIMALS" SubCategory = "FARM" CatShort = "ANML" CategoryFull = "ANIMALS-FARM" end
  if CatID == "ANMLHors" then Category = "ANIMALS" SubCategory = "HORSE" CatShort = "ANML" CategoryFull = "ANIMALS-HORSE" end
  if CatID == "ANMLInsc" then Category = "ANIMALS" SubCategory = "INSECT" CatShort = "ANML" CategoryFull = "ANIMALS-INSECT" end
  if CatID == "ANMLMisc" then Category = "ANIMALS" SubCategory = "MISC" CatShort = "ANML" CategoryFull = "ANIMALS-MISC" end
  if CatID == "ANMLPrim" then Category = "ANIMALS" SubCategory = "PRIMATE" CatShort = "ANML" CategoryFull = "ANIMALS-PRIMATE" end
  if CatID == "ANMLRept" then Category = "ANIMALS" SubCategory = "REPTILE" CatShort = "ANML" CategoryFull = "ANIMALS-REPTILE" end
  if CatID == "ANMLRdnt" then Category = "ANIMALS" SubCategory = "RODENT" CatShort = "ANML" CategoryFull = "ANIMALS-RODENT" end
  if CatID == "ANMLWild" then Category = "ANIMALS" SubCategory = "WILD" CatShort = "ANML" CategoryFull = "ANIMALS-WILD" end
  if CatID == "ASSET" then Category = "ARCHIVED" SubCategory = "ASSET" CatShort = "ASSET" CategoryFull = "ARCHIVED-ASSET" end
  if CatID == "BNCE" then Category = "ARCHIVED" SubCategory = "BOUNCE" CatShort = "BNCE" CategoryFull = "ARCHIVED-BOUNCE" end
  if CatID == "IR" then Category = "ARCHIVED" SubCategory = "IMPULSE RESPONSE" CatShort = "IR" CategoryFull = "ARCHIVED-IMPULSE RESPONSE" end
  if CatID == "MIX" then Category = "ARCHIVED" SubCategory = "MIX" CatShort = "MIX" CategoryFull = "ARCHIVED-MIX" end
  if CatID == "PFX" then Category = "ARCHIVED" SubCategory = "PFX" CatShort = "PFX" CategoryFull = "ARCHIVED-PFX" end
  if CatID == "RAW" then Category = "ARCHIVED" SubCategory = "RAW" CatShort = "RAW" CategoryFull = "ARCHIVED-RAW" end
  if CatID == "REF" then Category = "ARCHIVED" SubCategory = "REFERENCE" CatShort = "REF" CategoryFull = "ARCHIVED-REFERENCE" end
  if CatID == "SCNE" then Category = "ARCHIVED" SubCategory = "SCENE" CatShort = "SCNE" CategoryFull = "ARCHIVED-SCENE" end
  if CatID == "TEST" then Category = "ARCHIVED" SubCategory = "TEST TONE" CatShort = "TEST" CategoryFull = "ARCHIVED-TEST TONE" end
  if CatID == "TMARK" then Category = "ARCHIVED" SubCategory = "TRADEMARKED" CatShort = "TMARK" CategoryFull = "ARCHIVED-TRADEMARKED" end
  if CatID == "WIP" then Category = "ARCHIVED" SubCategory = "WORK IN PROGRESS" CatShort = "WIP" CategoryFull = "ARCHIVED-WORK IN PROGRESS" end
  if CatID == "WTF" then Category = "ARCHIVED" SubCategory = "WTF" CatShort = "WTF" CategoryFull = "ARCHIVED-WTF" end
  if CatID == "BEEPAppl" then Category = "BEEPS" SubCategory = "APPLIANCE" CatShort = "BEEP" CategoryFull = "BEEPS-APPLIANCE" end
  if CatID == "BEEP" then Category = "BEEPS" SubCategory = "GENERAL" CatShort = "BEEP" CategoryFull = "BEEPS-GENERAL" end
  if CatID == "BEEPLofi" then Category = "BEEPS" SubCategory = "LOFI" CatShort = "BEEP" CategoryFull = "BEEPS-LOFI" end
  if CatID == "BEEPMed" then Category = "BEEPS" SubCategory = "MEDICAL" CatShort = "BEEP" CategoryFull = "BEEPS-MEDICAL" end
  if CatID == "BEEPTimer" then Category = "BEEPS" SubCategory = "TIMER" CatShort = "BEEP" CategoryFull = "BEEPS-TIMER" end
  if CatID == "BEEPVeh" then Category = "BEEPS" SubCategory = "VEHICLE" CatShort = "BEEP" CategoryFull = "BEEPS-VEHICLE" end
  if CatID == "BELLAnml" then Category = "BELLS" SubCategory = "ANIMAL" CatShort = "BELL" CategoryFull = "BELLS-ANIMAL" end
  if CatID == "BELLDoor" then Category = "BELLS" SubCategory = "DOORBELL" CatShort = "BELL" CategoryFull = "BELLS-DOORBELL" end
  if CatID == "BELLGong" then Category = "BELLS" SubCategory = "GONG" CatShort = "BELL" CategoryFull = "BELLS-GONG" end
  if CatID == "BELLHand" then Category = "BELLS" SubCategory = "HANDBELL" CatShort = "BELL" CategoryFull = "BELLS-HANDBELL" end
  if CatID == "BELLLrg" then Category = "BELLS" SubCategory = "LARGE" CatShort = "BELL" CategoryFull = "BELLS-LARGE" end
  if CatID == "BELLMisc" then Category = "BELLS" SubCategory = "MISC" CatShort = "BELL" CategoryFull = "BELLS-MISC" end
  if CatID == "BIRDPrey" then Category = "BIRDS" SubCategory = "BIRD OF PREY" CatShort = "BIRD" CategoryFull = "BIRDS-BIRD OF PREY" end
  if CatID == "BIRDCrow" then Category = "BIRDS" SubCategory = "CROW" CatShort = "BIRD" CategoryFull = "BIRDS-CROW" end
  if CatID == "BIRDFowl" then Category = "BIRDS" SubCategory = "FOWL" CatShort = "BIRD" CategoryFull = "BIRDS-FOWL" end
  if CatID == "BIRDMisc" then Category = "BIRDS" SubCategory = "MISC" CatShort = "BIRD" CategoryFull = "BIRDS-MISC" end
  if CatID == "BIRDSea" then Category = "BIRDS" SubCategory = "SEA" CatShort = "BIRD" CategoryFull = "BIRDS-SEA" end
  if CatID == "BIRDSong" then Category = "BIRDS" SubCategory = "SONGBIRD" CatShort = "BIRD" CategoryFull = "BIRDS-SONGBIRD" end
  if CatID == "BIRDTrop" then Category = "BIRDS" SubCategory = "TROPICAL" CatShort = "BIRD" CategoryFull = "BIRDS-TROPICAL" end
  if CatID == "BIRDWade" then Category = "BIRDS" SubCategory = "WADING" CatShort = "BIRD" CategoryFull = "BIRDS-WADING" end
  if CatID == "BOATAir" then Category = "BOATS" SubCategory = "AIR BOAT" CatShort = "BOAT" CategoryFull = "BOATS-AIR BOAT" end
  if CatID == "BOATWash" then Category = "BOATS" SubCategory = "BOW WASH" CatShort = "BOAT" CategoryFull = "BOATS-BOW WASH" end
  if CatID == "BOATElec" then Category = "BOATS" SubCategory = "ELECTRIC" CatShort = "BOAT" CategoryFull = "BOATS-ELECTRIC" end
  if CatID == "BOATFish" then Category = "BOATS" SubCategory = "FISHING" CatShort = "BOAT" CategoryFull = "BOATS-FISHING" end
  if CatID == "BOATHorn" then Category = "BOATS" SubCategory = "HORN" CatShort = "BOAT" CategoryFull = "BOATS-HORN" end
  if CatID == "BOATInt" then Category = "BOATS" SubCategory = "INTERIOR" CatShort = "BOAT" CategoryFull = "BOATS-INTERIOR" end
  if CatID == "BOATMech" then Category = "BOATS" SubCategory = "MECHANISM" CatShort = "BOAT" CategoryFull = "BOATS-MECHANISM" end
  if CatID == "BOATMil" then Category = "BOATS" SubCategory = "MILITARY" CatShort = "BOAT" CategoryFull = "BOATS-MILITARY" end
  if CatID == "BOATMisc" then Category = "BOATS" SubCategory = "MISC" CatShort = "BOAT" CategoryFull = "BOATS-MISC" end
  if CatID == "BOATMotr" then Category = "BOATS" SubCategory = "MOTORBOAT" CatShort = "BOAT" CategoryFull = "BOATS-MOTORBOAT" end
  if CatID == "BOATRace" then Category = "BOATS" SubCategory = "RACING" CatShort = "BOAT" CategoryFull = "BOATS-RACING" end
  if CatID == "BOATRow" then Category = "BOATS" SubCategory = "ROWBOAT" CatShort = "BOAT" CategoryFull = "BOATS-ROWBOAT" end
  if CatID == "BOATSail" then Category = "BOATS" SubCategory = "SAILBOAT" CatShort = "BOAT" CategoryFull = "BOATS-SAILBOAT" end
  if CatID == "BOATShip" then Category = "BOATS" SubCategory = "SHIP" CatShort = "BOAT" CategoryFull = "BOATS-SHIP" end
  if CatID == "BOATStm" then Category = "BOATS" SubCategory = "STEAM" CatShort = "BOAT" CategoryFull = "BOATS-STEAM" end
  if CatID == "BOATSub" then Category = "BOATS" SubCategory = "SUBMARINE" CatShort = "BOAT" CategoryFull = "BOATS-SUBMARINE" end
  if CatID == "BLLTBy" then Category = "BULLETS" SubCategory = "BY" CatShort = "BLLT" CategoryFull = "BULLETS-BY" end
  if CatID == "BLLTImpt" then Category = "BULLETS" SubCategory = "IMPACT" CatShort = "BLLT" CategoryFull = "BULLETS-IMPACT" end
  if CatID == "BLLTMisc" then Category = "BULLETS" SubCategory = "MISC" CatShort = "BLLT" CategoryFull = "BULLETS-MISC" end
  if CatID == "BLLTRico" then Category = "BULLETS" SubCategory = "RICOCHET" CatShort = "BLLT" CategoryFull = "BULLETS-RICOCHET" end
  if CatID == "BLLTShel" then Category = "BULLETS" SubCategory = "SHELL" CatShort = "BLLT" CategoryFull = "BULLETS-SHELL" end
  if CatID == "TOONBoing" then Category = "CARTOON" SubCategory = "BOING" CatShort = "TOON" CategoryFull = "CARTOON-BOING" end
  if CatID == "TOONClang" then Category = "CARTOON" SubCategory = "CLANG" CatShort = "TOON" CategoryFull = "CARTOON-CLANG" end
  if CatID == "TOONCreak" then Category = "CARTOON" SubCategory = "CREAK" CatShort = "TOON" CategoryFull = "CARTOON-CREAK" end
  if CatID == "TOONHorn" then Category = "CARTOON" SubCategory = "HORN" CatShort = "TOON" CategoryFull = "CARTOON-HORN" end
  if CatID == "TOONImpt" then Category = "CARTOON" SubCategory = "IMPACT" CatShort = "TOON" CategoryFull = "CARTOON-IMPACT" end
  if CatID == "TOONMisc" then Category = "CARTOON" SubCategory = "MISC" CatShort = "TOON" CategoryFull = "CARTOON-MISC" end
  if CatID == "TOONMx" then Category = "CARTOON" SubCategory = "MUSICAL" CatShort = "TOON" CategoryFull = "CARTOON-MUSICAL" end
  if CatID == "TOONPluk" then Category = "CARTOON" SubCategory = "PLUCK" CatShort = "TOON" CategoryFull = "CARTOON-PLUCK" end
  if CatID == "TOONPop" then Category = "CARTOON" SubCategory = "POP" CatShort = "TOON" CategoryFull = "CARTOON-POP" end
  if CatID == "TOONShake" then Category = "CARTOON" SubCategory = "SHAKE" CatShort = "TOON" CategoryFull = "CARTOON-SHAKE" end
  if CatID == "TOONSplt" then Category = "CARTOON" SubCategory = "SPLAT" CatShort = "TOON" CategoryFull = "CARTOON-SPLAT" end
  if CatID == "TOONSqk" then Category = "CARTOON" SubCategory = "SQUEAK" CatShort = "TOON" CategoryFull = "CARTOON-SQUEAK" end
  if CatID == "TOONStrch" then Category = "CARTOON" SubCategory = "STRETCH" CatShort = "TOON" CategoryFull = "CARTOON-STRETCH" end
  if CatID == "TOONSwsh" then Category = "CARTOON" SubCategory = "SWISH" CatShort = "TOON" CategoryFull = "CARTOON-SWISH" end
  if CatID == "TOONTwang" then Category = "CARTOON" SubCategory = "TWANG" CatShort = "TOON" CategoryFull = "CARTOON-TWANG" end
  if CatID == "TOONWarb" then Category = "CARTOON" SubCategory = "WARBLE" CatShort = "TOON" CategoryFull = "CARTOON-WARBLE" end
  if CatID == "TOONWhis" then Category = "CARTOON" SubCategory = "WHISTLE" CatShort = "TOON" CategoryFull = "CARTOON-WHISTLE" end
  if CatID == "TOONZip" then Category = "CARTOON" SubCategory = "ZIP" CatShort = "TOON" CategoryFull = "CARTOON-ZIP" end
  if CatID == "CERMBrk" then Category = "CERAMICS" SubCategory = "BREAK" CatShort = "CERM" CategoryFull = "CERAMICS-BREAK" end
  if CatID == "CERMCrsh" then Category = "CERAMICS" SubCategory = "CRASH & DEBRIS" CatShort = "CERM" CategoryFull = "CERAMICS-CRASH & DEBRIS" end
  if CatID == "CERMFric" then Category = "CERAMICS" SubCategory = "FRICTION" CatShort = "CERM" CategoryFull = "CERAMICS-FRICTION" end
  if CatID == "CERMImpt" then Category = "CERAMICS" SubCategory = "IMPACT" CatShort = "CERM" CategoryFull = "CERAMICS-IMPACT" end
  if CatID == "CERMMisc" then Category = "CERAMICS" SubCategory = "MISC" CatShort = "CERM" CategoryFull = "CERAMICS-MISC" end
  if CatID == "CERMMvmt" then Category = "CERAMICS" SubCategory = "MOVEMENT" CatShort = "CERM" CategoryFull = "CERAMICS-MOVEMENT" end
  if CatID == "CERMTonl" then Category = "CERAMICS" SubCategory = "TONAL" CatShort = "CERM" CategoryFull = "CERAMICS-TONAL" end
  if CatID == "CHAINBrk" then Category = "CHAINS" SubCategory = "BREAK" CatShort = "CHAIN" CategoryFull = "CHAINS-BREAK" end
  if CatID == "CHAINImpt" then Category = "CHAINS" SubCategory = "IMPACT" CatShort = "CHAIN" CategoryFull = "CHAINS-IMPACT" end
  if CatID == "CHAINMisc" then Category = "CHAINS" SubCategory = "MISC" CatShort = "CHAIN" CategoryFull = "CHAINS-MISC" end
  if CatID == "CHAINMvmt" then Category = "CHAINS" SubCategory = "MOVEMENT" CatShort = "CHAIN" CategoryFull = "CHAINS-MOVEMENT" end
  if CatID == "CHEMAcid" then Category = "CHEMICALS" SubCategory = "ACID" CatShort = "CHEM" CategoryFull = "CHEMICALS-ACID" end
  if CatID == "CHEMMisc" then Category = "CHEMICALS" SubCategory = "MISC" CatShort = "CHEM" CategoryFull = "CHEMICALS-MISC" end
  if CatID == "CHEMReac" then Category = "CHEMICALS" SubCategory = "REACTION" CatShort = "CHEM" CategoryFull = "CHEMICALS-REACTION" end
  if CatID == "CLOCKChim" then Category = "CLOCKS" SubCategory = "CHIME" CatShort = "CLOCK" CategoryFull = "CLOCKS-CHIME" end
  if CatID == "CLOCKMech" then Category = "CLOCKS" SubCategory = "MECHANICS" CatShort = "CLOCK" CategoryFull = "CLOCKS-MECHANICS" end
  if CatID == "CLOCKMisc" then Category = "CLOCKS" SubCategory = "MISC" CatShort = "CLOCK" CategoryFull = "CLOCKS-MISC" end
  if CatID == "CLOCKTick" then Category = "CLOCKS" SubCategory = "TICK" CatShort = "CLOCK" CategoryFull = "CLOCKS-TICK" end
  if CatID == "CLOTHFlp" then Category = "CLOTH" SubCategory = "FLAP" CatShort = "CLOTH" CategoryFull = "CLOTH-FLAP" end
  if CatID == "CLOTHMisc" then Category = "CLOTH" SubCategory = "MISC" CatShort = "CLOTH" CategoryFull = "CLOTH-MISC" end
  if CatID == "CLOTHMvmt" then Category = "CLOTH" SubCategory = "MOVEMENT" CatShort = "CLOTH" CategoryFull = "CLOTH-MOVEMENT" end
  if CatID == "CLOTHRip" then Category = "CLOTH" SubCategory = "RIP" CatShort = "CLOTH" CategoryFull = "CLOTH-RIP" end
  if CatID == "COMAv" then Category = "COMMUNICATIONS" SubCategory = "AUDIO VISUAL" CatShort = "COM" CategoryFull = "COMMUNICATIONS-AUDIO VISUAL" end
  if CatID == "COMCam" then Category = "COMMUNICATIONS" SubCategory = "CAMERA" CatShort = "COM" CategoryFull = "COMMUNICATIONS-CAMERA" end
  if CatID == "COMCell" then Category = "COMMUNICATIONS" SubCategory = "CELLPHONE" CatShort = "COM" CategoryFull = "COMMUNICATIONS-CELLPHONE" end
  if CatID == "COMMic" then Category = "COMMUNICATIONS" SubCategory = "MICROPHONE" CatShort = "COM" CategoryFull = "COMMUNICATIONS-MICROPHONE" end
  if CatID == "COMMisc" then Category = "COMMUNICATIONS" SubCategory = "MISC" CatShort = "COM" CategoryFull = "COMMUNICATIONS-MISC" end
  if CatID == "COMPhono" then Category = "COMMUNICATIONS" SubCategory = "PHONOGRAPH" CatShort = "COM" CategoryFull = "COMMUNICATIONS-PHONOGRAPH" end
  if CatID == "COMRadio" then Category = "COMMUNICATIONS" SubCategory = "RADIO" CatShort = "COM" CategoryFull = "COMMUNICATIONS-RADIO" end
  if CatID == "COMStatic" then Category = "COMMUNICATIONS" SubCategory = "STATIC" CatShort = "COM" CategoryFull = "COMMUNICATIONS-STATIC" end
  if CatID == "COMTelm" then Category = "COMMUNICATIONS" SubCategory = "TELEMETRY" CatShort = "COM" CategoryFull = "COMMUNICATIONS-TELEMETRY" end
  if CatID == "COMTelph" then Category = "COMMUNICATIONS" SubCategory = "TELEPHONE" CatShort = "COM" CategoryFull = "COMMUNICATIONS-TELEPHONE" end
  if CatID == "COMTv" then Category = "COMMUNICATIONS" SubCategory = "TELEVISION" CatShort = "COM" CategoryFull = "COMMUNICATIONS-TELEVISION" end
  if CatID == "COMTran" then Category = "COMMUNICATIONS" SubCategory = "TRANSCEIVER" CatShort = "COM" CategoryFull = "COMMUNICATIONS-TRANSCEIVER" end
  if CatID == "COMType" then Category = "COMMUNICATIONS" SubCategory = "TYPEWRITER" CatShort = "COM" CategoryFull = "COMMUNICATIONS-TYPEWRITER" end
  if CatID == "CMPTDriv" then Category = "COMPUTERS" SubCategory = "HARD DRIVE" CatShort = "CMPT" CategoryFull = "COMPUTERS-HARD DRIVE" end
  if CatID == "CMPTKey" then Category = "COMPUTERS" SubCategory = "KEYBOARD & MOUSE" CatShort = "CMPT" CategoryFull = "COMPUTERS-KEYBOARD & MOUSE" end
  if CatID == "CMPTMisc" then Category = "COMPUTERS" SubCategory = "MISC" CatShort = "CMPT" CategoryFull = "COMPUTERS-MISC" end
  if CatID == "CREAAqua" then Category = "CREATURES" SubCategory = "AQUATIC" CatShort = "CREA" CategoryFull = "CREATURES-AQUATIC" end
  if CatID == "CREAAvian" then Category = "CREATURES" SubCategory = "AVIAN" CatShort = "CREA" CategoryFull = "CREATURES-AVIAN" end
  if CatID == "CREABeast" then Category = "CREATURES" SubCategory = "BEAST" CatShort = "CREA" CategoryFull = "CREATURES-BEAST" end
  if CatID == "CREABlob" then Category = "CREATURES" SubCategory = "BLOB" CatShort = "CREA" CategoryFull = "CREATURES-BLOB" end
  if CatID == "CREADino" then Category = "CREATURES" SubCategory = "DINOSAUR" CatShort = "CREA" CategoryFull = "CREATURES-DINOSAUR" end
  if CatID == "CREADrgn" then Category = "CREATURES" SubCategory = "DRAGON" CatShort = "CREA" CategoryFull = "CREATURES-DRAGON" end
  if CatID == "CREAElem" then Category = "CREATURES" SubCategory = "ELEMENTAL" CatShort = "CREA" CategoryFull = "CREATURES-ELEMENTAL" end
  if CatID == "CREAEthr" then Category = "CREATURES" SubCategory = "ETHEREAL" CatShort = "CREA" CategoryFull = "CREATURES-ETHEREAL" end
  if CatID == "CREAHmn" then Category = "CREATURES" SubCategory = "HUMANOID" CatShort = "CREA" CategoryFull = "CREATURES-HUMANOID" end
  if CatID == "CREAInsc" then Category = "CREATURES" SubCategory = "INSECTOID" CatShort = "CREA" CategoryFull = "CREATURES-INSECTOID" end
  if CatID == "CREAMisc" then Category = "CREATURES" SubCategory = "MISC" CatShort = "CREA" CategoryFull = "CREATURES-MISC" end
  if CatID == "CREAMnstr" then Category = "CREATURES" SubCategory = "MONSTER" CatShort = "CREA" CategoryFull = "CREATURES-MONSTER" end
  if CatID == "CREARept" then Category = "CREATURES" SubCategory = "REPTILIAN" CatShort = "CREA" CategoryFull = "CREATURES-REPTILIAN" end
  if CatID == "CREASmall" then Category = "CREATURES" SubCategory = "SMALL" CatShort = "CREA" CategoryFull = "CREATURES-SMALL" end
  if CatID == "CREASrce" then Category = "CREATURES" SubCategory = "SOURCE" CatShort = "CREA" CategoryFull = "CREATURES-SOURCE" end
  if CatID == "CRWDAngr" then Category = "CROWDS" SubCategory = "ANGRY" CatShort = "CRWD" CategoryFull = "CROWDS-ANGRY" end
  if CatID == "CRWDApls" then Category = "CROWDS" SubCategory = "APPLAUSE" CatShort = "CRWD" CategoryFull = "CROWDS-APPLAUSE" end
  if CatID == "CRWDBatl" then Category = "CROWDS" SubCategory = "BATTLE" CatShort = "CRWD" CategoryFull = "CROWDS-BATTLE" end
  if CatID == "CRWDCele" then Category = "CROWDS" SubCategory = "CELEBRATION" CatShort = "CRWD" CategoryFull = "CROWDS-CELEBRATION" end
  if CatID == "CRWDCheer" then Category = "CROWDS" SubCategory = "CHEERING" CatShort = "CRWD" CategoryFull = "CROWDS-CHEERING" end
  if CatID == "CRWDChld" then Category = "CROWDS" SubCategory = "CHILDREN" CatShort = "CRWD" CategoryFull = "CROWDS-CHILDREN" end
  if CatID == "CRWDConv" then Category = "CROWDS" SubCategory = "CONVERSATION" CatShort = "CRWD" CategoryFull = "CROWDS-CONVERSATION" end
  if CatID == "CRWDLaff" then Category = "CROWDS" SubCategory = "LAUGHTER" CatShort = "CRWD" CategoryFull = "CROWDS-LAUGHTER" end
  if CatID == "CRWDLoop" then Category = "CROWDS" SubCategory = "LOOP GROUP" CatShort = "CRWD" CategoryFull = "CROWDS-LOOP GROUP" end
  if CatID == "CRWDMisc" then Category = "CROWDS" SubCategory = "MISC" CatShort = "CRWD" CategoryFull = "CROWDS-MISC" end
  if CatID == "CRWDPanic" then Category = "CROWDS" SubCategory = "PANIC" CatShort = "CRWD" CategoryFull = "CROWDS-PANIC" end
  if CatID == "CRWDQuiet" then Category = "CROWDS" SubCategory = "QUIET" CatShort = "CRWD" CategoryFull = "CROWDS-QUIET" end
  if CatID == "CRWDReac" then Category = "CROWDS" SubCategory = "REACTION" CatShort = "CRWD" CategoryFull = "CROWDS-REACTION" end
  if CatID == "CRWDSing" then Category = "CROWDS" SubCategory = "SINGING" CatShort = "CRWD" CategoryFull = "CROWDS-SINGING" end
  if CatID == "CRWDSprt" then Category = "CROWDS" SubCategory = "SPORT" CatShort = "CRWD" CategoryFull = "CROWDS-SPORT" end
  if CatID == "CRWDWalla" then Category = "CROWDS" SubCategory = "WALLA" CatShort = "CRWD" CategoryFull = "CROWDS-WALLA" end
  if CatID == "DSGNBass" then Category = "DESIGNED" SubCategory = "BASS DIVE" CatShort = "DSGN" CategoryFull = "DESIGNED-BASS DIVE" end
  if CatID == "DSGNBoom" then Category = "DESIGNED" SubCategory = "BOOM" CatShort = "DSGN" CategoryFull = "DESIGNED-BOOM" end
  if CatID == "DSGNBram" then Category = "DESIGNED" SubCategory = "BRAAM" CatShort = "DSGN" CategoryFull = "DESIGNED-BRAAM" end
  if CatID == "DSGNDist" then Category = "DESIGNED" SubCategory = "DISTORTION" CatShort = "DSGN" CategoryFull = "DESIGNED-DISTORTION" end
  if CatID == "DSGNDron" then Category = "DESIGNED" SubCategory = "DRONE" CatShort = "DSGN" CategoryFull = "DESIGNED-DRONE" end
  if CatID == "DSGNErie" then Category = "DESIGNED" SubCategory = "EERIE" CatShort = "DSGN" CategoryFull = "DESIGNED-EERIE" end
  if CatID == "DSGNMisc" then Category = "DESIGNED" SubCategory = "MISC" CatShort = "DSGN" CategoryFull = "DESIGNED-MISC" end
  if CatID == "DSGNRise" then Category = "DESIGNED" SubCategory = "RISER" CatShort = "DSGN" CategoryFull = "DESIGNED-RISER" end
  if CatID == "DSGNRmbl" then Category = "DESIGNED" SubCategory = "RUMBLE" CatShort = "DSGN" CategoryFull = "DESIGNED-RUMBLE" end
  if CatID == "DSGNSrce" then Category = "DESIGNED" SubCategory = "SOURCE" CatShort = "DSGN" CategoryFull = "DESIGNED-SOURCE" end
  if CatID == "DSGNStngr" then Category = "DESIGNED" SubCategory = "STINGER" CatShort = "DSGN" CategoryFull = "DESIGNED-STINGER" end
  if CatID == "DSGNSynth" then Category = "DESIGNED" SubCategory = "SYNTHETIC" CatShort = "DSGN" CategoryFull = "DESIGNED-SYNTHETIC" end
  if CatID == "DSGNTonl" then Category = "DESIGNED" SubCategory = "TONAL" CatShort = "DSGN" CategoryFull = "DESIGNED-TONAL" end
  if CatID == "DSGNVocl" then Category = "DESIGNED" SubCategory = "VOCAL" CatShort = "DSGN" CategoryFull = "DESIGNED-VOCAL" end
  if CatID == "DESTRClpse" then Category = "DESTRUCTION" SubCategory = "COLLAPSE" CatShort = "DESTR" CategoryFull = "DESTRUCTION-COLLAPSE" end
  if CatID == "DESTRCrsh" then Category = "DESTRUCTION" SubCategory = "CRASH & DEBRIS" CatShort = "DESTR" CategoryFull = "DESTRUCTION-CRASH & DEBRIS" end
  if CatID == "DESTRMisc" then Category = "DESTRUCTION" SubCategory = "MISC" CatShort = "DESTR" CategoryFull = "DESTRUCTION-MISC" end
  if CatID == "DIRTCrsh" then Category = "DIRT & SAND" SubCategory = "CRASH & DEBRIS" CatShort = "DIRT" CategoryFull = "DIRT & SAND-CRASH & DEBRIS" end
  if CatID == "DIRTDust" then Category = "DIRT & SAND" SubCategory = "DUST" CatShort = "DIRT" CategoryFull = "DIRT & SAND-DUST" end
  if CatID == "DIRTImpt" then Category = "DIRT & SAND" SubCategory = "IMPACT" CatShort = "DIRT" CategoryFull = "DIRT & SAND-IMPACT" end
  if CatID == "DIRTMisc" then Category = "DIRT & SAND" SubCategory = "MISC" CatShort = "DIRT" CategoryFull = "DIRT & SAND-MISC" end
  if CatID == "DIRTMvmt" then Category = "DIRT & SAND" SubCategory = "MOVEMENT" CatShort = "DIRT" CategoryFull = "DIRT & SAND-MOVEMENT" end
  if CatID == "DOORAntq" then Category = "DOORS" SubCategory = "ANTIQUE" CatShort = "DOOR" CategoryFull = "DOORS-ANTIQUE" end
  if CatID == "DOORAppl" then Category = "DOORS" SubCategory = "APPLIANCE" CatShort = "DOOR" CategoryFull = "DOORS-APPLIANCE" end
  if CatID == "DOORCab" then Category = "DOORS" SubCategory = "CABINET" CatShort = "DOOR" CategoryFull = "DOORS-CABINET" end
  if CatID == "DOORCreak" then Category = "DOORS" SubCategory = "CREAK" CatShort = "DOOR" CategoryFull = "DOORS-CREAK" end
  if CatID == "DOORDungn" then Category = "DOORS" SubCategory = "DUNGEON" CatShort = "DOOR" CategoryFull = "DOORS-DUNGEON" end
  if CatID == "DOORElec" then Category = "DOORS" SubCategory = "ELECTRIC" CatShort = "DOOR" CategoryFull = "DOORS-ELECTRIC" end
  if CatID == "DOORGate" then Category = "DOORS" SubCategory = "GATE" CatShort = "DOOR" CategoryFull = "DOORS-GATE" end
  if CatID == "DOORGlas" then Category = "DOORS" SubCategory = "GLASS" CatShort = "DOOR" CategoryFull = "DOORS-GLASS" end
  if CatID == "DOORHdwr" then Category = "DOORS" SubCategory = "HARDWARE" CatShort = "DOOR" CategoryFull = "DOORS-HARDWARE" end
  if CatID == "DOORTech" then Category = "DOORS" SubCategory = "HITECH" CatShort = "DOOR" CategoryFull = "DOORS-HITECH" end
  if CatID == "DOORHydr" then Category = "DOORS" SubCategory = "HYDRAULIC & PNEUMATIC" CatShort = "DOOR" CategoryFull = "DOORS-HYDRAULIC & PNEUMATIC" end
  if CatID == "DOORKnck" then Category = "DOORS" SubCategory = "KNOCK" CatShort = "DOOR" CategoryFull = "DOORS-KNOCK" end
  if CatID == "DOORMetl" then Category = "DOORS" SubCategory = "METAL" CatShort = "DOOR" CategoryFull = "DOORS-METAL" end
  if CatID == "DOORMisc" then Category = "DOORS" SubCategory = "MISC" CatShort = "DOOR" CategoryFull = "DOORS-MISC" end
  if CatID == "DOORPlas" then Category = "DOORS" SubCategory = "PLASTIC" CatShort = "DOOR" CategoryFull = "DOORS-PLASTIC" end
  if CatID == "DOORPrisn" then Category = "DOORS" SubCategory = "PRISON" CatShort = "DOOR" CategoryFull = "DOORS-PRISON" end
  if CatID == "DOORRevl" then Category = "DOORS" SubCategory = "REVOLVING" CatShort = "DOOR" CategoryFull = "DOORS-REVOLVING" end
  if CatID == "DOORSlid" then Category = "DOORS" SubCategory = "SLIDING" CatShort = "DOOR" CategoryFull = "DOORS-SLIDING" end
  if CatID == "DOORSton" then Category = "DOORS" SubCategory = "STONE" CatShort = "DOOR" CategoryFull = "DOORS-STONE" end
  if CatID == "DOORSwng" then Category = "DOORS" SubCategory = "SWINGING" CatShort = "DOOR" CategoryFull = "DOORS-SWINGING" end
  if CatID == "DOORWood" then Category = "DOORS" SubCategory = "WOOD" CatShort = "DOOR" CategoryFull = "DOORS-WOOD" end
  if CatID == "DRWRMetl" then Category = "DRAWERS" SubCategory = "METAL" CatShort = "DRWR" CategoryFull = "DRAWERS-METAL" end
  if CatID == "DRWRMisc" then Category = "DRAWERS" SubCategory = "MISC" CatShort = "DRWR" CategoryFull = "DRAWERS-MISC" end
  if CatID == "DRWRPlas" then Category = "DRAWERS" SubCategory = "PLASTIC" CatShort = "DRWR" CategoryFull = "DRAWERS-PLASTIC" end
  if CatID == "DRWRWood" then Category = "DRAWERS" SubCategory = "WOOD" CatShort = "DRWR" CategoryFull = "DRAWERS-WOOD" end
  if CatID == "ELECArc" then Category = "ELECTRICITY" SubCategory = "ARC" CatShort = "ELEC" CategoryFull = "ELECTRICITY-ARC" end
  if CatID == "ELECBuzz" then Category = "ELECTRICITY" SubCategory = "BUZZ & HUM" CatShort = "ELEC" CategoryFull = "ELECTRICITY-BUZZ & HUM" end
  if CatID == "ELECEmf" then Category = "ELECTRICITY" SubCategory = "ELECTROMAGNETIC" CatShort = "ELEC" CategoryFull = "ELECTRICITY-ELECTROMAGNETIC" end
  if CatID == "ELECMisc" then Category = "ELECTRICITY" SubCategory = "MISC" CatShort = "ELEC" CategoryFull = "ELECTRICITY-MISC" end
  if CatID == "ELECSprk" then Category = "ELECTRICITY" SubCategory = "SPARKS" CatShort = "ELEC" CategoryFull = "ELECTRICITY-SPARKS" end
  if CatID == "ELECZap" then Category = "ELECTRICITY" SubCategory = "ZAP" CatShort = "ELEC" CategoryFull = "ELECTRICITY-ZAP" end
  if CatID == "EQUIPBridle" then Category = "EQUIPMENT" SubCategory = "BRIDLE & TACK" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-BRIDLE & TACK" end
  if CatID == "EQUIPTech" then Category = "EQUIPMENT" SubCategory = "HITECH" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-HITECH" end
  if CatID == "EQUIPMisc" then Category = "EQUIPMENT" SubCategory = "MISC" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-MISC" end
  if CatID == "EQUIPRec" then Category = "EQUIPMENT" SubCategory = "RECREATIONAL" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-RECREATIONAL" end
  if CatID == "EQUIPSprt" then Category = "EQUIPMENT" SubCategory = "SPORT" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-SPORT" end
  if CatID == "EQUIPTact" then Category = "EQUIPMENT" SubCategory = "TACTICAL" CatShort = "EQUIP" CategoryFull = "EQUIPMENT-TACTICAL" end
  if CatID == "EXPLDsgn" then Category = "EXPLOSIONS" SubCategory = "DESIGNED" CatShort = "EXPL" CategoryFull = "EXPLOSIONS-DESIGNED" end
  if CatID == "EXPLMisc" then Category = "EXPLOSIONS" SubCategory = "MISC" CatShort = "EXPL" CategoryFull = "EXPLOSIONS-MISC" end
  if CatID == "EXPLReal" then Category = "EXPLOSIONS" SubCategory = "REAL" CatShort = "EXPL" CategoryFull = "EXPLOSIONS-REAL" end
  if CatID == "FARTDsgn" then Category = "FARTS" SubCategory = "DESIGNED" CatShort = "FART" CategoryFull = "FARTS-DESIGNED" end
  if CatID == "FARTMisc" then Category = "FARTS" SubCategory = "MISC" CatShort = "FART" CategoryFull = "FARTS-MISC" end
  if CatID == "FARTReal" then Category = "FARTS" SubCategory = "REAL" CatShort = "FART" CategoryFull = "FARTS-REAL" end
  if CatID == "FGHTBf" then Category = "FIGHT" SubCategory = "BODYFALL" CatShort = "FGHT" CategoryFull = "FIGHT-BODYFALL" end
  if CatID == "FGHTClth" then Category = "FIGHT" SubCategory = "CLOTH" CatShort = "FGHT" CategoryFull = "FIGHT-CLOTH" end
  if CatID == "FGHTGrab" then Category = "FIGHT" SubCategory = "GRAB" CatShort = "FGHT" CategoryFull = "FIGHT-GRAB" end
  if CatID == "FGHTImpt" then Category = "FIGHT" SubCategory = "IMPACT" CatShort = "FGHT" CategoryFull = "FIGHT-IMPACT" end
  if CatID == "FGHTMisc" then Category = "FIGHT" SubCategory = "MISC" CatShort = "FGHT" CategoryFull = "FIGHT-MISC" end
  if CatID == "FIREBurn" then Category = "FIRE" SubCategory = "BURNING" CatShort = "FIRE" CategoryFull = "FIRE-BURNING" end
  if CatID == "FIREBrst" then Category = "FIRE" SubCategory = "BURST" CatShort = "FIRE" CategoryFull = "FIRE-BURST" end
  if CatID == "FIRECrkl" then Category = "FIRE" SubCategory = "CRACKLE" CatShort = "FIRE" CategoryFull = "FIRE-CRACKLE" end
  if CatID == "FIREGas" then Category = "FIRE" SubCategory = "GAS" CatShort = "FIRE" CategoryFull = "FIRE-GAS" end
  if CatID == "FIREIgn" then Category = "FIRE" SubCategory = "IGNITE" CatShort = "FIRE" CategoryFull = "FIRE-IGNITE" end
  if CatID == "FIREMisc" then Category = "FIRE" SubCategory = "MISC" CatShort = "FIRE" CategoryFull = "FIRE-MISC" end
  if CatID == "FIRESizz" then Category = "FIRE" SubCategory = "SIZZLE" CatShort = "FIRE" CategoryFull = "FIRE-SIZZLE" end
  if CatID == "FIRETrch" then Category = "FIRE" SubCategory = "TORCH" CatShort = "FIRE" CategoryFull = "FIRE-TORCH" end
  if CatID == "FIREWhsh" then Category = "FIRE" SubCategory = "WHOOSH" CatShort = "FIRE" CategoryFull = "FIRE-WHOOSH" end
  if CatID == "FRWKComr" then Category = "FIREWORKS" SubCategory = "COMMERCIAL" CatShort = "FRWK" CategoryFull = "FIREWORKS-COMMERCIAL" end
  if CatID == "FRWKMisc" then Category = "FIREWORKS" SubCategory = "MISC" CatShort = "FRWK" CategoryFull = "FIREWORKS-MISC" end
  if CatID == "FRWKRec" then Category = "FIREWORKS" SubCategory = "RECREATIONAL" CatShort = "FRWK" CategoryFull = "FIREWORKS-RECREATIONAL" end
  if CatID == "FOLYClth" then Category = "FOLEY" SubCategory = "CLOTH" CatShort = "FOLY" CategoryFull = "FOLEY-CLOTH" end
  if CatID == "FOLYFeet" then Category = "FOLEY" SubCategory = "FEET" CatShort = "FOLY" CategoryFull = "FOLEY-FEET" end
  if CatID == "FOLYHand" then Category = "FOLEY" SubCategory = "HANDS" CatShort = "FOLY" CategoryFull = "FOLEY-HANDS" end
  if CatID == "FOLYMisc" then Category = "FOLEY" SubCategory = "MISC" CatShort = "FOLY" CategoryFull = "FOLEY-MISC" end
  if CatID == "FOLYProp" then Category = "FOLEY" SubCategory = "PROP" CatShort = "FOLY" CategoryFull = "FOLEY-PROP" end
  if CatID == "FOODCook" then Category = "FOOD & DRINK" SubCategory = "COOKING" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-COOKING" end
  if CatID == "FOODDrnk" then Category = "FOOD & DRINK" SubCategory = "DRINKING" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-DRINKING" end
  if CatID == "FOODEat" then Category = "FOOD & DRINK" SubCategory = "EATING" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-EATING" end
  if CatID == "FOODGware" then Category = "FOOD & DRINK" SubCategory = "GLASSWARE" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-GLASSWARE" end
  if CatID == "FOODIngr" then Category = "FOOD & DRINK" SubCategory = "INGREDIENTS" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-INGREDIENTS" end
  if CatID == "FOODKware" then Category = "FOOD & DRINK" SubCategory = "KITCHENWARE" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-KITCHENWARE" end
  if CatID == "FOODMisc" then Category = "FOOD & DRINK" SubCategory = "MISC" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-MISC" end
  if CatID == "FOODTware" then Category = "FOOD & DRINK" SubCategory = "TABLEWARE" CatShort = "FOOD" CategoryFull = "FOOD & DRINK-TABLEWARE" end
  if CatID == "FEETAnml" then Category = "FOOTSTEPS" SubCategory = "ANIMAL" CatShort = "FEET" CategoryFull = "FOOTSTEPS-ANIMAL" end
  if CatID == "FEETCrea" then Category = "FOOTSTEPS" SubCategory = "CREATURE" CatShort = "FEET" CategoryFull = "FOOTSTEPS-CREATURE" end
  if CatID == "FEETHors" then Category = "FOOTSTEPS" SubCategory = "HORSE" CatShort = "FEET" CategoryFull = "FOOTSTEPS-HORSE" end
  if CatID == "FEETHmn" then Category = "FOOTSTEPS" SubCategory = "HUMAN" CatShort = "FEET" CategoryFull = "FOOTSTEPS-HUMAN" end
  if CatID == "FEETMisc" then Category = "FOOTSTEPS" SubCategory = "MISC" CatShort = "FEET" CategoryFull = "FOOTSTEPS-MISC" end
  if CatID == "GAMEArcd" then Category = "GAMES" SubCategory = "ARCADE" CatShort = "GAME" CategoryFull = "GAMES-ARCADE" end
  if CatID == "GAMEBoard" then Category = "GAMES" SubCategory = "BOARD" CatShort = "GAME" CategoryFull = "GAMES-BOARD" end
  if CatID == "GAMECas" then Category = "GAMES" SubCategory = "CASINO" CatShort = "GAME" CategoryFull = "GAMES-CASINO" end
  if CatID == "GAMEMisc" then Category = "GAMES" SubCategory = "MISC" CatShort = "GAME" CategoryFull = "GAMES-MISC" end
  if CatID == "GAMEVideo" then Category = "GAMES" SubCategory = "VIDEO" CatShort = "GAME" CategoryFull = "GAMES-VIDEO" end
  if CatID == "GEOFuma" then Category = "GEOTHERMAL" SubCategory = "FUMAROLE" CatShort = "GEO" CategoryFull = "GEOTHERMAL-FUMAROLE" end
  if CatID == "GEOGeyser" then Category = "GEOTHERMAL" SubCategory = "GEYSER" CatShort = "GEO" CategoryFull = "GEOTHERMAL-GEYSER" end
  if CatID == "GEOLava" then Category = "GEOTHERMAL" SubCategory = "LAVA" CatShort = "GEO" CategoryFull = "GEOTHERMAL-LAVA" end
  if CatID == "GEOMisc" then Category = "GEOTHERMAL" SubCategory = "MISC" CatShort = "GEO" CategoryFull = "GEOTHERMAL-MISC" end
  if CatID == "GEOMudpot" then Category = "GEOTHERMAL" SubCategory = "MUD POTS" CatShort = "GEO" CategoryFull = "GEOTHERMAL-MUD POTS" end
  if CatID == "GLASBrk" then Category = "GLASS" SubCategory = "BREAK" CatShort = "GLAS" CategoryFull = "GLASS-BREAK" end
  if CatID == "GLASCrsh" then Category = "GLASS" SubCategory = "CRASH & DEBRIS" CatShort = "GLAS" CategoryFull = "GLASS-CRASH & DEBRIS" end
  if CatID == "GLASFric" then Category = "GLASS" SubCategory = "FRICTION" CatShort = "GLAS" CategoryFull = "GLASS-FRICTION" end
  if CatID == "GLASImpt" then Category = "GLASS" SubCategory = "IMPACT" CatShort = "GLAS" CategoryFull = "GLASS-IMPACT" end
  if CatID == "GLASMisc" then Category = "GLASS" SubCategory = "MISC" CatShort = "GLAS" CategoryFull = "GLASS-MISC" end
  if CatID == "GLASMvmt" then Category = "GLASS" SubCategory = "MOVEMENT" CatShort = "GLAS" CategoryFull = "GLASS-MOVEMENT" end
  if CatID == "GLASTonl" then Category = "GLASS" SubCategory = "TONAL" CatShort = "GLAS" CategoryFull = "GLASS-TONAL" end
  if CatID == "GOREBurn" then Category = "GORE" SubCategory = "BURN" CatShort = "GORE" CategoryFull = "GORE-BURN" end
  if CatID == "GOREFlsh" then Category = "GORE" SubCategory = "FLESH" CatShort = "GORE" CategoryFull = "GORE-FLESH" end
  if CatID == "GOREMisc" then Category = "GORE" SubCategory = "MISC" CatShort = "GORE" CategoryFull = "GORE-MISC" end
  if CatID == "GOREOoze" then Category = "GORE" SubCategory = "OOZE" CatShort = "GORE" CategoryFull = "GORE-OOZE" end
  if CatID == "GORESrce" then Category = "GORE" SubCategory = "SOURCE" CatShort = "GORE" CategoryFull = "GORE-SOURCE" end
  if CatID == "GORESplt" then Category = "GORE" SubCategory = "SPLAT" CatShort = "GORE" CategoryFull = "GORE-SPLAT" end
  if CatID == "GORESqsh" then Category = "GORE" SubCategory = "SQUISH" CatShort = "GORE" CategoryFull = "GORE-SQUISH" end
  if CatID == "GOREStab" then Category = "GORE" SubCategory = "STAB" CatShort = "GORE" CategoryFull = "GORE-STAB" end
  if CatID == "GUNAntq" then Category = "GUNS" SubCategory = "ANTIQUE" CatShort = "GUN" CategoryFull = "GUNS-ANTIQUE" end
  if CatID == "GUNArtl" then Category = "GUNS" SubCategory = "ARTILLERY" CatShort = "GUN" CategoryFull = "GUNS-ARTILLERY" end
  if CatID == "GUNAuto" then Category = "GUNS" SubCategory = "AUTOMATIC" CatShort = "GUN" CategoryFull = "GUNS-AUTOMATIC" end
  if CatID == "GUNCano" then Category = "GUNS" SubCategory = "CANNON" CatShort = "GUN" CategoryFull = "GUNS-CANNON" end
  if CatID == "GUNHndl" then Category = "GUNS" SubCategory = "HANDLE" CatShort = "GUN" CategoryFull = "GUNS-HANDLE" end
  if CatID == "GUNTech" then Category = "GUNS" SubCategory = "HITECH" CatShort = "GUN" CategoryFull = "GUNS-HITECH" end
  if CatID == "GUNMech" then Category = "GUNS" SubCategory = "MECHANISM" CatShort = "GUN" CategoryFull = "GUNS-MECHANISM" end
  if CatID == "GUNMisc" then Category = "GUNS" SubCategory = "MISC" CatShort = "GUN" CategoryFull = "GUNS-MISC" end
  if CatID == "GUNPis" then Category = "GUNS" SubCategory = "PISTOL" CatShort = "GUN" CategoryFull = "GUNS-PISTOL" end
  if CatID == "GUNRif" then Category = "GUNS" SubCategory = "RIFLE" CatShort = "GUN" CategoryFull = "GUNS-RIFLE" end
  if CatID == "GUNShotg" then Category = "GUNS" SubCategory = "SHOTGUN" CatShort = "GUN" CategoryFull = "GUNS-SHOTGUN" end
  if CatID == "GUNSupr" then Category = "GUNS" SubCategory = "SUPPRESSED" CatShort = "GUN" CategoryFull = "GUNS-SUPPRESSED" end
  if CatID == "HORNAir" then Category = "HORNS" SubCategory = "AIR POWERED" CatShort = "HORN" CategoryFull = "HORNS-AIR POWERED" end
  if CatID == "HORNCele" then Category = "HORNS" SubCategory = "CELEBRATION" CatShort = "HORN" CategoryFull = "HORNS-CELEBRATION" end
  if CatID == "HORNMisc" then Category = "HORNS" SubCategory = "MISC" CatShort = "HORN" CategoryFull = "HORNS-MISC" end
  if CatID == "HORNTrad" then Category = "HORNS" SubCategory = "TRADITIONAL" CatShort = "HORN" CategoryFull = "HORNS-TRADITIONAL" end
  if CatID == "HMNBrth" then Category = "HUMAN" SubCategory = "BREATH" CatShort = "HMN" CategoryFull = "HUMAN-BREATH" end
  if CatID == "HMNBurp" then Category = "HUMAN" SubCategory = "BURP" CatShort = "HMN" CategoryFull = "HUMAN-BURP" end
  if CatID == "HMNCough" then Category = "HUMAN" SubCategory = "COUGH" CatShort = "HMN" CategoryFull = "HUMAN-COUGH" end
  if CatID == "HMNHart" then Category = "HUMAN" SubCategory = "HEARTBEAT" CatShort = "HMN" CategoryFull = "HUMAN-HEARTBEAT" end
  if CatID == "HMNKiss" then Category = "HUMAN" SubCategory = "KISS" CatShort = "HMN" CategoryFull = "HUMAN-KISS" end
  if CatID == "HMNMisc" then Category = "HUMAN" SubCategory = "MISC" CatShort = "HMN" CategoryFull = "HUMAN-MISC" end
  if CatID == "HMNSneez" then Category = "HUMAN" SubCategory = "SNEEZE" CatShort = "HMN" CategoryFull = "HUMAN-SNEEZE" end
  if CatID == "HMNSnor" then Category = "HUMAN" SubCategory = "SNORE" CatShort = "HMN" CategoryFull = "HUMAN-SNORE" end
  if CatID == "HMNSpit" then Category = "HUMAN" SubCategory = "SPIT" CatShort = "HMN" CategoryFull = "HUMAN-SPIT" end
  if CatID == "ICEBrk" then Category = "ICE" SubCategory = "BREAK" CatShort = "ICE" CategoryFull = "ICE-BREAK" end
  if CatID == "ICECrsh" then Category = "ICE" SubCategory = "CRASH & DEBRIS" CatShort = "ICE" CategoryFull = "ICE-CRASH & DEBRIS" end
  if CatID == "ICEFric" then Category = "ICE" SubCategory = "FRICTION" CatShort = "ICE" CategoryFull = "ICE-FRICTION" end
  if CatID == "ICEImpt" then Category = "ICE" SubCategory = "IMPACT" CatShort = "ICE" CategoryFull = "ICE-IMPACT" end
  if CatID == "ICEMisc" then Category = "ICE" SubCategory = "MISC" CatShort = "ICE" CategoryFull = "ICE-MISC" end
  if CatID == "ICEMvmt" then Category = "ICE" SubCategory = "MOVEMENT" CatShort = "ICE" CategoryFull = "ICE-MOVEMENT" end
  if CatID == "ICETonl" then Category = "ICE" SubCategory = "TONAL" CatShort = "ICE" CategoryFull = "ICE-TONAL" end
  if CatID == "LASRGun" then Category = "LASERS" SubCategory = "GUN" CatShort = "LASR" CategoryFull = "LASERS-GUN" end
  if CatID == "LASRImpt" then Category = "LASERS" SubCategory = "IMPACT" CatShort = "LASR" CategoryFull = "LASERS-IMPACT" end
  if CatID == "LASRMisc" then Category = "LASERS" SubCategory = "MISC" CatShort = "LASR" CategoryFull = "LASERS-MISC" end
  if CatID == "LETHRCreak" then Category = "LEATHER" SubCategory = "CREAK" CatShort = "LETHR" CategoryFull = "LEATHER-CREAK" end
  if CatID == "LETHRImpt" then Category = "LEATHER" SubCategory = "IMPACT" CatShort = "LETHR" CategoryFull = "LEATHER-IMPACT" end
  if CatID == "LETHRMisc" then Category = "LEATHER" SubCategory = "MISC" CatShort = "LETHR" CategoryFull = "LEATHER-MISC" end
  if CatID == "LETHRMvmt" then Category = "LEATHER" SubCategory = "MOVEMENT" CatShort = "LETHR" CategoryFull = "LEATHER-MOVEMENT" end
  if CatID == "LIQBubl" then Category = "LIQUID & MUD" SubCategory = "BUBBLES" CatShort = "LIQ" CategoryFull = "LIQUID & MUD-BUBBLES" end
  if CatID == "LIQImpt" then Category = "LIQUID & MUD" SubCategory = "IMPACT" CatShort = "LIQ" CategoryFull = "LIQUID & MUD-IMPACT" end
  if CatID == "LIQMisc" then Category = "LIQUID & MUD" SubCategory = "MISC" CatShort = "LIQ" CategoryFull = "LIQUID & MUD-MISC" end
  if CatID == "LIQMvmt" then Category = "LIQUID & MUD" SubCategory = "MOVEMENT" CatShort = "LIQ" CategoryFull = "LIQUID & MUD-MOVEMENT" end
  if CatID == "LIQSuct" then Category = "LIQUID & MUD" SubCategory = "SUCTION" CatShort = "LIQ" CategoryFull = "LIQUID & MUD-SUCTION" end
  if CatID == "MACHAmus" then Category = "MACHINES" SubCategory = "AMUSEMENT" CatShort = "MACH" CategoryFull = "MACHINES-AMUSEMENT" end
  if CatID == "MACHAntq" then Category = "MACHINES" SubCategory = "ANTIQUE" CatShort = "MACH" CategoryFull = "MACHINES-ANTIQUE" end
  if CatID == "MACHAppl" then Category = "MACHINES" SubCategory = "APPLIANCE" CatShort = "MACH" CategoryFull = "MACHINES-APPLIANCE" end
  if CatID == "MACHCnst" then Category = "MACHINES" SubCategory = "CONSTRUCTION" CatShort = "MACH" CategoryFull = "MACHINES-CONSTRUCTION" end
  if CatID == "MACHElev" then Category = "MACHINES" SubCategory = "ELEVATOR" CatShort = "MACH" CategoryFull = "MACHINES-ELEVATOR" end
  if CatID == "MACHEscl" then Category = "MACHINES" SubCategory = "ESCALATOR" CatShort = "MACH" CategoryFull = "MACHINES-ESCALATOR" end
  if CatID == "MACHFan" then Category = "MACHINES" SubCategory = "FAN" CatShort = "MACH" CategoryFull = "MACHINES-FAN" end
  if CatID == "MACHTech" then Category = "MACHINES" SubCategory = "HITECH" CatShort = "MACH" CategoryFull = "MACHINES-HITECH" end
  if CatID == "MACHHvac" then Category = "MACHINES" SubCategory = "HVAC" CatShort = "MACH" CategoryFull = "MACHINES-HVAC" end
  if CatID == "MACHInd" then Category = "MACHINES" SubCategory = "INDUSTRIAL" CatShort = "MACH" CategoryFull = "MACHINES-INDUSTRIAL" end
  if CatID == "MACHMech" then Category = "MACHINES" SubCategory = "MECHANISM" CatShort = "MACH" CategoryFull = "MACHINES-MECHANISM" end
  if CatID == "MACHMed" then Category = "MACHINES" SubCategory = "MEDICAL" CatShort = "MACH" CategoryFull = "MACHINES-MEDICAL" end
  if CatID == "MACHMisc" then Category = "MACHINES" SubCategory = "MISC" CatShort = "MACH" CategoryFull = "MACHINES-MISC" end
  if CatID == "MACHOffi" then Category = "MACHINES" SubCategory = "OFFICE" CatShort = "MACH" CategoryFull = "MACHINES-OFFICE" end
  if CatID == "MACHPump" then Category = "MACHINES" SubCategory = "PUMP" CatShort = "MACH" CategoryFull = "MACHINES-PUMP" end
  if CatID == "MAGAngl" then Category = "MAGIC" SubCategory = "ANGELIC" CatShort = "MAG" CategoryFull = "MAGIC-ANGELIC" end
  if CatID == "MAGElem" then Category = "MAGIC" SubCategory = "ELEMENTAL" CatShort = "MAG" CategoryFull = "MAGIC-ELEMENTAL" end
  if CatID == "MAGEvil" then Category = "MAGIC" SubCategory = "EVIL" CatShort = "MAG" CategoryFull = "MAGIC-EVIL" end
  if CatID == "MAGMisc" then Category = "MAGIC" SubCategory = "MISC" CatShort = "MAG" CategoryFull = "MAGIC-MISC" end
  if CatID == "MAGPoof" then Category = "MAGIC" SubCategory = "POOF" CatShort = "MAG" CategoryFull = "MAGIC-POOF" end
  if CatID == "MAGShim" then Category = "MAGIC" SubCategory = "SHIMMER" CatShort = "MAG" CategoryFull = "MAGIC-SHIMMER" end
  if CatID == "MAGSpel" then Category = "MAGIC" SubCategory = "SPELL" CatShort = "MAG" CategoryFull = "MAGIC-SPELL" end
  if CatID == "MECHClik" then Category = "MECHANICAL" SubCategory = "CLICK" CatShort = "MECH" CategoryFull = "MECHANICAL-CLICK" end
  if CatID == "MECHGear" then Category = "MECHANICAL" SubCategory = "GEARS" CatShort = "MECH" CategoryFull = "MECHANICAL-GEARS" end
  if CatID == "MECHHydr" then Category = "MECHANICAL" SubCategory = "HYDRAULIC & PNEUMATIC" CatShort = "MECH" CategoryFull = "MECHANICAL-HYDRAULIC & PNEUMATIC" end
  if CatID == "MECHLtch" then Category = "MECHANICAL" SubCategory = "LATCH" CatShort = "MECH" CategoryFull = "MECHANICAL-LATCH" end
  if CatID == "MECHLvr" then Category = "MECHANICAL" SubCategory = "LEVER" CatShort = "MECH" CategoryFull = "MECHANICAL-LEVER" end
  if CatID == "MECHLock" then Category = "MECHANICAL" SubCategory = "LOCK" CatShort = "MECH" CategoryFull = "MECHANICAL-LOCK" end
  if CatID == "MECHMisc" then Category = "MECHANICAL" SubCategory = "MISC" CatShort = "MECH" CategoryFull = "MECHANICAL-MISC" end
  if CatID == "MECHPuly" then Category = "MECHANICAL" SubCategory = "PULLEY" CatShort = "MECH" CategoryFull = "MECHANICAL-PULLEY" end
  if CatID == "MECHRtch" then Category = "MECHANICAL" SubCategory = "RATCHET" CatShort = "MECH" CategoryFull = "MECHANICAL-RATCHET" end
  if CatID == "MECHRelay" then Category = "MECHANICAL" SubCategory = "RELAY" CatShort = "MECH" CategoryFull = "MECHANICAL-RELAY" end
  if CatID == "MECHRolr" then Category = "MECHANICAL" SubCategory = "ROLLER" CatShort = "MECH" CategoryFull = "MECHANICAL-ROLLER" end
  if CatID == "MECHSwtch" then Category = "MECHANICAL" SubCategory = "SWITCH" CatShort = "MECH" CategoryFull = "MECHANICAL-SWITCH" end
  if CatID == "METLBrk" then Category = "METAL" SubCategory = "BREAK" CatShort = "METL" CategoryFull = "METAL-BREAK" end
  if CatID == "METLCrsh" then Category = "METAL" SubCategory = "CRASH & DEBRIS" CatShort = "METL" CategoryFull = "METAL-CRASH & DEBRIS" end
  if CatID == "METLFric" then Category = "METAL" SubCategory = "FRICTION" CatShort = "METL" CategoryFull = "METAL-FRICTION" end
  if CatID == "METLImpt" then Category = "METAL" SubCategory = "IMPACT" CatShort = "METL" CategoryFull = "METAL-IMPACT" end
  if CatID == "METLMisc" then Category = "METAL" SubCategory = "MISC" CatShort = "METL" CategoryFull = "METAL-MISC" end
  if CatID == "METLMvmt" then Category = "METAL" SubCategory = "MOVEMENT" CatShort = "METL" CategoryFull = "METAL-MOVEMENT" end
  if CatID == "METLTonl" then Category = "METAL" SubCategory = "TONAL" CatShort = "METL" CategoryFull = "METAL-TONAL" end
  if CatID == "MOTRAntq" then Category = "MOTORS" SubCategory = "ANTIQUE" CatShort = "MOTR" CategoryFull = "MOTORS-ANTIQUE" end
  if CatID == "MOTRComb" then Category = "MOTORS" SubCategory = "COMBUSTION" CatShort = "MOTR" CategoryFull = "MOTORS-COMBUSTION" end
  if CatID == "MOTRElec" then Category = "MOTORS" SubCategory = "ELECTRIC" CatShort = "MOTR" CategoryFull = "MOTORS-ELECTRIC" end
  if CatID == "MOTRMisc" then Category = "MOTORS" SubCategory = "MISC" CatShort = "MOTR" CategoryFull = "MOTORS-MISC" end
  if CatID == "MOTRSrvo" then Category = "MOTORS" SubCategory = "SERVO" CatShort = "MOTR" CategoryFull = "MOTORS-SERVO" end
  if CatID == "MOTRTurb" then Category = "MOTORS" SubCategory = "TURBINE" CatShort = "MOTR" CategoryFull = "MOTORS-TURBINE" end
  if CatID == "MOVEActv" then Category = "MOVEMENT" SubCategory = "ACTIVITY" CatShort = "MOVE" CategoryFull = "MOVEMENT-ACTIVITY" end
  if CatID == "MOVEAnml" then Category = "MOVEMENT" SubCategory = "ANIMAL" CatShort = "MOVE" CategoryFull = "MOVEMENT-ANIMAL" end
  if CatID == "MOVECrea" then Category = "MOVEMENT" SubCategory = "CREATURE" CatShort = "MOVE" CategoryFull = "MOVEMENT-CREATURE" end
  if CatID == "MOVECrwd" then Category = "MOVEMENT" SubCategory = "CROWD" CatShort = "MOVE" CategoryFull = "MOVEMENT-CROWD" end
  if CatID == "MOVEInsc" then Category = "MOVEMENT" SubCategory = "INSECT" CatShort = "MOVE" CategoryFull = "MOVEMENT-INSECT" end
  if CatID == "MOVEMisc" then Category = "MOVEMENT" SubCategory = "MISC" CatShort = "MOVE" CategoryFull = "MOVEMENT-MISC" end
  if CatID == "MOVEPres" then Category = "MOVEMENT" SubCategory = "PRESENCE" CatShort = "MOVE" CategoryFull = "MOVEMENT-PRESENCE" end
  if CatID == "MUSCBrass" then Category = "MUSICAL" SubCategory = "BRASS" CatShort = "MUSC" CategoryFull = "MUSICAL-BRASS" end
  if CatID == "MUSCChim" then Category = "MUSICAL" SubCategory = "CHIME" CatShort = "MUSC" CategoryFull = "MUSICAL-CHIME" end
  if CatID == "MUSCChor" then Category = "MUSICAL" SubCategory = "CHORAL" CatShort = "MUSC" CategoryFull = "MUSICAL-CHORAL" end
  if CatID == "MUSCInst" then Category = "MUSICAL" SubCategory = "INSTRUMENT" CatShort = "MUSC" CategoryFull = "MUSICAL-INSTRUMENT" end
  if CatID == "MUSCLoop" then Category = "MUSICAL" SubCategory = "LOOP" CatShort = "MUSC" CategoryFull = "MUSICAL-LOOP" end
  if CatID == "MUSCMisc" then Category = "MUSICAL" SubCategory = "MISC" CatShort = "MUSC" CategoryFull = "MUSICAL-MISC" end
  if CatID == "MUSCPerc" then Category = "MUSICAL" SubCategory = "PERCUSSION" CatShort = "MUSC" CategoryFull = "MUSICAL-PERCUSSION" end
  if CatID == "MUSCSmpl" then Category = "MUSICAL" SubCategory = "SAMPLE" CatShort = "MUSC" CategoryFull = "MUSICAL-SAMPLE" end
  if CatID == "MUSCSong" then Category = "MUSICAL" SubCategory = "SONG & PHRASE" CatShort = "MUSC" CategoryFull = "MUSICAL-SONG & PHRASE" end
  if CatID == "MUSCStngr" then Category = "MUSICAL" SubCategory = "STINGER" CatShort = "MUSC" CategoryFull = "MUSICAL-STINGER" end
  if CatID == "MUSCStr" then Category = "MUSICAL" SubCategory = "STRINGED" CatShort = "MUSC" CategoryFull = "MUSICAL-STRINGED" end
  if CatID == "MUSCToy" then Category = "MUSICAL" SubCategory = "TOY" CatShort = "MUSC" CategoryFull = "MUSICAL-TOY" end
  if CatID == "MUSCWind" then Category = "MUSICAL" SubCategory = "WOODWIND" CatShort = "MUSC" CategoryFull = "MUSICAL-WOODWIND" end
  if CatID == "NATDAval" then Category = "NATURAL DISASTER" SubCategory = "AVALANCHE" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-AVALANCHE" end
  if CatID == "NATDQuak" then Category = "NATURAL DISASTER" SubCategory = "EARTHQUAKE" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-EARTHQUAKE" end
  if CatID == "NATDMisc" then Category = "NATURAL DISASTER" SubCategory = "MISC" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-MISC" end
  if CatID == "NATDTorn" then Category = "NATURAL DISASTER" SubCategory = "TORNADO" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-TORNADO" end
  if CatID == "NATDTsun" then Category = "NATURAL DISASTER" SubCategory = "TSUNAMI" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-TSUNAMI" end
  if CatID == "NATDThyp" then Category = "NATURAL DISASTER" SubCategory = "TYPHOON" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-TYPHOON" end
  if CatID == "NATDVolc" then Category = "NATURAL DISASTER" SubCategory = "VOLCANO" CatShort = "NATD" CategoryFull = "NATURAL DISASTER-VOLCANO" end
  if CatID == "OBJBag" then Category = "OBJECTS" SubCategory = "BAG" CatShort = "OBJ" CategoryFull = "OBJECTS-BAG" end
  if CatID == "OBJBook" then Category = "OBJECTS" SubCategory = "BOOK" CatShort = "OBJ" CategoryFull = "OBJECTS-BOOK" end
  if CatID == "OBJCoin" then Category = "OBJECTS" SubCategory = "COIN" CatShort = "OBJ" CategoryFull = "OBJECTS-COIN" end
  if CatID == "OBJCont" then Category = "OBJECTS" SubCategory = "CONTAINER" CatShort = "OBJ" CategoryFull = "OBJECTS-CONTAINER" end
  if CatID == "OBJFurn" then Category = "OBJECTS" SubCategory = "FURNITURE" CatShort = "OBJ" CategoryFull = "OBJECTS-FURNITURE" end
  if CatID == "OBJHsehld" then Category = "OBJECTS" SubCategory = "HOUSEHOLD" CatShort = "OBJ" CategoryFull = "OBJECTS-HOUSEHOLD" end
  if CatID == "OBJJewl" then Category = "OBJECTS" SubCategory = "JEWELRY" CatShort = "OBJ" CategoryFull = "OBJECTS-JEWELRY" end
  if CatID == "OBJKey" then Category = "OBJECTS" SubCategory = "KEYS" CatShort = "OBJ" CategoryFull = "OBJECTS-KEYS" end
  if CatID == "OBJLug" then Category = "OBJECTS" SubCategory = "LUGGAGE" CatShort = "OBJ" CategoryFull = "OBJECTS-LUGGAGE" end
  if CatID == "OBJMed" then Category = "OBJECTS" SubCategory = "MEDICAL" CatShort = "OBJ" CategoryFull = "OBJECTS-MEDICAL" end
  if CatID == "OBJMisc" then Category = "OBJECTS" SubCategory = "MISC" CatShort = "OBJ" CategoryFull = "OBJECTS-MISC" end
  if CatID == "OBJPack" then Category = "OBJECTS" SubCategory = "PACKAGING" CatShort = "OBJ" CategoryFull = "OBJECTS-PACKAGING" end
  if CatID == "OBJTape" then Category = "OBJECTS" SubCategory = "TAPE" CatShort = "OBJ" CategoryFull = "OBJECTS-TAPE" end
  if CatID == "OBJUmbr" then Category = "OBJECTS" SubCategory = "UMBRELLA" CatShort = "OBJ" CategoryFull = "OBJECTS-UMBRELLA" end
  if CatID == "OBJWhled" then Category = "OBJECTS" SubCategory = "WHEELED" CatShort = "OBJ" CategoryFull = "OBJECTS-WHEELED" end
  if CatID == "OBJWrite" then Category = "OBJECTS" SubCategory = "WRITING" CatShort = "OBJ" CategoryFull = "OBJECTS-WRITING" end
  if CatID == "OBJZipr" then Category = "OBJECTS" SubCategory = "ZIPPER" CatShort = "OBJ" CategoryFull = "OBJECTS-ZIPPER" end
  if CatID == "PAPRFltr" then Category = "PAPER" SubCategory = "FLUTTER" CatShort = "PAPR" CategoryFull = "PAPER-FLUTTER" end
  if CatID == "PAPRFric" then Category = "PAPER" SubCategory = "FRICTION" CatShort = "PAPR" CategoryFull = "PAPER-FRICTION" end
  if CatID == "PAPRHndl" then Category = "PAPER" SubCategory = "HANDLE" CatShort = "PAPR" CategoryFull = "PAPER-HANDLE" end
  if CatID == "PAPRImpt" then Category = "PAPER" SubCategory = "IMPACT" CatShort = "PAPR" CategoryFull = "PAPER-IMPACT" end
  if CatID == "PAPRMisc" then Category = "PAPER" SubCategory = "MISC" CatShort = "PAPR" CategoryFull = "PAPER-MISC" end
  if CatID == "PAPRRip" then Category = "PAPER" SubCategory = "RIP" CatShort = "PAPR" CategoryFull = "PAPER-RIP" end
  if CatID == "PAPRTonl" then Category = "PAPER" SubCategory = "TONAL" CatShort = "PAPR" CategoryFull = "PAPER-TONAL" end
  if CatID == "PLASBrk" then Category = "PLASTIC" SubCategory = "BREAK" CatShort = "PLAS" CategoryFull = "PLASTIC-BREAK" end
  if CatID == "PLASCrsh" then Category = "PLASTIC" SubCategory = "CRASH & DEBRIS" CatShort = "PLAS" CategoryFull = "PLASTIC-CRASH & DEBRIS" end
  if CatID == "PLASFric" then Category = "PLASTIC" SubCategory = "FRICTION" CatShort = "PLAS" CategoryFull = "PLASTIC-FRICTION" end
  if CatID == "PLASImpt" then Category = "PLASTIC" SubCategory = "IMPACT" CatShort = "PLAS" CategoryFull = "PLASTIC-IMPACT" end
  if CatID == "PLASMisc" then Category = "PLASTIC" SubCategory = "MISC" CatShort = "PLAS" CategoryFull = "PLASTIC-MISC" end
  if CatID == "PLASMvmt" then Category = "PLASTIC" SubCategory = "MOVEMENT" CatShort = "PLAS" CategoryFull = "PLASTIC-MOVEMENT" end
  if CatID == "RAINClth" then Category = "RAIN" SubCategory = "CLOTH" CatShort = "RAIN" CategoryFull = "RAIN-CLOTH" end
  if CatID == "RAINConc" then Category = "RAIN" SubCategory = "CONCRETE" CatShort = "RAIN" CategoryFull = "RAIN-CONCRETE" end
  if CatID == "RAIN" then Category = "RAIN" SubCategory = "GENERAL" CatShort = "RAIN" CategoryFull = "RAIN-GENERAL" end
  if CatID == "RAINGlas" then Category = "RAIN" SubCategory = "GLASS" CatShort = "RAIN" CategoryFull = "RAIN-GLASS" end
  if CatID == "RAINMetl" then Category = "RAIN" SubCategory = "METAL" CatShort = "RAIN" CategoryFull = "RAIN-METAL" end
  if CatID == "RAINPlas" then Category = "RAIN" SubCategory = "PLASTIC" CatShort = "RAIN" CategoryFull = "RAIN-PLASTIC" end
  if CatID == "RAINVege" then Category = "RAIN" SubCategory = "VEGETATION" CatShort = "RAIN" CategoryFull = "RAIN-VEGETATION" end
  if CatID == "RAINWatr" then Category = "RAIN" SubCategory = "WATER" CatShort = "RAIN" CategoryFull = "RAIN-WATER" end
  if CatID == "RAINWood" then Category = "RAIN" SubCategory = "WOOD" CatShort = "RAIN" CategoryFull = "RAIN-WOOD" end
  if CatID == "ROBTMisc" then Category = "ROBOTS" SubCategory = "MISC" CatShort = "ROBT" CategoryFull = "ROBOTS-MISC" end
  if CatID == "ROBTMvmt" then Category = "ROBOTS" SubCategory = "MOVEMENT" CatShort = "ROBT" CategoryFull = "ROBOTS-MOVEMENT" end
  if CatID == "ROBTVox" then Category = "ROBOTS" SubCategory = "VOCAL" CatShort = "ROBT" CategoryFull = "ROBOTS-VOCAL" end
  if CatID == "ROCKBrk" then Category = "ROCKS" SubCategory = "BREAK" CatShort = "ROCK" CategoryFull = "ROCKS-BREAK" end
  if CatID == "ROCKCrsh" then Category = "ROCKS" SubCategory = "CRASH & DEBRIS" CatShort = "ROCK" CategoryFull = "ROCKS-CRASH & DEBRIS" end
  if CatID == "ROCKFric" then Category = "ROCKS" SubCategory = "FRICTION" CatShort = "ROCK" CategoryFull = "ROCKS-FRICTION" end
  if CatID == "ROCKImpt" then Category = "ROCKS" SubCategory = "IMPACT" CatShort = "ROCK" CategoryFull = "ROCKS-IMPACT" end
  if CatID == "ROCKMisc" then Category = "ROCKS" SubCategory = "MISC" CatShort = "ROCK" CategoryFull = "ROCKS-MISC" end
  if CatID == "ROCKMvmt" then Category = "ROCKS" SubCategory = "MOVEMENT" CatShort = "ROCK" CategoryFull = "ROCKS-MOVEMENT" end
  if CatID == "ROCKTonl" then Category = "ROCKS" SubCategory = "TONAL" CatShort = "ROCK" CategoryFull = "ROCKS-TONAL" end
  if CatID == "ROPECreak" then Category = "ROPE" SubCategory = "CREAK" CatShort = "ROPE" CategoryFull = "ROPE-CREAK" end
  if CatID == "ROPEMisc" then Category = "ROPE" SubCategory = "MISC" CatShort = "ROPE" CategoryFull = "ROPE-MISC" end
  if CatID == "ROPEMvmt" then Category = "ROPE" SubCategory = "MOVEMENT" CatShort = "ROPE" CategoryFull = "ROPE-MOVEMENT" end
  if CatID == "RUBRCrsh" then Category = "RUBBER" SubCategory = "CRASH & DEBRIS" CatShort = "RUBR" CategoryFull = "RUBBER-CRASH & DEBRIS" end
  if CatID == "RUBRFric" then Category = "RUBBER" SubCategory = "FRICTION" CatShort = "RUBR" CategoryFull = "RUBBER-FRICTION" end
  if CatID == "RUBRImpt" then Category = "RUBBER" SubCategory = "IMPACT" CatShort = "RUBR" CategoryFull = "RUBBER-IMPACT" end
  if CatID == "RUBRMisc" then Category = "RUBBER" SubCategory = "MISC" CatShort = "RUBR" CategoryFull = "RUBBER-MISC" end
  if CatID == "RUBRMvmt" then Category = "RUBBER" SubCategory = "MOVEMENT" CatShort = "RUBR" CategoryFull = "RUBBER-MOVEMENT" end
  if CatID == "SCIAlrm" then Category = "SCIFI" SubCategory = "ALARM" CatShort = "SCI" CategoryFull = "SCIFI-ALARM" end
  if CatID == "SCICmpt" then Category = "SCIFI" SubCategory = "COMPUTER" CatShort = "SCI" CategoryFull = "SCIFI-COMPUTER" end
  if CatID == "SCIDoor" then Category = "SCIFI" SubCategory = "DOOR" CatShort = "SCI" CategoryFull = "SCIFI-DOOR" end
  if CatID == "SCIEnrg" then Category = "SCIFI" SubCategory = "ENERGY" CatShort = "SCI" CategoryFull = "SCIFI-ENERGY" end
  if CatID == "SCIMach" then Category = "SCIFI" SubCategory = "MACHINE" CatShort = "SCI" CategoryFull = "SCIFI-MACHINE" end
  if CatID == "SCIMech" then Category = "SCIFI" SubCategory = "MECHANISM" CatShort = "SCI" CategoryFull = "SCIFI-MECHANISM" end
  if CatID == "SCIMisc" then Category = "SCIFI" SubCategory = "MISC" CatShort = "SCI" CategoryFull = "SCIFI-MISC" end
  if CatID == "SCIRetro" then Category = "SCIFI" SubCategory = "RETRO" CatShort = "SCI" CategoryFull = "SCIFI-RETRO" end
  if CatID == "SCIShip" then Category = "SCIFI" SubCategory = "SPACESHIP" CatShort = "SCI" CategoryFull = "SCIFI-SPACESHIP" end
  if CatID == "SCIVeh" then Category = "SCIFI" SubCategory = "VEHICLE" CatShort = "SCI" CategoryFull = "SCIFI-VEHICLE" end
  if CatID == "SCIWeap" then Category = "SCIFI" SubCategory = "WEAPON" CatShort = "SCI" CategoryFull = "SCIFI-WEAPON" end
  if CatID == "SNOWCrsh" then Category = "SNOW" SubCategory = "CRASH & DEBRIS" CatShort = "SNOW" CategoryFull = "SNOW-CRASH & DEBRIS" end
  if CatID == "SNOWFric" then Category = "SNOW" SubCategory = "FRICTION" CatShort = "SNOW" CategoryFull = "SNOW-FRICTION" end
  if CatID == "SNOWImpt" then Category = "SNOW" SubCategory = "IMPACT" CatShort = "SNOW" CategoryFull = "SNOW-IMPACT" end
  if CatID == "SNOWMisc" then Category = "SNOW" SubCategory = "MISC" CatShort = "SNOW" CategoryFull = "SNOW-MISC" end
  if CatID == "SNOWMvmt" then Category = "SNOW" SubCategory = "MOVEMENT" CatShort = "SNOW" CategoryFull = "SNOW-MOVEMENT" end
  if CatID == "SPRTCourt" then Category = "SPORTS" SubCategory = "COURT" CatShort = "SPRT" CategoryFull = "SPORTS-COURT" end
  if CatID == "SPRTField" then Category = "SPORTS" SubCategory = "FIELD" CatShort = "SPRT" CategoryFull = "SPORTS-FIELD" end
  if CatID == "SPRTGym" then Category = "SPORTS" SubCategory = "GYM" CatShort = "SPRT" CategoryFull = "SPORTS-GYM" end
  if CatID == "SPRTIndor" then Category = "SPORTS" SubCategory = "INDOOR" CatShort = "SPRT" CategoryFull = "SPORTS-INDOOR" end
  if CatID == "SPRTMisc" then Category = "SPORTS" SubCategory = "MISC" CatShort = "SPRT" CategoryFull = "SPORTS-MISC" end
  if CatID == "SPRTSkate" then Category = "SPORTS" SubCategory = "SKATE" CatShort = "SPRT" CategoryFull = "SPORTS-SKATE" end
  if CatID == "SPRTTrck" then Category = "SPORTS" SubCategory = "TRACK & FIELD" CatShort = "SPRT" CategoryFull = "SPORTS-TRACK & FIELD" end
  if CatID == "SPRTWatr" then Category = "SPORTS" SubCategory = "WATER" CatShort = "SPRT" CategoryFull = "SPORTS-WATER" end
  if CatID == "SPRTWntr" then Category = "SPORTS" SubCategory = "WINTER" CatShort = "SPRT" CategoryFull = "SPORTS-WINTER" end
  if CatID == "SWSH" then Category = "SWOOSHES" SubCategory = "SWISH" CatShort = "SWSH" CategoryFull = "SWOOSHES-SWISH" end
  if CatID == "WHSH" then Category = "SWOOSHES" SubCategory = "WHOOSH" CatShort = "WHSH" CategoryFull = "SWOOSHES-WHOOSH" end
  if CatID == "TOOLHand" then Category = "TOOLS" SubCategory = "HAND" CatShort = "TOOL" CategoryFull = "TOOLS-HAND" end
  if CatID == "TOOLMisc" then Category = "TOOLS" SubCategory = "MISC" CatShort = "TOOL" CategoryFull = "TOOLS-MISC" end
  if CatID == "TOOLPneu" then Category = "TOOLS" SubCategory = "PNEUMATIC" CatShort = "TOOL" CategoryFull = "TOOLS-PNEUMATIC" end
  if CatID == "TOOLPowr" then Category = "TOOLS" SubCategory = "POWER" CatShort = "TOOL" CategoryFull = "TOOLS-POWER" end
  if CatID == "TOYElec" then Category = "TOYS" SubCategory = "ELECTRONIC" CatShort = "TOY" CategoryFull = "TOYS-ELECTRONIC" end
  if CatID == "TOYMech" then Category = "TOYS" SubCategory = "MECHANICAL" CatShort = "TOY" CategoryFull = "TOYS-MECHANICAL" end
  if CatID == "TOYMisc" then Category = "TOYS" SubCategory = "MISC" CatShort = "TOY" CategoryFull = "TOYS-MISC" end
  if CatID == "TRNBrake" then Category = "TRAINS" SubCategory = "BRAKE" CatShort = "TRN" CategoryFull = "TRAINS-BRAKE" end
  if CatID == "TRNClak" then Category = "TRAINS" SubCategory = "CLACK" CatShort = "TRN" CategoryFull = "TRAINS-CLACK" end
  if CatID == "TRNDiesl" then Category = "TRAINS" SubCategory = "DIESEL" CatShort = "TRN" CategoryFull = "TRAINS-DIESEL" end
  if CatID == "TRNElec" then Category = "TRAINS" SubCategory = "ELECTRIC" CatShort = "TRN" CategoryFull = "TRAINS-ELECTRIC" end
  if CatID == "TRNHspd" then Category = "TRAINS" SubCategory = "HIGH SPEED" CatShort = "TRN" CategoryFull = "TRAINS-HIGH SPEED" end
  if CatID == "TRNHorn" then Category = "TRAINS" SubCategory = "HORN" CatShort = "TRN" CategoryFull = "TRAINS-HORN" end
  if CatID == "TRNInt" then Category = "TRAINS" SubCategory = "INTERIOR" CatShort = "TRN" CategoryFull = "TRAINS-INTERIOR" end
  if CatID == "TRNMech" then Category = "TRAINS" SubCategory = "MECHANISM" CatShort = "TRN" CategoryFull = "TRAINS-MECHANISM" end
  if CatID == "TRNMisc" then Category = "TRAINS" SubCategory = "MISC" CatShort = "TRN" CategoryFull = "TRAINS-MISC" end
  if CatID == "TRNSteam" then Category = "TRAINS" SubCategory = "STEAM" CatShort = "TRN" CategoryFull = "TRAINS-STEAM" end
  if CatID == "TRNSbwy" then Category = "TRAINS" SubCategory = "SUBWAY" CatShort = "TRN" CategoryFull = "TRAINS-SUBWAY" end
  if CatID == "TRNTram" then Category = "TRAINS" SubCategory = "TRAM" CatShort = "TRN" CategoryFull = "TRAINS-TRAM" end
  if CatID == "UIAlert" then Category = "USER INTERFACE" SubCategory = "ALERT" CatShort = "UI" CategoryFull = "USER INTERFACE-ALERT" end
  if CatID == "UIBeep" then Category = "USER INTERFACE" SubCategory = "BEEP" CatShort = "UI" CategoryFull = "USER INTERFACE-BEEP" end
  if CatID == "UIClick" then Category = "USER INTERFACE" SubCategory = "CLICK" CatShort = "UI" CategoryFull = "USER INTERFACE-CLICK" end
  if CatID == "UIData" then Category = "USER INTERFACE" SubCategory = "DATA" CatShort = "UI" CategoryFull = "USER INTERFACE-DATA" end
  if CatID == "UIGlitch" then Category = "USER INTERFACE" SubCategory = "GLITCH" CatShort = "UI" CategoryFull = "USER INTERFACE-GLITCH" end
  if CatID == "UIMisc" then Category = "USER INTERFACE" SubCategory = "MISC" CatShort = "UI" CategoryFull = "USER INTERFACE-MISC" end
  if CatID == "UIMvmt" then Category = "USER INTERFACE" SubCategory = "MOTION" CatShort = "UI" CategoryFull = "USER INTERFACE-MOTION" end
  if CatID == "VEGEGras" then Category = "VEGETATION" SubCategory = "GRASS" CatShort = "VEGE" CategoryFull = "VEGETATION-GRASS" end
  if CatID == "VEGELeaf" then Category = "VEGETATION" SubCategory = "LEAVES" CatShort = "VEGE" CategoryFull = "VEGETATION-LEAVES" end
  if CatID == "VEGEMisc" then Category = "VEGETATION" SubCategory = "MISC" CatShort = "VEGE" CategoryFull = "VEGETATION-MISC" end
  if CatID == "VEGETree" then Category = "VEGETATION" SubCategory = "TREE" CatShort = "VEGE" CategoryFull = "VEGETATION-TREE" end
  if CatID == "VEHAlrm" then Category = "VEHICLES" SubCategory = "ALARM" CatShort = "VEH" CategoryFull = "VEHICLES-ALARM" end
  if CatID == "VEHAntq" then Category = "VEHICLES" SubCategory = "ANTIQUE" CatShort = "VEH" CategoryFull = "VEHICLES-ANTIQUE" end
  if CatID == "VEHAtv" then Category = "VEHICLES" SubCategory = "ATV" CatShort = "VEH" CategoryFull = "VEHICLES-ATV" end
  if CatID == "VEHBike" then Category = "VEHICLES" SubCategory = "BICYCLE" CatShort = "VEH" CategoryFull = "VEHICLES-BICYCLE" end
  if CatID == "VEHBrake" then Category = "VEHICLES" SubCategory = "BRAKE" CatShort = "VEH" CategoryFull = "VEHICLES-BRAKE" end
  if CatID == "VEHBus" then Category = "VEHICLES" SubCategory = "BUS" CatShort = "VEH" CategoryFull = "VEHICLES-BUS" end
  if CatID == "VEHCar" then Category = "VEHICLES" SubCategory = "CAR" CatShort = "VEH" CategoryFull = "VEHICLES-CAR" end
  if CatID == "VEHCnst" then Category = "VEHICLES" SubCategory = "CONSTRUCTION" CatShort = "VEH" CategoryFull = "VEHICLES-CONSTRUCTION" end
  if CatID == "VEHDoor" then Category = "VEHICLES" SubCategory = "DOOR" CatShort = "VEH" CategoryFull = "VEHICLES-DOOR" end
  if CatID == "VEHElec" then Category = "VEHICLES" SubCategory = "ELECTRIC" CatShort = "VEH" CategoryFull = "VEHICLES-ELECTRIC" end
  if CatID == "VEHFarm" then Category = "VEHICLES" SubCategory = "FARM" CatShort = "VEH" CategoryFull = "VEHICLES-FARM" end
  if CatID == "VEHFrght" then Category = "VEHICLES" SubCategory = "FREIGHT" CatShort = "VEH" CategoryFull = "VEHICLES-FREIGHT" end
  if CatID == "VEHBy" then Category = "VEHICLES" SubCategory = "GENERIC BY" CatShort = "VEH" CategoryFull = "VEHICLES-GENERIC BY" end
  if CatID == "VEHHorn" then Category = "VEHICLES" SubCategory = "HORN" CatShort = "VEH" CategoryFull = "VEHICLES-HORN" end
  if CatID == "VEHInt" then Category = "VEHICLES" SubCategory = "INTERIOR" CatShort = "VEH" CategoryFull = "VEHICLES-INTERIOR" end
  if CatID == "VEHJalop" then Category = "VEHICLES" SubCategory = "JALOPY" CatShort = "VEH" CategoryFull = "VEHICLES-JALOPY" end
  if CatID == "VEHMech" then Category = "VEHICLES" SubCategory = "MECHANISM" CatShort = "VEH" CategoryFull = "VEHICLES-MECHANISM" end
  if CatID == "VEHMil" then Category = "VEHICLES" SubCategory = "MILITARY" CatShort = "VEH" CategoryFull = "VEHICLES-MILITARY" end
  if CatID == "VEHMisc" then Category = "VEHICLES" SubCategory = "MISC" CatShort = "VEH" CategoryFull = "VEHICLES-MISC" end
  if CatID == "VEHMoto" then Category = "VEHICLES" SubCategory = "MOTORCYCLE" CatShort = "VEH" CategoryFull = "VEHICLES-MOTORCYCLE" end
  if CatID == "VEHRace" then Category = "VEHICLES" SubCategory = "RACING" CatShort = "VEH" CategoryFull = "VEHICLES-RACING" end
  if CatID == "VEHSirn" then Category = "VEHICLES" SubCategory = "SIREN" CatShort = "VEH" CategoryFull = "VEHICLES-SIREN" end
  if CatID == "VEHSkid" then Category = "VEHICLES" SubCategory = "SKID" CatShort = "VEH" CategoryFull = "VEHICLES-SKID" end
  if CatID == "VEHSusp" then Category = "VEHICLES" SubCategory = "SUSPENSION" CatShort = "VEH" CategoryFull = "VEHICLES-SUSPENSION" end
  if CatID == "VEHTire" then Category = "VEHICLES" SubCategory = "TIRE" CatShort = "VEH" CategoryFull = "VEHICLES-TIRE" end
  if CatID == "VEHTruck" then Category = "VEHICLES" SubCategory = "TRUCK VAN & SUV" CatShort = "VEH" CategoryFull = "VEHICLES-TRUCK VAN & SUV" end
  if CatID == "VEHUtil" then Category = "VEHICLES" SubCategory = "UTILITY" CatShort = "VEH" CategoryFull = "VEHICLES-UTILITY" end
  if CatID == "VEHWagn" then Category = "VEHICLES" SubCategory = "WAGON" CatShort = "VEH" CategoryFull = "VEHICLES-WAGON" end
  if CatID == "VEHWndw" then Category = "VEHICLES" SubCategory = "WINDOW" CatShort = "VEH" CategoryFull = "VEHICLES-WINDOW" end
  if CatID == "VOXAlien" then Category = "VOICES" SubCategory = "ALIEN" CatShort = "VOX" CategoryFull = "VOICES-ALIEN" end
  if CatID == "VOXBaby" then Category = "VOICES" SubCategory = "BABY" CatShort = "VOX" CategoryFull = "VOICES-BABY" end
  if CatID == "VOXCheer" then Category = "VOICES" SubCategory = "CHEER" CatShort = "VOX" CategoryFull = "VOICES-CHEER" end
  if CatID == "VOXChld" then Category = "VOICES" SubCategory = "CHILD" CatShort = "VOX" CategoryFull = "VOICES-CHILD" end
  if CatID == "VOXCry" then Category = "VOICES" SubCategory = "CRYING" CatShort = "VOX" CategoryFull = "VOICES-CRYING" end
  if CatID == "VOXEfrt" then Category = "VOICES" SubCategory = "EFFORTS" CatShort = "VOX" CategoryFull = "VOICES-EFFORTS" end
  if CatID == "VOXFem" then Category = "VOICES" SubCategory = "FEMALE" CatShort = "VOX" CategoryFull = "VOICES-FEMALE" end
  if CatID == "VOXFutz" then Category = "VOICES" SubCategory = "FUTZED" CatShort = "VOX" CategoryFull = "VOICES-FUTZED" end
  if CatID == "VOXHist" then Category = "VOICES" SubCategory = "HISTORICAL" CatShort = "VOX" CategoryFull = "VOICES-HISTORICAL" end
  if CatID == "VOXLaff" then Category = "VOICES" SubCategory = "LAUGH" CatShort = "VOX" CategoryFull = "VOICES-LAUGH" end
  if CatID == "VOXMale" then Category = "VOICES" SubCategory = "MALE" CatShort = "VOX" CategoryFull = "VOICES-MALE" end
  if CatID == "VOXMisc" then Category = "VOICES" SubCategory = "MISC" CatShort = "VOX" CategoryFull = "VOICES-MISC" end
  if CatID == "VOXReac" then Category = "VOICES" SubCategory = "REACTION" CatShort = "VOX" CategoryFull = "VOICES-REACTION" end
  if CatID == "VOXScrm" then Category = "VOICES" SubCategory = "SCREAM" CatShort = "VOX" CategoryFull = "VOICES-SCREAM" end
  if CatID == "VOXSing" then Category = "VOICES" SubCategory = "SINGING" CatShort = "VOX" CategoryFull = "VOICES-SINGING" end
  if CatID == "WATRBubl" then Category = "WATER" SubCategory = "BUBBLES" CatShort = "WATR" CategoryFull = "WATER-BUBBLES" end
  if CatID == "WATRDran" then Category = "WATER" SubCategory = "DRAIN" CatShort = "WATR" CategoryFull = "WATER-DRAIN" end
  if CatID == "WATRDrip" then Category = "WATER" SubCategory = "DRIP" CatShort = "WATR" CategoryFull = "WATER-DRIP" end
  if CatID == "WATRFlow" then Category = "WATER" SubCategory = "FLOW" CatShort = "WATR" CategoryFull = "WATER-FLOW" end
  if CatID == "WATRFoun" then Category = "WATER" SubCategory = "FOUNTAIN" CatShort = "WATR" CategoryFull = "WATER-FOUNTAIN" end
  if CatID == "WATRImpt" then Category = "WATER" SubCategory = "IMPACT" CatShort = "WATR" CategoryFull = "WATER-IMPACT" end
  if CatID == "WATRLap" then Category = "WATER" SubCategory = "LAP" CatShort = "WATR" CategoryFull = "WATER-LAP" end
  if CatID == "WATRMisc" then Category = "WATER" SubCategory = "MISC" CatShort = "WATR" CategoryFull = "WATER-MISC" end
  if CatID == "WATRMvmt" then Category = "WATER" SubCategory = "MOVEMENT" CatShort = "WATR" CategoryFull = "WATER-MOVEMENT" end
  if CatID == "WATRPlmb" then Category = "WATER" SubCategory = "PLUMBING" CatShort = "WATR" CategoryFull = "WATER-PLUMBING" end
  if CatID == "WATRSplsh" then Category = "WATER" SubCategory = "SPLASH" CatShort = "WATR" CategoryFull = "WATER-SPLASH" end
  if CatID == "WATRSpray" then Category = "WATER" SubCategory = "SPRAY" CatShort = "WATR" CategoryFull = "WATER-SPRAY" end
  if CatID == "WATRStm" then Category = "WATER" SubCategory = "STEAM" CatShort = "WATR" CategoryFull = "WATER-STEAM" end
  if CatID == "WATRSurf" then Category = "WATER" SubCategory = "SURF" CatShort = "WATR" CategoryFull = "WATER-SURF" end
  if CatID == "WATRTurb" then Category = "WATER" SubCategory = "TURBULENT" CatShort = "WATR" CategoryFull = "WATER-TURBULENT" end
  if CatID == "WATRFall" then Category = "WATER" SubCategory = "WATERFALL" CatShort = "WATR" CategoryFull = "WATER-WATERFALL" end
  if CatID == "WATRWave" then Category = "WATER" SubCategory = "WAVE" CatShort = "WATR" CategoryFull = "WATER-WAVE" end
  if CatID == "WEAPArmr" then Category = "WEAPONS" SubCategory = "ARMOR" CatShort = "WEAP" CategoryFull = "WEAPONS-ARMOR" end
  if CatID == "WEAPArro" then Category = "WEAPONS" SubCategory = "ARROW" CatShort = "WEAP" CategoryFull = "WEAPONS-ARROW" end
  if CatID == "WEAPBlnt" then Category = "WEAPONS" SubCategory = "BLUNT" CatShort = "WEAP" CategoryFull = "WEAPONS-BLUNT" end
  if CatID == "WEAPBow" then Category = "WEAPONS" SubCategory = "BOW" CatShort = "WEAP" CategoryFull = "WEAPONS-BOW" end
  if CatID == "WEAPKnif" then Category = "WEAPONS" SubCategory = "KNIFE" CatShort = "WEAP" CategoryFull = "WEAPONS-KNIFE" end
  if CatID == "WEAPMisc" then Category = "WEAPONS" SubCategory = "MISC" CatShort = "WEAP" CategoryFull = "WEAPONS-MISC" end
  if CatID == "WEAPPole" then Category = "WEAPONS" SubCategory = "POLEARM" CatShort = "WEAP" CategoryFull = "WEAPONS-POLEARM" end
  if CatID == "WEAPSiege" then Category = "WEAPONS" SubCategory = "SIEGE" CatShort = "WEAP" CategoryFull = "WEAPONS-SIEGE" end
  if CatID == "WEAPSwrd" then Category = "WEAPONS" SubCategory = "SWORD" CatShort = "WEAP" CategoryFull = "WEAPONS-SWORD" end
  if CatID == "WEAPWhip" then Category = "WEAPONS" SubCategory = "WHIP" CatShort = "WEAP" CategoryFull = "WEAPONS-WHIP" end
  if CatID == "HAIL" then Category = "WEATHER" SubCategory = "HAIL" CatShort = "HAIL" CategoryFull = "WEATHER-HAIL" end
  if CatID == "WTHR" then Category = "WEATHER" SubCategory = "MISC" CatShort = "WTHR" CategoryFull = "WEATHER-MISC" end
  if CatID == "STORM" then Category = "WEATHER" SubCategory = "STORM" CatShort = "STORM" CategoryFull = "WEATHER-STORM" end
  if CatID == "THUN" then Category = "WEATHER" SubCategory = "THUNDER" CatShort = "THUN" CategoryFull = "WEATHER-THUNDER" end
  if CatID == "WHSTHmn" then Category = "WHISTLES" SubCategory = "HUMAN" CatShort = "WHST" CategoryFull = "WHISTLES-HUMAN" end
  if CatID == "WHSTMech" then Category = "WHISTLES" SubCategory = "MECHANICAL" CatShort = "WHST" CategoryFull = "WHISTLES-MECHANICAL" end
  if CatID == "WHSTMisc" then Category = "WHISTLES" SubCategory = "MISC" CatShort = "WHST" CategoryFull = "WHISTLES-MISC" end
  if CatID == "WINDDsgn" then Category = "WIND" SubCategory = "DESIGNED" CatShort = "WIND" CategoryFull = "WIND-DESIGNED" end
  if CatID == "WIND" then Category = "WIND" SubCategory = "GENERAL" CatShort = "WIND" CategoryFull = "WIND-GENERAL" end
  if CatID == "WINDGust" then Category = "WIND" SubCategory = "GUST" CatShort = "WIND" CategoryFull = "WIND-GUST" end
  if CatID == "WINDInt" then Category = "WIND" SubCategory = "INTERIOR" CatShort = "WIND" CategoryFull = "WIND-INTERIOR" end
  if CatID == "WINDTonl" then Category = "WIND" SubCategory = "TONAL" CatShort = "WIND" CategoryFull = "WIND-TONAL" end
  if CatID == "WINDVege" then Category = "WIND" SubCategory = "VEGETATION" CatShort = "WIND" CategoryFull = "WIND-VEGETATION" end
  if CatID == "WNDWCover" then Category = "WINDOWS" SubCategory = "COVERING" CatShort = "WNDW" CategoryFull = "WINDOWS-COVERING" end
  if CatID == "WNDWHdwr" then Category = "WINDOWS" SubCategory = "HARDWARE" CatShort = "WNDW" CategoryFull = "WINDOWS-HARDWARE" end
  if CatID == "WNDWKnck" then Category = "WINDOWS" SubCategory = "KNOCK" CatShort = "WNDW" CategoryFull = "WINDOWS-KNOCK" end
  if CatID == "WNDWMetl" then Category = "WINDOWS" SubCategory = "METAL" CatShort = "WNDW" CategoryFull = "WINDOWS-METAL" end
  if CatID == "WNDWMisc" then Category = "WINDOWS" SubCategory = "MISC" CatShort = "WNDW" CategoryFull = "WINDOWS-MISC" end
  if CatID == "WNDWPlas" then Category = "WINDOWS" SubCategory = "PLASTIC" CatShort = "WNDW" CategoryFull = "WINDOWS-PLASTIC" end
  if CatID == "WNDWWood" then Category = "WINDOWS" SubCategory = "WOOD" CatShort = "WNDW" CategoryFull = "WINDOWS-WOOD" end
  if CatID == "WINGBird" then Category = "WINGS" SubCategory = "BIRD" CatShort = "WING" CategoryFull = "WINGS-BIRD" end
  if CatID == "WINGCrea" then Category = "WINGS" SubCategory = "CREATURE" CatShort = "WING" CategoryFull = "WINGS-CREATURE" end
  if CatID == "WINGInsc" then Category = "WINGS" SubCategory = "INSECT" CatShort = "WING" CategoryFull = "WINGS-INSECT" end
  if CatID == "WINGMisc" then Category = "WINGS" SubCategory = "MISC" CatShort = "WING" CategoryFull = "WINGS-MISC" end
  if CatID == "WOODBrk" then Category = "WOOD" SubCategory = "BREAK" CatShort = "WOOD" CategoryFull = "WOOD-BREAK" end
  if CatID == "WOODCrsh" then Category = "WOOD" SubCategory = "CRASH & DEBRIS" CatShort = "WOOD" CategoryFull = "WOOD-CRASH & DEBRIS" end
  if CatID == "WOODFric" then Category = "WOOD" SubCategory = "FRICTION" CatShort = "WOOD" CategoryFull = "WOOD-FRICTION" end
  if CatID == "WOODImpt" then Category = "WOOD" SubCategory = "IMPACT" CatShort = "WOOD" CategoryFull = "WOOD-IMPACT" end
  if CatID == "WOODMisc" then Category = "WOOD" SubCategory = "MISC" CatShort = "WOOD" CategoryFull = "WOOD-MISC" end
  if CatID == "WOODMvmt" then Category = "WOOD" SubCategory = "MOVEMENT" CatShort = "WOOD" CategoryFull = "WOOD-MOVEMENT" end
  if CatID == "WOODTonl" then Category = "WOOD" SubCategory = "TONAL" CatShort = "WOOD" CategoryFull = "WOOD-TONAL" end
end

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

      region.name = CatID
      if CatID ~= '' then
        region.name = build_name(region.name, origin_name, #j)
        catid_fun(region.name)
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