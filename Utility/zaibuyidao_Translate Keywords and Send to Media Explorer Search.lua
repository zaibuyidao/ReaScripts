-- @description Translate Keywords and Send to Media Explorer Search
-- @version 1.0.3
-- @author zaibuyidao
-- @changelog
--   New Script
-- @links
--   https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about
--   Requires:
--   1. ReaImGui
--   2. js_ReaScriptAPI
--   3. Python
--   4. Python package: openai

local ZBYDFuncPath = reaper.GetResourcePath() .. '/Scripts/zaibuyidao Scripts/Utility/zaibuyidao_Functions.lua'
if reaper.file_exists(ZBYDFuncPath) then
  dofile(ZBYDFuncPath)
  if not checkSWSExtension() or not checkJSAPIExtension() then return end
else
  local errorMsg = "Error - Missing Script (错误 - 缺失脚本)\n\n" ..
  "[English]\nThe required 'zaibuyidao Functions' script file was not found. Please ensure the file is correctly placed at:\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\nIf the file is missing, you can install it via ReaPack by searching for 'zaibuyidao Functions' in the ReaPack package browser.\n\n" ..
  "[中文]\n必需的 'zaibuyidao Functions' 脚本文件未找到。请确保文件正确放置在以下位置：\n" ..
  ZBYDFuncPath:gsub('%\\', '/') .. "\n\n如果文件缺失，您可以通过 ReaPack 包浏览器搜索并安装 'zaibuyidao Functions'。\n"

  reaper.MB(errorMsg, "Missing Script Error/脚本文件缺失错误", 0)

  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('zaibuyidao Functions')
  else
    local reapackErrorMsg = "Error - ReaPack Not Found (错误 - 未找到 ReaPack)\n\n" ..
    "[English]\nThe ReaPack extension is not found. Please install ReaPack to manage and install REAPER scripts and extensions easily. Visit https://reapack.com for installation instructions.\n\n" ..
    "[中文]\n未找到 ReaPack 扩展。请安装 ReaPack 来便捷地管理和安装 REAPER 脚本及扩展。访问 https://reapack.com 获取安装指南。\n"

    reaper.MB(reapackErrorMsg, "ReaPack Not Found/未找到 ReaPack", 0)
  end
  return
end

local SCRIPT_NAME = "Translate Keywords and Send to Media Explorer Search"
local EXT_SECTION = "TRANSLATE_KEYWORDS_AND_SEND_TO_MEDIA_EXPLORER_SEARCH"

local DEFAULT_API_KEY_B64 = "YjY2YzczMzA2OWQ4NDAyNWIyZTdkZTJlNTg1ZTk1MjcuMTdmUEdRRzY2OTE5UldMVA=="
local DEFAULT_BASE_URL = "https://open.bigmodel.cn/api/paas/v4/"
local DEFAULT_MODEL_NAME = "glm-4-flash"

if not reaper.ImGui_GetBuiltinPath then
  if reaper.APIExists("ReaPack_BrowsePackages") then
    reaper.ReaPack_BrowsePackages("ReaImGui: ReaScript binding for Dear ImGui")
  end
  reaper.MB(
    "ReaImGui is not installed or is out of date.\n\nPlease install or update 'ReaImGui: ReaScript binding for Dear ImGui' before running this script.",
    SCRIPT_NAME,
    0
  )
  return
end

if not reaper.APIExists("JS_Window_Find") then
  if reaper.APIExists("ReaPack_BrowsePackages") then
    reaper.ReaPack_BrowsePackages("js_ReaScriptAPI")
  end
  reaper.MB(
    "js_ReaScriptAPI is not installed.\n\nPlease install 'js_ReaScriptAPI: API functions for ReaScripts' before running this script.",
    SCRIPT_NAME,
    0
  )
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require "imgui" "0.10"

local FLT_MIN = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext(SCRIPT_NAME)
if reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly then
  reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
end

local font = reaper.ImGui_CreateFont("sans-serif", 14)
reaper.ImGui_Attach(ctx, font)

local FRAME_ROUNDING = 6.0
local WINDOW_ROUNDING = 8.0
local TITLE_BG_COLOR = 0x121212FF

local info = debug.getinfo(1, "S")
local script_path = info.source:match([[^@?(.*[\/])[^\/]-$]]) or ""
local is_windows = reaper.GetOS():find("Win") ~= nil
local language = getSystemLanguage() -- Detect the system language to display messages in Chinese or English

local function i18n(sc, tc, en)
  if language == "简体中文" then
    return sc
  elseif language == "繁體中文" then
    return tc
  else
    return en
  end
end

local UI_TEXT = {
  missing_media_explorer = i18n("未找到媒体资源管理器窗口。", "找不到 Media Explorer 視窗。", "Media Explorer window not found."),
  missing_search_box = i18n("未找到媒体资源管理器搜索框。", "找不到 Media Explorer 搜尋框。", "Media Explorer search box not found."),
  empty_keywords = i18n("关键词为空。", "關鍵字為空。", "Keywords are empty."),
  no_synonyms = i18n("没有可用的同义词。", "沒有可用的同義詞。", "No synonyms available."),
  start_translation_failed = i18n("无法开始翻译。", "無法開始翻譯。", "Unable to start translation."),
  current_sent = i18n("当前文本已发送到媒体资源管理器。", "目前文字已傳送到 Media Explorer。", "Current text sent to Media Explorer."),
  current_send_failed = i18n("发送当前文本失败。", "傳送目前文字失敗。", "Failed to send current text."),
  translated_sent = i18n("已翻译并发送到媒体资源管理器。", "已翻譯並傳送到 Media Explorer。", "Translated and sent to Media Explorer."),
  translated_sent_no_synonyms = i18n("已翻译并发送到媒体资源管理器。仅单个关键词输入支持同义词。", "已翻譯並傳送到 Media Explorer。只有單一關鍵字輸入支援同義詞。", "Translated and sent to Media Explorer. Synonyms are only available for single-keyword input."),
  search_send_failed = i18n("发送搜索文本失败。", "傳送搜尋文字失敗。", "Failed to send search text."),
  translation_failed = i18n("翻译失败。", "翻譯失敗。", "Translation failed."),
  input_help = i18n("输入任意语言文本。按 Enter 翻译成英文关键词并发送到媒体资源管理器搜索框。按 Ctrl+Enter 直接发送当前输入。", "輸入任意語言文字。按 Enter 翻譯成英文關鍵字並傳送到 Media Explorer 搜尋框。按 Ctrl+Enter 直接傳送目前輸入。", "Input text in any language. Press Enter to translate it into English keywords and send it to the Media Explorer search box. Press Ctrl+Enter to send the current input directly."),
  translating = i18n("翻译中...", "翻譯中...", "Translating..."),
  synonyms = i18n("同义词: ", "同義詞: ", "Synonyms:"),
  synonym_sent_prefix = i18n("同义词已发送到媒体资源管理器: ", "同義詞已傳送到 Media Explorer: ", "Synonym sent to Media Explorer: "),
  synonym_send_failed = i18n("发送同义词搜索失败。", "傳送同義詞搜尋失敗。", "Failed to send synonym search."),
  search_all_terms = i18n("搜索全部词条 (OR)", "搜尋全部詞條 (OR)", "Search All Terms (or)"),
  all_terms_sent = i18n("已使用 OR 逻辑发送翻译词和所有同义词。", "已使用 OR 邏輯傳送翻譯詞和所有同義詞。", "Translated term and all synonyms sent with OR logic."),
  all_terms_send_failed = i18n("发送 OR 同义词搜索失败。", "傳送 OR 同義詞搜尋失敗。", "Failed to send OR synonym search."),
  write_worker_failed = i18n("无法写入 Python worker: ", "無法寫入 Python worker: ", "Unable to write Python worker: "),
  write_launcher_failed = i18n("无法写入启动器: ", "無法寫入啟動器: ", "Unable to write launcher: "),
  empty_input = i18n("输入为空。", "輸入為空。", "Empty input"),
  translation_in_progress = i18n("翻译正在进行中。", "翻譯正在進行中。", "Translation already in progress"),
  api_key_empty = i18n("API key 为空。", "API key 為空。", "API key is empty"),
  write_request_failed = i18n("无法写入请求文本: ", "無法寫入請求文字：", "Unable to write request text: "),
  translation_timeout = i18n("翻译超时。", "翻譯逾時。", "Translation timed out."),
  empty_translation = i18n("翻译返回了空内容。", "翻譯傳回了空內容。", "Translation returned empty content."),
  missing_openai = i18n("缺少 Python openai 包。请运行: pip install openai", "缺少 Python openai 套件。請執行: pip install openai", "Missing Python package openai. Run: pip install openai"),
  empty_translation_result = i18n("翻译结果为空。", "翻譯結果為空。", "Empty translation result"),
  dependency_hint = i18n("Python 依赖: 如果无法开始翻译，请运行 `pip install openai`。", "Python 相依套件: 如果無法開始翻譯，請執行 `pip install openai`。", "Python dependency: install with `pip install openai` if translation cannot start."),
  button_translate = i18n("Enter: 翻译 + 搜索", "Enter: 翻譯 + 搜尋", "Enter: Translate + Search"),
  button_send_current = i18n("Ctrl+Enter: 发送当前文本", "Ctrl+Enter: 傳送目前文字", "Ctrl+Enter: Send Current Text"),
  button_close = i18n("关闭", "關閉", "Close"),
}

local function trim(s)
  s = tostring(s or "")
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function sanitize_search_text(text)
  text = tostring(text or "")
  text = text:gsub("[%z\1-\31\127]", "")
  text = text:gsub("\194[\128-\159]", "")
  return trim(text)
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then
    f:close()
    return true
  end
  return false
end

local function write_file(path, content)
  local f, err = io.open(path, "wb")
  if not f then
    return nil, err
  end
  f:write(content)
  f:close()
  return true
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

local function py_quote(s)
  return string.format("%q", tostring(s or ""))
end

local function base64_encode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  return ((data:gsub(".", function(x)
    local r, bits = "", x:byte()
    for i = 8, 1, -1 do
      r = r .. ((bits % 2 ^ i - bits % 2 ^ (i - 1) > 0) and "1" or "0")
    end
    return r
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then return "" end
    local c = 0
    for i = 1, 6 do
      c = c + ((x:sub(i, i) == "1") and 2 ^ (6 - i) or 0)
    end
    return b:sub(c + 1, c + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function base64_decode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  data = tostring(data or ""):gsub("[^" .. b .. "=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then return "" end
    local r, f = "", (b:find(x, 1, true) or 1) - 1
    for i = 6, 1, -1 do
      r = r .. ((f % 2 ^ i - f % 2 ^ (i - 1) > 0) and "1" or "0")
    end
    return r
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
    if #x ~= 8 then return "" end
    local c = 0
    for i = 1, 8 do
      c = c + ((x:sub(i, i) == "1") and 2 ^ (8 - i) or 0)
    end
    return string.char(c)
  end))
end

local function split_lines(text)
  local lines = {}
  text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  for line in text:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end
  return lines
end

local function normalize_compare_text(text)
  text = trim(text)
  text = text:gsub("^['\"]+", ""):gsub("['\"]+$", "")
  return text:lower()
end

local function normalize_keyword_spacing(text)
  text = trim(text)
  text = text:gsub("%s+", " ")
  return text
end

local function is_english_keyword(text)
  text = normalize_keyword_spacing(text)
  if text == "" then return false end
  if text:match("[^A-Za-z0-9%s%-%']") then
    return false
  end
  return text:match("[A-Za-z]") ~= nil
end

local function push_unique(list, seen, text)
  text = normalize_keyword_spacing(text)
  text = text:gsub("^[-*%d%.)%s]+", "")
  text = text:gsub("^['\"]+", ""):gsub("['\"]+$", "")
  text = normalize_keyword_spacing(text)
  if text == "" then return end
  if not is_english_keyword(text) then return end

  local key = normalize_compare_text(text)
  if key == "none" or key == "n/a" or key == "no synonyms" then
    return
  end
  if key == "" or seen[key] then return end
  seen[key] = true
  list[#list + 1] = text
end

local function split_synonym_text(text, primary_keyword)
  local synonyms = {}
  local seen = {}
  push_unique(synonyms, seen, primary_keyword)

  text = tostring(text or "")
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  text = text:gsub("%s+[Oo][Rr]%s+", "\n")
  text = text:gsub("|", "\n")
  text = text:gsub(";", "\n")
  text = text:gsub(",", "\n")
  text = text:gsub("/", "\n")

  for token in text:gmatch("[^\n]+") do
    push_unique(synonyms, seen, token)
  end

  return synonyms
end

local function split_primary_keyword_terms(text)
  local terms = split_synonym_text(text, "")
  local primary = terms[1] or trim(text)
  local extras = {}
  for i = 2, #terms do
    extras[#extras + 1] = terms[i]
  end
  return primary, extras
end

local function sanitize_primary_keyword(text)
  text = normalize_keyword_spacing(text)
  local suffixes = {
    " sound effects",
    " sound effect",
    " sound fx",
    " sfx",
    " sound",
    " audio effects",
    " audio effect",
    " audio",
    " fx",
  }

  local lower = text:lower()
  for i = 1, #suffixes do
    local suffix = suffixes[i]
    if lower:sub(-#suffix) == suffix and #lower > #suffix then
      text = trim(text:sub(1, #text - #suffix))
      lower = text:lower()
    end
  end

  text = normalize_keyword_spacing(text)
  if not is_english_keyword(text) then
    return ""
  end

  return text
end

local function parse_translation_payload(result)
  local raw = tostring(result or "")
  local normalized = raw:gsub("\r\n", "\n"):gsub("\r", "\n")
  local lower = normalized:lower()

  local keyword_text = ""
  local synonym_text = ""

  local keyword_start, keyword_end = lower:find("keywords%s*:")
  local synonym_start, synonym_end = lower:find("synonyms%s*:")

  if keyword_start then
    local keyword_stop = synonym_start and (synonym_start - 1) or #normalized
    keyword_text = normalized:sub(keyword_end + 1, keyword_stop)
  elseif synonym_start then
    keyword_text = normalized:sub(1, synonym_start - 1)
  else
    keyword_text = normalized
  end

  if synonym_start then
    synonym_text = normalized:sub(synonym_end + 1)
  end

  keyword_text = normalize_keyword_spacing(keyword_text:gsub("[%s\n]+", " "))
  keyword_text = keyword_text:gsub("^['\"]+", ""):gsub("['\"]+$", "")
  local keyword_extras
  keyword_text, keyword_extras = split_primary_keyword_terms(keyword_text)
  keyword_text = sanitize_primary_keyword(keyword_text)

  local synonyms = split_synonym_text(synonym_text, keyword_text)
  if keyword_text == "" and #synonyms > 0 then
    keyword_text = synonyms[1]
  end

  if keyword_text ~= "" then
    local all_terms = {}
    local seen = {}
    push_unique(all_terms, seen, keyword_text)
    for i = 1, #(keyword_extras or {}) do
      push_unique(all_terms, seen, keyword_extras[i])
    end
    for i = 1, #synonyms do
      push_unique(all_terms, seen, synonyms[i])
    end
    synonyms = all_terms
  end

  return keyword_text, synonyms
end

local function join_with_separator(items, separator)
  return table.concat(items or {}, separator or "\n")
end

local function supports_synonyms_for_input(text)
  text = trim(text)
  if text == "" then
    return false
  end

  if text:find("[,;/|]") then
    return false
  end

  local lower = text:lower()
  if lower:match("%s+or%s+") or lower:match("%s+and%s+") then
    return false
  end

  local word_count = 0
  for _ in text:gmatch("%S+") do
    word_count = word_count + 1
    if word_count > 1 then
      return false
    end
  end

  return word_count == 1
end

local function get_api_key()
  local value = reaper.GetExtState(EXT_SECTION, "api_key")
  if value == "" then
    value = base64_decode(DEFAULT_API_KEY_B64)
  end
  return value
end

local function get_base_url()
  local value = reaper.GetExtState(EXT_SECTION, "base_url")
  if value == "" then value = DEFAULT_BASE_URL end
  return value
end

local function get_model_name()
  local value = reaper.GetExtState(EXT_SECTION, "model_name")
  if value == "" then value = DEFAULT_MODEL_NAME end
  return value
end

local temp_input = script_path .. "__translate_input.txt"
local temp_output = script_path .. "__translate_output.txt"
local temp_python = script_path .. "__translate_worker.py"
local temp_launcher = script_path .. (is_windows and "__translate_launcher.vbs" or "__translate_launcher.sh")

local function build_python_worker()
  local py = {
    "# -*- coding: utf-8 -*-",
    "import os",
    "import sys",
    "",
    "try:",
    "    sys.stdout.reconfigure(encoding='utf-8')",
    "except Exception:",
    "    pass",
    "",
    "API_KEY = " .. py_quote(get_api_key()),
    "BASE_URL = " .. py_quote(get_base_url()),
    "MODEL_NAME = " .. py_quote(get_model_name()),
    "SYSTEM_PROMPT = " .. py_quote("你是一个音效搜索关键词翻译器。无论用户输入什么语言，包括中文、日文、韩文、法文、西班牙文或英文，都请直接转换成适合音效库搜索的英文关键词。只输出英文关键词结果，不要解释，不要编号，不要引号，不要句号。"),
    "",
    "def atomic_write(path, content):",
    "    tmp = path + '.tmp'",
    "    with open(tmp, 'w', encoding='utf-8') as f:",
    "        f.write(content)",
    "        f.flush()",
    "        os.fsync(f.fileno())",
    "    if os.path.exists(path):",
    "        os.remove(path)",
    "    os.replace(tmp, path)",
    "",
    "def fail(path, message):",
    "    atomic_write(path, 'Error: ' + str(message))",
    "",
    "def main():",
    "    if len(sys.argv) < 3:",
    "        sys.exit(1)",
    "    input_path = sys.argv[1]",
    "    output_path = sys.argv[2]",
    "    try:",
    "        from openai import OpenAI",
    "    except Exception as e:",
    "        fail(output_path, " .. py_quote(UI_TEXT.missing_openai) .. ")",
    "        return",
    "    try:",
    "        with open(input_path, 'r', encoding='utf-8') as f:",
    "            text = f.read().strip()",
    "    except Exception as e:",
    "        fail(output_path, e)",
    "        return",
    "    if not text:",
    "        fail(output_path, " .. py_quote(UI_TEXT.empty_input) .. ")",
    "        return",
    "    try:",
    "        client = OpenAI(api_key=API_KEY, base_url=BASE_URL)",
    "        response = client.chat.completions.create(",
    "            model=MODEL_NAME,",
    "            messages=[",
    "                {'role': 'system', 'content': SYSTEM_PROMPT},",
    "                {'role': 'user', 'content': text},",
    "            ],",
    "            temperature=0.1,",
    "            max_tokens=80,",
    "        )",
    "        result = ''",
    "        if response and getattr(response, 'choices', None):",
    "            msg = response.choices[0].message",
    "            result = getattr(msg, 'content', '') or ''",
    "        result = result.replace('\\r', ' ').replace('\\n', ' ').strip()",
    "        if not result:",
    "            fail(output_path, " .. py_quote(UI_TEXT.empty_translation_result) .. ")",
    "            return",
    "        atomic_write(output_path, result)",
    "    except Exception as e:",
    "        fail(output_path, e)",
    "",
    "if __name__ == '__main__':",
    "    main()",
    "",
  }
  return table.concat(py, "\n")
end

build_python_worker = function()
  local py = {
    "# -*- coding: utf-8 -*-",
    "import base64",
    "import os",
    "import sys",
    "",
    "try:",
    "    sys.stdout.reconfigure(encoding='utf-8')",
    "except Exception:",
    "    pass",
    "",
    "API_KEY_B64 = " .. py_quote(base64_encode(get_api_key())),
    "BASE_URL = " .. py_quote(get_base_url()),
    "MODEL_NAME = " .. py_quote(get_model_name()),
    "SYSTEM_PROMPT = " .. py_quote("You translate any user input into concise English for sound search, but the primary result should stay close to the literal core meaning of the original word or phrase. Return exactly two lines in this format:\nKEYWORDS: one primary english keyword or one short primary english phrase only\nSYNONYMS: synonym 1 | synonym 2 | synonym 3 | synonym 4 | synonym 5 | synonym 6 | synonym 7\nThe KEYWORDS line must contain only one primary result, not a list and not comma-separated alternatives. Do not append generic suffixes such as sound effect, sound effects, sound, audio, sfx, or fx unless they are part of the literal meaning. Both lines must contain English keywords only. Do not include Chinese, Japanese, Korean, Cyrillic, accented characters, emojis, or any non-English symbols. Use only English. Do not explain anything. Do not number items. Keep everything compact and search-friendly."),
    "",
    "def atomic_write(path, content):",
    "    tmp = path + '.tmp'",
    "    with open(tmp, 'w', encoding='utf-8') as f:",
    "        f.write(content)",
    "        f.flush()",
    "        os.fsync(f.fileno())",
    "    if os.path.exists(path):",
    "        os.remove(path)",
    "    os.replace(tmp, path)",
    "",
    "def fail(path, message):",
    "    atomic_write(path, 'Error: ' + str(message))",
    "",
    "def main():",
    "    if len(sys.argv) < 3:",
    "        sys.exit(1)",
    "    input_path = sys.argv[1]",
    "    output_path = sys.argv[2]",
    "    try:",
    "        from openai import OpenAI",
    "    except Exception:",
    "        fail(output_path, " .. py_quote(UI_TEXT.missing_openai) .. ")",
    "        return",
    "    try:",
    "        with open(input_path, 'r', encoding='utf-8') as f:",
    "            text = f.read().strip()",
    "    except Exception as e:",
    "        fail(output_path, e)",
    "        return",
    "    if not text:",
    "        fail(output_path, " .. py_quote(UI_TEXT.empty_input) .. ")",
    "        return",
    "    try:",
    "        api_key = base64.b64decode(API_KEY_B64).decode('utf-8')",
    "        client = OpenAI(api_key=api_key, base_url=BASE_URL)",
    "        response = client.chat.completions.create(",
    "            model=MODEL_NAME,",
    "            messages=[",
    "                {'role': 'system', 'content': SYSTEM_PROMPT},",
    "                {'role': 'user', 'content': text},",
    "            ],",
    "            temperature=0.1,",
    "            max_tokens=120,",
    "        )",
    "        result = ''",
    "        if response and getattr(response, 'choices', None):",
    "            msg = response.choices[0].message",
    "            result = getattr(msg, 'content', '') or ''",
    "        result = result.replace('\\r\\n', '\\n').replace('\\r', '\\n').strip()",
    "        if not result:",
    "            fail(output_path, " .. py_quote(UI_TEXT.empty_translation_result) .. ")",
    "            return",
    "        atomic_write(output_path, result)",
    "    except Exception as e:",
    "        fail(output_path, e)",
    "",
    "if __name__ == '__main__':",
    "    main()",
    "",
  }
  return table.concat(py, "\n")
end

local function ensure_worker_files()
  local ok, err = write_file(temp_python, build_python_worker())
  if not ok then
    return nil, UI_TEXT.write_worker_failed .. tostring(err or "")
  end

  local launcher
  if is_windows then
    local py_cmd = 'pythonw "' .. temp_python:gsub('"', '""') .. '" "' .. temp_input:gsub('"', '""') .. '" "' .. temp_output:gsub('"', '""') .. '"'
    launcher = table.concat({
      'Set shell = CreateObject("WScript.Shell")',
      'shell.Run "' .. py_cmd:gsub('"', '""') .. '", 0, False',
      "",
    }, "\r\n")
  else
    launcher = table.concat({
      "#!/bin/sh",
      "export LANG=en_US.UTF-8",
      "python3 " .. string.format("%q", temp_python) .. " " .. string.format("%q", temp_input) .. " " .. string.format("%q", temp_output),
      "",
    }, "\n")
  end

  ok, err = write_file(temp_launcher, launcher)
  if not ok then
    return nil, UI_TEXT.write_launcher_failed .. tostring(err or "")
  end
  return true
end

local Translator = {
  is_requesting = false,
  request_start_time = 0,
  pending_text = nil,
  error_message = nil,
}

local function cleanup_temp_io()
  os.remove(temp_input)
  os.remove(temp_output)
end

function Translator.SendRequest(text)
  text = trim(text)
  if text == "" then
    return nil, UI_TEXT.empty_input
  end
  if Translator.is_requesting then
    return nil, UI_TEXT.translation_in_progress
  end
  if trim(get_api_key()) == "" then
    return nil, UI_TEXT.api_key_empty
  end

  local ok, err = ensure_worker_files()
  if not ok then
    return nil, err
  end

  cleanup_temp_io()

  ok, err = write_file(temp_input, text)
  if not ok then
    return nil, UI_TEXT.write_request_failed .. tostring(err or "")
  end

  local cmd
  if is_windows then
    cmd = string.format('wscript //nologo "%s"', temp_launcher)
  else
    cmd = string.format('/bin/sh "%s"', temp_launcher)
  end

  if reaper.ExecProcess then
    reaper.ExecProcess(cmd, 0)
  else
    os.execute(cmd)
  end

  Translator.is_requesting = true
  Translator.request_start_time = reaper.time_precise()
  Translator.pending_text = text
  Translator.error_message = nil
  return true
end

function Translator.Poll(on_success, on_error)
  if not Translator.is_requesting then return end

  local now = reaper.time_precise()
  if now - Translator.request_start_time > 20 then
    Translator.is_requesting = false
    Translator.pending_text = nil
    Translator.error_message = UI_TEXT.translation_timeout
    cleanup_temp_io()
    if on_error then on_error(Translator.error_message) end
    return
  end

  if not file_exists(temp_output) then
    return
  end

  local content = trim(read_file(temp_output) or "")
  cleanup_temp_io()
  Translator.is_requesting = false
  Translator.pending_text = nil

  if content == "" then
    Translator.error_message = UI_TEXT.empty_translation
    if on_error then on_error(Translator.error_message) end
    return
  end

  if content == "Error" or content:match("^Error:") then
    Translator.error_message = content
    if on_error then on_error(content) end
    return
  end

  if on_success then on_success(content) end
end

local function send_search_text(text)
  local title = reaper.JS_Localize("Media Explorer", "common")
  local hwnd = reaper.JS_Window_Find(title, true)
  if not hwnd then
    return nil, UI_TEXT.missing_media_explorer
  end

  local search = reaper.JS_Window_FindChildByID(hwnd, 1015)
  if search == nil then
    return nil, UI_TEXT.missing_search_box
  end

  reaper.JS_Window_SetTitle(search, text)

  local os_name = reaper.GetOS()
  if os_name ~= "Win32" and os_name ~= "Win64" then
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
  else
    if reaper.GetToggleCommandStateEx(32063, 42051) == 1 then
      reaper.JS_WindowMessage_Send(hwnd, "WM_COMMAND", 42051, 0, 0, 0)
    end
    reaper.JS_WindowMessage_Post(search, "WM_KEYDOWN", 0x0020, 0, 0, 0)
    reaper.JS_WindowMessage_Post(search, "WM_KEYUP",   0x0008, 0, 0, 0)
  end

  return true
end

local function apply_search_text(text)
  text = sanitize_search_text(text)
  if text == "" then
    return nil, UI_TEXT.empty_keywords
  end

  reaper.SetExtState(EXT_SECTION, "last_keywords", text, false)

  reaper.Undo_BeginBlock()
  local ok, err = send_search_text(text)
  reaper.Undo_EndBlock("Media Explorer Search", -1)
  reaper.UpdateArrange()

  if not ok then
    return nil, err
  end

  return true
end

local input_text = reaper.GetExtState(EXT_SECTION, "last_input")
local translated_text = reaper.GetExtState(EXT_SECTION, "last_translation_keywords")
if translated_text == "" then
  translated_text = reaper.GetExtState(EXT_SECTION, "last_keywords")
end
local translated_synonyms = split_lines(reaper.GetExtState(EXT_SECTION, "last_synonyms"))
local last_translation_source = ""
local status_text = UI_TEXT.dependency_hint
local should_close = false
local pending_send_current_after_shortcut = false
local input_clear_serial = 0

local function store_input_text()
  reaper.SetExtState(EXT_SECTION, "last_input", input_text or "", true)
end

local function is_alt_down()
  if reaper.ImGui_Key_LeftAlt and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftAlt()) then
    return true
  end
  if reaper.ImGui_Key_RightAlt and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightAlt()) then
    return true
  end
  return reaper.ImGui_Mod_Alt and reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt())
end

local function store_translation_state()
  reaper.SetExtState(EXT_SECTION, "last_translation_keywords", translated_text or "", false)
  reaper.SetExtState(EXT_SECTION, "last_synonyms", join_with_separator(translated_synonyms, "\n"), false)
end

local function send_all_synonyms_search()
  if #translated_synonyms == 0 then
    return nil, UI_TEXT.no_synonyms
  end
  return apply_search_text(table.concat(translated_synonyms, " OR "))
end

local function begin_translation()
  last_translation_source = trim(input_text)
  local ok, err = Translator.SendRequest(input_text)
  if not ok then
    status_text = tostring(err or UI_TEXT.start_translation_failed)
    return
  end
end

local function send_current_input()
  local clean_input = sanitize_search_text(input_text)
  local ok, err = apply_search_text(clean_input)
  if ok then
    input_text = clean_input
    store_input_text()
    translated_text = clean_input
    translated_synonyms = {}
    store_translation_state()
    status_text = UI_TEXT.current_sent
  else
    status_text = tostring(err or UI_TEXT.current_send_failed)
  end
end

local function shortcut_keys_released()
  return not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl())
    and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_Enter())
    and not reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_KeypadEnter())
end

local function on_translate_success(result)
  local allow_synonyms = supports_synonyms_for_input(last_translation_source)
  translated_text, translated_synonyms = parse_translation_payload(result)
  if not allow_synonyms then
    translated_synonyms = {}
  end
  input_text = translated_text
  store_input_text()
  store_translation_state()
  local ok, err = apply_search_text(translated_text)
  if ok then
    if allow_synonyms then
      status_text = UI_TEXT.translated_sent
    else
      status_text = UI_TEXT.translated_sent_no_synonyms
    end
  else
    status_text = tostring(err or UI_TEXT.search_send_failed)
  end
end

local function on_translate_error(err)
  status_text = tostring(err or UI_TEXT.translation_failed)
end

function draw_ui()
  reaper.ImGui_SetNextWindowSize(ctx, 530, 155, reaper.ImGui_Cond_FirstUseEver())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), WINDOW_ROUNDING)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), TITLE_BG_COLOR)
  local visible, open = reaper.ImGui_Begin(ctx, SCRIPT_NAME, true, reaper.ImGui_WindowFlags_NoCollapse())
  reaper.ImGui_PopStyleVar(ctx)

  if visible then
    reaper.ImGui_PushFont(ctx, font, 14)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), FRAME_ROUNDING)
    -- reaper.ImGui_TextWrapped(ctx, UI_TEXT.input_help)
    -- reaper.ImGui_Spacing(ctx)

    local input_hint = Translator.is_requesting and UI_TEXT.translating or ""
    reaper.ImGui_SetNextItemWidth(ctx, -FLT_MIN)
    local changed
    changed, input_text = reaper.ImGui_InputText(ctx, "##keywords" .. input_clear_serial, input_text or "")
    local input_is_active = reaper.ImGui_IsItemActive(ctx)
    local input_is_focused = reaper.ImGui_IsItemFocused(ctx)
    local input_is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local input_is_clicked = reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left())
    if changed then
      local clean_input = sanitize_search_text(input_text)
      if clean_input ~= input_text then
        input_text = clean_input
      end
      store_input_text()
    end
    if input_is_hovered and input_is_clicked and is_alt_down() then
      input_text = ""
      input_clear_serial = input_clear_serial + 1
      store_input_text()
    end

    if input_hint ~= "" then
      local rect_min_x, rect_min_y = reaper.ImGui_GetItemRectMin(ctx)
      local rect_max_x, rect_max_y = reaper.ImGui_GetItemRectMax(ctx)
      local hint_width, hint_height = reaper.ImGui_CalcTextSize(ctx, input_hint)
      local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
      local text_x = rect_max_x - hint_width - 10
      local text_y = rect_min_y + math.max(0, ((rect_max_y - rect_min_y) - hint_height) * 0.5)
      local text_color = reaper.ImGui_GetColor(ctx, reaper.ImGui_Col_TextDisabled())
      reaper.ImGui_DrawList_AddText(draw_list, text_x, text_y, text_color, input_hint)
    end

    if (input_is_active or input_is_focused)
      and (reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) or reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter())) then
      if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) then
        pending_send_current_after_shortcut = true
      else
        begin_translation()
      end
    end

    if pending_send_current_after_shortcut and shortcut_keys_released() then
      pending_send_current_after_shortcut = false
      send_current_input()
    end

    -- reaper.ImGui_Spacing(ctx)

    -- if translated_text ~= "" then
    --   reaper.ImGui_TextWrapped(ctx, "Current English keywords: " .. translated_text)
    -- end

    --if #translated_synonyms > 0 then
      reaper.ImGui_Spacing(ctx)
      -- reaper.ImGui_TextWrapped(ctx, UI_TEXT.synonyms)
      local synonym_button_height = 24
      local synonym_row_width = reaper.ImGui_GetContentRegionAvail(ctx)
      local synonym_line_width = 0
      local synonym_item_spacing = ({ reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()) })[1] or 8
      local synonym_frame_padding = ({ reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding()) })[1] or 4

      local function place_synonym_button(label)
        local text_width = reaper.ImGui_CalcTextSize(ctx, label)
        local button_width = text_width + synonym_frame_padding * 2
        if synonym_line_width > 0 then
          if synonym_line_width + synonym_item_spacing + button_width <= synonym_row_width then
            reaper.ImGui_SameLine(ctx)
            synonym_line_width = synonym_line_width + synonym_item_spacing
          else
            synonym_line_width = 0
          end
        end
        synonym_line_width = synonym_line_width + button_width
      end

      for i = 1, #translated_synonyms do
        local synonym = translated_synonyms[i]
        place_synonym_button(synonym)
        if reaper.ImGui_Button(ctx, synonym, 0) then
          local ok, err = apply_search_text(synonym)
          if ok then
            status_text = UI_TEXT.synonym_sent_prefix .. synonym
          else
            status_text = tostring(err or UI_TEXT.synonym_send_failed)
          end
        end
      end

      place_synonym_button(UI_TEXT.search_all_terms)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x2E6F57FF)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x3D8A6EFF)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x245A47FF)
      if reaper.ImGui_Button(ctx, UI_TEXT.search_all_terms, 0, synonym_button_height) then
        local ok, err = send_all_synonyms_search()
        if ok then
          status_text = UI_TEXT.all_terms_sent
        else
          status_text = tostring(err or UI_TEXT.all_terms_send_failed)
        end
      end
      reaper.ImGui_PopStyleColor(ctx, 3)
    --end

    if status_text ~= "" then
      -- reaper.ImGui_Spacing(ctx)
      reaper.ImGui_TextWrapped(ctx, status_text)
    end

    reaper.ImGui_Spacing(ctx)
    local button_row_width = reaper.ImGui_GetContentRegionAvail(ctx)
    local button_width = math.max(1, (button_row_width - 16) / 3)

    if reaper.ImGui_Button(ctx, UI_TEXT.button_translate, button_width, 28) then
      begin_translation()
    end

    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, UI_TEXT.button_send_current, button_width, 28) then
      send_current_input()
    end

    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, UI_TEXT.button_close, button_width, 28) then
      should_close = true
    end

    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_PopFont(ctx)
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopStyleColor(ctx)

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
    should_close = true
  end

  if not open then
    should_close = true
  end
end

function loop()
  Translator.Poll(on_translate_success, on_translate_error)
  draw_ui()
  if not should_close then
    reaper.defer(loop)
  else
    store_input_text()
    cleanup_temp_io()
  end
end

reaper.defer(loop)
