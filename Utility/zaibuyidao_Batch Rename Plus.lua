-- @description Batch Rename Plus
-- @version 1.0.22
-- @author zaibuyidao
-- @changelog
--   Changed Replace mode to "Match case", defaulting to case-insensitive matching.
-- @links
--   https://www.soundengine.cn/u/zaibuyidao
--   https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires JS_ReaScriptAPI & SWS Extension

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

-- Check for ReaImGui dependency
if not reaper.ImGui_GetBuiltinPath then
  if reaper.APIExists('ReaPack_BrowsePackages') then
    reaper.ReaPack_BrowsePackages('ReaImGui: ReaScript binding for Dear ImGui')
    reaper.MB(
      "ReaImGui is not installed or is out of date.\n\n" ..
      "The ReaPack package browser has been opened. Please search for 'ReaImGui' and install or update it before running this script.",
      "Batch Rename Plus", 0)
  else
    local reapackErrorMsg = 
      "ReaPack is not installed.\n\n" ..
      "To use this script, please install ReaPack first:\n" ..
      "https://reapack.com\n\n" ..
      "After installing ReaPack, use it to install 'ReaImGui: ReaScript binding for Dear ImGui'."
    reaper.MB(reapackErrorMsg, "ReaPack Not Found", 0)
  end
  return
end

local ImGui
if reaper.ImGui_GetBuiltinPath then
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  ImGui = require 'imgui' '0.9'
end

local TEXT = {
  zh_CN = {
    title = "Batch Rename Plus",
    window_title = "Batch Rename Plus - REAPER 可扩展批量重命名",
    error = "错误",
    ok = "确定",
    cancel = "取消",
    items = "媒体对象",
    tracks = "轨道",
    regions = "区域",
    markers = "标记",
    source_files = "源文件",
    media = "媒体",
    manager = "管理器",
    time_selection = "时间选区",
    selected_regions = "选中的区域",
    selected_items = "选中的媒体对象",
    selected_markers = "选中的标记",
    batch_items = "媒体对象",
    batch_tracks = "轨道",
    batch_regions_manager = "区域 / 管理器",
    batch_regions_time = "区域 / 时间选区",
    batch_regions_selected = "区域 / 选中的区域",
    batch_regions_items = "区域 / 选中的媒体对象",
    batch_markers_manager = "标记 / 管理器",
    batch_markers_selected = "标记 / 选中的标记",
    batch_markers_time = "标记 / 时间选区",
    batch_sources_items = "源文件 / 选中的媒体对象",
    tip_items = "提示: 在编排视图中选择媒体对象。",
    tip_tracks = "提示: 在轨道控制面板中选择轨道。",
    tip_regions_manager = "提示: 打开区域/标记管理器并选择区域。",
    tip_regions_time = "提示: 在编排视图中拖拽创建用于区域的时间选区。",
    tip_regions_selected = "提示: 在编排标尺中选择区域。",
    tip_regions_items = "提示: 在编排视图中选择媒体对象，以定位其所在区域。",
    tip_markers_manager = "提示: 打开区域/标记管理器并选择标记。",
    tip_markers_selected = "提示: 在编排标尺中选择标记。",
    tip_markers_time = "提示: 在编排视图中拖拽创建用于标记的时间选区。",
    tip_sources_items = "提示: 在编排视图中选择带有源文件的媒体对象。",
    save_preset = "保存预设",
    rename_preset = "重命名预设",
    save_preset_title = "输入新预设名称: ",
    rename_preset_title = "输入预设的新名称: ",
    no_preset = "无预设",
    reset_factory = "重置为出厂默认值",
    save_preset_menu = "保存预设...",
    delete_preset = "删除预设",
    rename_preset_menu = "重命名预设...",
    export_presets = "导出预设",
    import_presets = "导入预设",
    text_files_filter = "文本文件 (*.txt)\0*.txt\0所有文件\0*.*\0",
    failed_open_write = "无法打开文件写入: \n%s",
    failed_open_read = "无法打开文件读取: \n%s",
    exported_presets = "已导出 %d 个预设到: \n%s",
    imported_presets = "已从以下文件导入 %d 个预设: \n%s",
    preview_objects = "预览 - %d 个对象",
    compare_objects = "比较 - %d 个对象",
    resize = "调整大小",
    horizontal_scroll = "水平滚动",
    vertical_scroll = "垂直滚动",
    before = "之前",
    after = "之后",
    message = "消息",
    index = "序号",
    item_name = "媒体对象名称",
    source_name = "源文件名称",
    empty_name = "错误: 名称为空。",
    empty_slot = "空槽位。",
    random_preview = "随机(%s)",
    counts_status = "%d 个错误，%d 个重复。",
    mode = "模式",
    copy_cell_help = "按住 Ctrl 并左键单击可复制单元格内容。\n",
    filter = "筛选: ",
    compare = "比较",
    preview = "预览",
    options = "选项",
    interface = "界面",
    language = "界面语言",
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",
    preview_options = "预览",
    support = "支持",
    support_text_1 = "这个工具是免费且开源的，并且会一直如此。",
    support_text_2 = "不过如果你愿意捐赠支持，我会非常感谢。",
    visit_soundengine = "访问 soundengine.cn",
    close = "关闭",
    popup_table_font_size = "弹窗表格字号",
    show_main_preview_table = "显示主预览表格",
    show_help_markers = "显示帮助提示",
    save_and_close = "保存并关闭",
    reset = "重置",
    no_items_selected_compare = "未选择媒体对象。\n请至少选择一个媒体对象。",
    different_same = "相同: %s",
    different = "不同",
    copy_table = "复制表格",
    copy_items = "复制对象",
    copy_sources = "复制源文件",
    refresh = "刷新",
    apply_to = "应用到",
    target = "目标",
    choose_target_help = "选择 Batch Rename Plus 要重命名的对象。\n\n区域和标记会按选择方式分组: 管理器、时间选区、编排视图选择，或选中的媒体对象。",
    settings = "设置",
    example = "示例: ",
    rename = "重命名",
    replace = "替换",
    remove = "删除",
    insert = "插入",
    wildcards = "通配符",
    specifiers = "格式符",
    pattern = "模式",
    find_what = "查找内容",
    replace_with = "替换为",
    match_case = "匹配大小写",
    use_regular_expression = "使用正则表达式",
    regex_help = "勾选后，“查找内容”会按 Wwise/ECMAScript 风格的正则表达式匹配；“替换为”可以使用捕获组。\n\n常用写法:\n. 匹配任意单个字符\n\\d 匹配数字，\\D 匹配非数字\n\\w 匹配字母、数字或下划线，\\W 匹配其它字符\n\\s 匹配空格、Tab、换行等空白字符\n^ 匹配名称开头，$ 匹配名称结尾\n[ABC] 匹配 A、B 或 C；[A-Z] 匹配 A 到 Z\n[^0-9] 匹配不是数字的字符\n* 表示 0 次或更多，+ 表示 1 次或更多，? 表示 0 次或 1 次\n{3} 表示正好 3 次，{2,4} 表示 2 到 4 次\n( ) 创建捕获组；(?: ) 创建不编号的分组\n| 表示“或者”，例如 cat|dog\n\\b 匹配单词边界\n\n替换引用:\n$1、$2 使用第 1、第 2 个捕获组\n$& 使用整个匹配内容\n$` 使用匹配前面的内容\n$' 使用匹配后面的内容\n$+ 使用最后一个捕获组\n$$ 输入一个普通的 $ 符号\n\n入门示例:\n1. 去掉名称末尾编号\n查找内容: _\\d+$\n替换为: 留空\n示例: Amb_Rain_001 -> Amb_Rain\n\n2. 把空格和横线统一成下划线\n查找内容: [\\s-]+\n替换为: _\n示例: Footstep Wood-01 -> Footstep_Wood_01\n\n3. 交换两个用下划线分隔的部分\n查找内容: ^(.*)_(.*)$\n替换为: $2_$1\n示例: Door_Open -> Open_Door\n\n4. 只保留括号里的文字\n查找内容: ^.*\\((.*)\\).*$\n替换为: $1\n示例: Explosion (Large) -> Large\n\n小提示: 如果要匹配 .、(、)、[、]、+、*、?、$ 这些符号本身，请在前面加反斜杠，例如 \\. 表示真正的点号。",
    occurrence = "出现位置",
    first = "首次",
    last = "末次",
    all = "全部",
    count = "数量",
    at_position = "位置",
    at_position_insert = "位置",
    from = "从",
    from_insert = "从",
    beginning = "开头",
    ending = "结尾",
    to_insert = "插入内容",
    behavior = "行为",
    range_cycle = "范围循环",
    match_src = "匹配源",
    sort_by = "排序方式",
    track = "轨道",
    sequence = "顺序",
    timeline = "时间线",
    open_region_marker_manager = "打开区域/标记管理器",
    clear = "清空",
    rename_all = "全部重命名",
    rename_all_display = "全部重命名",
    wildcard_help = "媒体对象通配符: \n$item 表示媒体对象名称，$track 表示轨道名称，$tracknumber 表示轨道编号，$folders 表示轨道文件夹，$GUID 表示唯一标识符。\n\n轨道通配符: \n$track 表示轨道名称，$tracknumber 表示轨道编号，$folders 表示轨道文件夹，$GUID 表示唯一标识符。\n\n源文件通配符: \n$source 表示源文件名，$track 表示轨道名称，$tracknumber 表示轨道编号，$folders 表示轨道文件夹。\n\n通用标签: d=n 表示数字递增，d=start-end 表示数字循环，a=c 表示字母递增，a=start-end 表示字母循环，r=n 表示随机字符串。\n\n模式: 重命名、替换、删除或插入。启用循环模式后，数字或字母会循环。排序选项: 轨道、顺序或时间线。",
    slider_help = "按住 Alt 拖动滑块可进行更细微的调整。\n\n如需超精细控制，请按住 Alt + Shift 拖动。\n\n要输入指定数值，请按住 Ctrl 并左键单击滑块后输入。",
    range_cycle_help = "启用循环模式后，字母或数字会在指定范围内连续循环。\n\n例如，'a=A-C' 会按 A - B - C - A - ... 循环，'d=1-3' 会按 1 - 2 - 3 - 1 - ... 循环。\n你也可以指定反向范围，例如 'a=Z-X' 或 'd=9-7'，用于降序循环。",
    match_src_help = "启用后，重命名源文件时也会把媒体对象/Take 名称更新为新的源文件名。\n\n关闭后，只重命名源文件，媒体对象/Take 名称保持不变。",
    rename_all_help = "按 Ctrl+Enter 可立即执行“全部重命名”。",
    no_media_items_selected = "未选择媒体对象。",
    no_tracks_selected = "未选择轨道。",
    no_options_selected = "未选择任何功能。请至少勾选一个功能。",
    no_changes = "未应用任何更改。请调整设置。",
    open_region_marker_manager_msg = "请先打开区域/标记管理器窗口。\n\n菜单路径: 视图 - 区域/标记管理器",
    no_regions_manager = "区域/标记管理器中未选择区域。",
    no_time_selection = "没有时间选区。",
    no_regions_time = "时间选区内未找到区域。",
    no_regions_arrange = "编排视图中未选择区域。",
    no_regions_items = "未找到选中媒体对象所在的区域。",
    no_markers_manager = "区域/标记管理器中未选择标记。",
    no_markers_arrange = "编排视图中未选择标记。",
    no_markers_time = "时间选区内未找到标记。",
    selected_region_marker_requires_newer = "选中的区域/标记需要 REAPER 7.73 或更新版本。",
    selected_items_no_audio = "选中的媒体对象没有音频源或均为 MIDI！",
    no_valid_source_files = "选中的媒体对象没有有效的音频源文件。",
    undo_batch = "Batch Rename Plus",
    undo_no_changes = "Batch Rename Plus (无更改)",
    undo_no_source_files = "Batch Rename Plus (无源文件)",
    renaming_errors_header = "\n---- 重命名已完成，但发生以下错误: ----\n",
    does_not_exist = "不存在: %s",
    failed_rename = "失败: %s <--> %s (%s)",
    unknown = "未知"
  },
  zh_TW = {
    title = "Batch Rename Plus",
    window_title = "Batch Rename Plus - REAPER 可擴充批次重新命名",
    error = "錯誤",
    ok = "確定",
    cancel = "取消",
    items = "媒體物件",
    tracks = "軌道",
    regions = "區域",
    markers = "標記",
    source_files = "來源檔案",
    media = "媒體",
    manager = "管理器",
    time_selection = "時間選取",
    selected_regions = "選取的區域",
    selected_items = "選取的媒體物件",
    selected_markers = "選取的標記",
    batch_items = "媒體物件",
    batch_tracks = "軌道",
    batch_regions_manager = "區域 / 管理器",
    batch_regions_time = "區域 / 時間選取",
    batch_regions_selected = "區域 / 選取的區域",
    batch_regions_items = "區域 / 選取的媒體物件",
    batch_markers_manager = "標記 / 管理器",
    batch_markers_selected = "標記 / 選取的標記",
    batch_markers_time = "標記 / 時間選取",
    batch_sources_items = "來源檔案 / 選取的媒體物件",
    tip_items = "提示: 在編曲視圖中選取媒體物件。",
    tip_tracks = "提示: 在軌道控制面板中選取軌道。",
    tip_regions_manager = "提示: 開啟區域/標記管理器並選取區域。",
    tip_regions_time = "提示: 在編曲視圖中拖曳建立用於區域的時間選取。",
    tip_regions_selected = "提示: 在編曲標尺中選取區域。",
    tip_regions_items = "提示: 在編曲視圖中選取媒體物件，以定位其所在區域。",
    tip_markers_manager = "提示: 開啟區域/標記管理器並選取標記。",
    tip_markers_selected = "提示: 在編曲標尺中選取標記。",
    tip_markers_time = "提示: 在編曲視圖中拖曳建立用於標記的時間選取。",
    tip_sources_items = "提示: 在編曲視圖中選取帶有來源檔案的媒體物件。",
    save_preset = "儲存預設",
    rename_preset = "重新命名預設",
    save_preset_title = "輸入新預設名稱: ",
    rename_preset_title = "輸入預設的新名稱: ",
    no_preset = "無預設",
    reset_factory = "重設為出廠預設",
    save_preset_menu = "儲存預設...",
    delete_preset = "刪除預設",
    rename_preset_menu = "重新命名預設...",
    export_presets = "匯出預設",
    import_presets = "匯入預設",
    text_files_filter = "文字檔案 (*.txt)\0*.txt\0所有檔案\0*.*\0",
    failed_open_write = "無法開啟檔案寫入: \n%s",
    failed_open_read = "無法開啟檔案讀取: \n%s",
    exported_presets = "已匯出 %d 個預設到: \n%s",
    imported_presets = "已從以下檔案匯入 %d 個預設: \n%s",
    preview_objects = "預覽 - %d 個物件",
    compare_objects = "比較 - %d 個物件",
    resize = "調整大小",
    horizontal_scroll = "水平捲動",
    vertical_scroll = "垂直捲動",
    before = "之前",
    after = "之後",
    message = "訊息",
    index = "序號",
    item_name = "媒體物件名稱",
    source_name = "來源檔案名稱",
    empty_name = "錯誤: 名稱為空。",
    empty_slot = "空白欄位。",
    random_preview = "隨機(%s)",
    counts_status = "%d 個錯誤，%d 個重複。",
    mode = "模式",
    copy_cell_help = "按住 Ctrl 並左鍵點擊可複製儲存格內容。\n",
    filter = "篩選: ",
    compare = "比較",
    preview = "預覽",
    options = "選項",
    interface = "介面",
    language = "介面語言",
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",
    preview_options = "預覽",
    support = "支持",
    support_text_1 = "這個工具是免費且開源的，並且會一直如此。",
    support_text_2 = "不過如果你願意捐贈支持，我會非常感謝。",
    visit_soundengine = "造訪 soundengine.cn",
    close = "關閉",
    popup_table_font_size = "彈窗表格字號",
    show_main_preview_table = "顯示主預覽表格",
    show_help_markers = "顯示說明提示",
    save_and_close = "儲存並關閉",
    reset = "重設",
    no_items_selected_compare = "未選取媒體物件。\n請至少選取一個媒體物件。",
    different_same = "相同: %s",
    different = "不同",
    copy_table = "複製表格",
    copy_items = "複製物件",
    copy_sources = "複製來源",
    refresh = "重新整理",
    apply_to = "套用到",
    target = "目標",
    choose_target_help = "選擇 Batch Rename Plus 要重新命名的物件。\n\n區域和標記會依選取方式分組: 管理器、時間選取、編曲視圖選取，或選取的媒體物件。",
    settings = "設定",
    example = "範例: ",
    rename = "重新命名",
    replace = "取代",
    remove = "刪除",
    insert = "插入",
    wildcards = "萬用字元",
    specifiers = "格式符",
    pattern = "模式",
    find_what = "尋找內容",
    replace_with = "取代為",
    match_case = "匹配大小寫",
    use_regular_expression = "使用正則表達式",
    regex_help = "勾選後，「尋找內容」會按 Wwise/ECMAScript 風格的正則表達式匹配；「取代為」可以使用捕獲組。\n\n常用寫法:\n. 匹配任意單個字元\n\\d 匹配數字，\\D 匹配非數字\n\\w 匹配字母、數字或底線，\\W 匹配其它字元\n\\s 匹配空格、Tab、換行等空白字元\n^ 匹配名稱開頭，$ 匹配名稱結尾\n[ABC] 匹配 A、B 或 C；[A-Z] 匹配 A 到 Z\n[^0-9] 匹配不是數字的字元\n* 表示 0 次或更多，+ 表示 1 次或更多，? 表示 0 次或 1 次\n{3} 表示正好 3 次，{2,4} 表示 2 到 4 次\n( ) 建立捕獲組；(?: ) 建立不編號的分組\n| 表示「或者」，例如 cat|dog\n\\b 匹配單字邊界\n\n取代引用:\n$1、$2 使用第 1、第 2 個捕獲組\n$& 使用整個匹配內容\n$` 使用匹配前面的內容\n$' 使用匹配後面的內容\n$+ 使用最後一個捕獲組\n$$ 輸入一個普通的 $ 符號\n\n入門範例:\n1. 去掉名稱結尾編號\n尋找內容: _\\d+$\n取代為: 留空\n範例: Amb_Rain_001 -> Amb_Rain\n\n2. 把空格和橫線統一成底線\n尋找內容: [\\s-]+\n取代為: _\n範例: Footstep Wood-01 -> Footstep_Wood_01\n\n3. 交換兩個用底線分隔的部分\n尋找內容: ^(.*)_(.*)$\n取代為: $2_$1\n範例: Door_Open -> Open_Door\n\n4. 只保留括號裡的文字\n尋找內容: ^.*\\((.*)\\).*$\n取代為: $1\n範例: Explosion (Large) -> Large\n\n小提示: 如果要匹配 .、(、)、[、]、+、*、?、$ 這些符號本身，請在前面加反斜線，例如 \\. 表示真正的點號。",
    occurrence = "出現位置",
    first = "首次",
    last = "末次",
    all = "全部",
    count = "數量",
    at_position = "位置",
    at_position_insert = "位置",
    from = "從",
    from_insert = "從",
    beginning = "開頭",
    ending = "結尾",
    to_insert = "插入內容",
    behavior = "行為",
    range_cycle = "範圍循環",
    match_src = "符合來源",
    sort_by = "排序方式",
    track = "軌道",
    sequence = "順序",
    timeline = "時間線",
    open_region_marker_manager = "開啟區域/標記管理器",
    clear = "清空",
    rename_all = "全部重新命名",
    rename_all_display = "全部重新命名",
    wildcard_help = "媒體物件萬用字元: \n$item 表示媒體物件名稱，$track 表示軌道名稱，$tracknumber 表示軌道編號，$folders 表示軌道資料夾，$GUID 表示唯一識別碼。\n\n軌道萬用字元: \n$track 表示軌道名稱，$tracknumber 表示軌道編號，$folders 表示軌道資料夾，$GUID 表示唯一識別碼。\n\n來源檔案萬用字元: \n$source 表示來源檔名，$track 表示軌道名稱，$tracknumber 表示軌道編號，$folders 表示軌道資料夾。\n\n通用標籤: d=n 表示數字遞增，d=start-end 表示數字循環，a=c 表示字母遞增，a=start-end 表示字母循環，r=n 表示隨機字串。\n\n模式: 重新命名、取代、刪除或插入。啟用循環模式後，數字或字母會循環。排序選項: 軌道、順序或時間線。",
    slider_help = "按住 Alt 拖曳滑桿可進行更細微的調整。\n\n如需超精細控制，請按住 Alt + Shift 拖曳。\n\n要輸入指定數值，請按住 Ctrl 並左鍵點擊滑桿後輸入。",
    range_cycle_help = "啟用循環模式後，字母或數字會在指定範圍內連續循環。\n\n例如，'a=A-C' 會按 A - B - C - A - ... 循環，'d=1-3' 會按 1 - 2 - 3 - 1 - ... 循環。\n你也可以指定反向範圍，例如 'a=Z-X' 或 'd=9-7'，用於降序循環。",
    match_src_help = "啟用後，重新命名來源檔案時也會把媒體物件/Take 名稱更新為新的來源檔名。\n\n關閉後，只重新命名來源檔案，媒體物件/Take 名稱保持不變。",
    rename_all_help = "按 Ctrl+Enter 可立即執行「全部重新命名」。",
    no_media_items_selected = "未選取媒體物件。",
    no_tracks_selected = "未選取軌道。",
    no_options_selected = "未選取任何功能。請至少勾選一個功能。",
    no_changes = "未套用任何變更。請調整設定。",
    open_region_marker_manager_msg = "請先開啟區域/標記管理器視窗。\n\n選單路徑: 檢視 - 區域/標記管理器",
    no_regions_manager = "區域/標記管理器中未選取區域。",
    no_time_selection = "沒有時間選取。",
    no_regions_time = "時間選取內未找到區域。",
    no_regions_arrange = "編曲視圖中未選取區域。",
    no_regions_items = "未找到選取媒體物件所在的區域。",
    no_markers_manager = "區域/標記管理器中未選取標記。",
    no_markers_arrange = "編曲視圖中未選取標記。",
    no_markers_time = "時間選取內未找到標記。",
    selected_region_marker_requires_newer = "選取的區域/標記需要 REAPER 7.73 或更新版本。",
    selected_items_no_audio = "選取的媒體物件沒有音訊來源或皆為 MIDI！",
    no_valid_source_files = "選取的媒體物件沒有有效的音訊來源檔案。",
    undo_batch = "Batch Rename Plus",
    undo_no_changes = "Batch Rename Plus (無變更)",
    undo_no_source_files = "Batch Rename Plus (無來源檔案)",
    renaming_errors_header = "\n---- 重新命名已完成，但發生以下錯誤: ----\n",
    does_not_exist = "不存在: %s",
    failed_rename = "失敗: %s <--> %s (%s)",
    unknown = "未知"
  },
  en = {
    title = "Batch Rename Plus",
    window_title = "Batch Rename Plus - Extensible Batch Renaming for REAPER",
    error = "Error",
    ok = "OK",
    cancel = "Cancel",
    items = "Items",
    tracks = "Tracks",
    regions = "Regions",
    markers = "Markers",
    source_files = "Source Files",
    media = "Media",
    manager = "Manager",
    time_selection = "Time Selection",
    selected_regions = "Selected Regions",
    selected_items = "Selected Items",
    selected_markers = "Selected Markers",
    batch_items = "Items",
    batch_tracks = "Tracks",
    batch_regions_manager = "Regions / Manager",
    batch_regions_time = "Regions / Time Selection",
    batch_regions_selected = "Regions / Selected Regions",
    batch_regions_items = "Regions / Selected Items",
    batch_markers_manager = "Markers / Manager",
    batch_markers_selected = "Markers / Selected Markers",
    batch_markers_time = "Markers / Time Selection",
    batch_sources_items = "Source Files / Selected Items",
    tip_items = "Tip: In the Arrange view, select your items.",
    tip_tracks = "Tip: In the Track Control Panel, select a track.",
    tip_regions_manager = "Tip: Open the Region Manager and select a region.",
    tip_regions_time = "Tip: In the Arrange view, drag to make a time selection for regions.",
    tip_regions_selected = "Tip: In the arrange ruler, select regions.",
    tip_regions_items = "Tip: Select items in the Arrange view to target their regions.",
    tip_markers_manager = "Tip: Open the Marker Manager and select a marker.",
    tip_markers_selected = "Tip: In the arrange ruler, select markers.",
    tip_markers_time = "Tip: In the Arrange view, drag to make a time selection for markers.",
    tip_sources_items = "Tip: In the Arrange view, select media items with source files.",
    save_preset = "Save Preset",
    rename_preset = "Rename Preset",
    save_preset_title = "Enter a name for the new preset:",
    rename_preset_title = "Enter a new name for the preset:",
    no_preset = "No preset",
    reset_factory = "Reset to factory default",
    save_preset_menu = "Save Preset...",
    delete_preset = "Delete Preset",
    rename_preset_menu = "Rename Preset...",
    export_presets = "Export Presets",
    import_presets = "Import Presets",
    text_files_filter = "Text Files (*.txt)\0*.txt\0All Files\0*.*\0",
    failed_open_write = "Failed to open file for writing:\n%s",
    failed_open_read = "Failed to open file for reading:\n%s",
    exported_presets = "Exported %d presets to:\n%s",
    imported_presets = "Imported %d presets from:\n%s",
    preview_objects = "Preview - %d Object(s)",
    compare_objects = "Compare - %d Object(s)",
    resize = "Resize",
    horizontal_scroll = "Horizontal Scroll",
    vertical_scroll = "Vertical Scroll",
    before = "Before",
    after = "After",
    message = "Message",
    index = "Index",
    item_name = "Item Name",
    source_name = "Source Name",
    empty_name = "Error: empty name.",
    empty_slot = "Empty slot.",
    random_preview = "random(%s)",
    counts_status = "%d error(s) detected. %d duplicate(s) detected.",
    mode = "Mode",
    copy_cell_help = "Use Ctrl+LeftClick to copy cell content\n",
    filter = "Filter:",
    compare = "Compare",
    preview = "Preview",
    options = "Options",
    interface = "Interface",
    language = "Language",
    language_english = "English",
    language_simplified_chinese = "简体中文",
    language_traditional_chinese = "繁體中文",
    preview_options = "Preview",
    support = "Support",
    support_text_1 = "This tool is free and open source. And it will always be.",
    support_text_2 = "However, I do appreciate your support via donation.",
    visit_soundengine = "Visit soundengine.cn",
    close = "Close",
    popup_table_font_size = "Popup table font size",
    show_main_preview_table = "Show main preview table",
    show_help_markers = "Show help markers",
    save_and_close = "Save and Close",
    reset = "Reset",
    no_items_selected_compare = "No items selected.\nPlease select at least one media item.",
    different_same = "Same: %s",
    different = "Different",
    copy_table = "Copy Table",
    copy_items = "Copy Items",
    copy_sources = "Copy Sources",
    refresh = "Refresh",
    apply_to = "Apply To",
    target = "Target",
    choose_target_help = "Choose what Batch Rename Plus should rename.\n\nRegions and markers are grouped by how they are selected: Manager, Time Selection, arrange-view selection, or selected items.",
    settings = "Settings",
    example = "Example:",
    rename = "Rename",
    replace = "Replace",
    remove = "Remove",
    insert = "Insert",
    wildcards = "Wildcards",
    specifiers = "Specifiers",
    pattern = "Pattern",
    find_what = "Find what",
    replace_with = "Replace with",
    match_case = "Match case",
    use_regular_expression = "Use Regular Expression",
    regex_help = "When enabled, “Find what” is matched as a Wwise/ECMAScript-style regular expression. “Replace with” can use capture groups.\n\nCommon patterns:\n. matches any single character\n\\d matches a digit, \\D matches a non-digit\n\\w matches a letter, digit, or underscore; \\W matches anything else\n\\s matches whitespace such as space, Tab, or newline\n^ matches the start of the name, $ matches the end\n[ABC] matches A, B, or C; [A-Z] matches A through Z\n[^0-9] matches any character that is not a digit\n* means 0 or more, + means 1 or more, ? means 0 or 1\n{3} means exactly 3 times, {2,4} means 2 to 4 times\n( ) creates a capture group; (?: ) creates an unnumbered group\n| means “or”, for example cat|dog\n\\b matches a word boundary\n\nReplacement references:\n$1, $2 use capture group 1 or 2\n$& uses the whole match\n$` uses the text before the match\n$' uses the text after the match\n$+ uses the last captured group\n$$ inserts a plain $ character\n\nBeginner examples:\n1. Remove a trailing number\nFind what: _\\d+$\nReplace with: leave empty\nExample: Amb_Rain_001 -> Amb_Rain\n\n2. Turn spaces and hyphens into underscores\nFind what: [\\s-]+\nReplace with: _\nExample: Footstep Wood-01 -> Footstep_Wood_01\n\n3. Swap two underscore-separated parts\nFind what: ^(.*)_(.*)$\nReplace with: $2_$1\nExample: Door_Open -> Open_Door\n\n4. Keep only text inside parentheses\nFind what: ^.*\\((.*)\\).*$\nReplace with: $1\nExample: Explosion (Large) -> Large\n\nTip: To match punctuation such as ., (, ), [, ], +, *, ?, or $ literally, put a backslash before it. For example, \\. matches a real dot.",
    occurrence = "Occurrence",
    first = "First",
    last = "Last",
    all = "All",
    count = "Count",
    at_position = "At position",
    at_position_insert = "At position",
    from = "From",
    from_insert = "From",
    beginning = "Beginning",
    ending = "End",
    to_insert = "To insert",
    behavior = "Behavior",
    range_cycle = "Range Cycle",
    match_src = "Match Src",
    sort_by = "Sort by",
    track = "Track",
    sequence = "Sequence",
    timeline = "Timeline",
    open_region_marker_manager = "Open Region/Marker Manager",
    clear = "Clear",
    rename_all = "Rename All",
    rename_all_display = "Rename All",
    wildcard_help = "Items wildcards: \n$item for item name, $track for track name, $tracknumber for track number, $folders for track folder, $GUID for unique identifier.\n\nTracks wildcards: \n$track for track name, $tracknumber for track number, $folders for track folder, $GUID for unique identifier.\n\nSource Files wildcards: \n$source for source file name, $track for track name, $tracknumber for track number, $folders for track folder.\n\nGeneral tags: d=n for number increment, d=start-end for number cycle, a=c for letter increment, a=start-end for letter cycle, r=n for random string.\n\nModes: rename, replace, remove or insert. Enable cycle mode to loop numbers or letters. Sorting options: track, sequential or timeline.",
    slider_help = "Hold Alt and drag the slider to make finer adjustments.\n\nFor ultra-precise control, hold Alt + Shift while dragging.\n\nTo enter a specific value, Ctrl + Left-click the slider and type it in.",
    range_cycle_help = "Enable Cycle Mode to continuously loop letters or numbers within a specified range.\n\nFor example, 'a=A-C' will cycle A - B - C - A - ..., and 'd=1-3' will cycle 1 - 2 - 3 - 1 - ...,\nYou can also specify a reverse range like 'a=Z-X' or 'd=9-7' to cycle in descending order.",
    match_src_help = "When enabled, source-file renames also update item/take names to the new source filename.\n\nDisable it to keep item/take names unchanged while only renaming source files.",
    rename_all_help = "Press Ctrl+Enter to instantly perform the “Rename All” action.",
    no_media_items_selected = "No media items selected.",
    no_tracks_selected = "No tracks selected.",
    no_options_selected = "No options selected - please check at least one feature.",
    no_changes = "No changes applied - please adjust settings.",
    open_region_marker_manager_msg = "Please open the Region/Marker Manager window first.\n\nIn the menu bar, go to: View - Region/marker manager",
    no_regions_manager = "No regions selected in Region Manager.",
    no_time_selection = "No time selection.",
    no_regions_time = "No regions found in time selection.",
    no_regions_arrange = "No regions selected in arrange view.",
    no_regions_items = "No regions found for selected items.",
    no_markers_manager = "No markers selected in Marker Manager.",
    no_markers_arrange = "No markers selected in arrange view.",
    no_markers_time = "No markers found in time selection.",
    selected_region_marker_requires_newer = "Selected regions/markers require REAPER 7.73 or newer.",
    selected_items_no_audio = "Selected media items have no audio source or are all MIDI!",
    no_valid_source_files = "Selected media items have no valid audio source files.",
    undo_batch = "Batch Rename Plus",
    undo_no_changes = "Batch Rename Plus (no changes)",
    undo_no_source_files = "Batch Rename Plus (no source files)",
    renaming_errors_header = "\n---- Renaming completed, the following errors occurred: ----\n",
    does_not_exist = "Does not exist: %s",
    failed_rename = "Failed: %s <--> %s (%s)",
    unknown = "Unknown"
  }
}

local EXT_SECTION = "BatchRenamePlus"

local LANGUAGE_EXT_KEY = "Language"
local LANGUAGE_DEFAULT = "en"
local LANGUAGE_OPTIONS = {
  { id = "en",    label_key = "language_english" },
  { id = "zh_CN", label_key = "language_simplified_chinese" },
  { id = "zh_TW", label_key = "language_traditional_chinese" },
}
local LANGUAGE_ALIASES = {
  English = "en",
  ["简体中文"] = "zh_CN",
  ["繁體中文"] = "zh_TW",
}

local language = LANGUAGE_DEFAULT
local T = TEXT[LANGUAGE_DEFAULT]
local TITLE = T.title

function fill_missing_translation_keys()
  for lang_id, lang_table in pairs(TEXT) do
    if lang_id ~= LANGUAGE_DEFAULT then
      for key, value in pairs(TEXT[LANGUAGE_DEFAULT]) do
        if lang_table[key] == nil then
          lang_table[key] = value
        end
      end
    end
  end
end

fill_missing_translation_keys()

function stable_label(label, stable_id)
  return tostring(label or "") .. "###" .. tostring(stable_id)
end

function display_label(label)
  return tostring(label or ""):gsub("###.*$", ""):gsub("##.*$", "")
end

function normalize_language(value)
  value = tostring(value or "")
  value = LANGUAGE_ALIASES[value] or value
  if TEXT[value] then return value end
  return LANGUAGE_DEFAULT
end

function set_language(value, persist)
  language = normalize_language(value)
  T = TEXT[language] or TEXT[LANGUAGE_DEFAULT]
  TITLE = T.title
  if persist then
    reaper.SetExtState(EXT_SECTION, LANGUAGE_EXT_KEY, language, true)
  end
end

local stored_language = reaper.GetExtState(EXT_SECTION, LANGUAGE_EXT_KEY)
set_language(stored_language, false)
if stored_language ~= "" and stored_language ~= language then
  reaper.SetExtState(EXT_SECTION, LANGUAGE_EXT_KEY, language, true)
end

function tr(key, ...)
  local text = T[key] or TEXT[LANGUAGE_DEFAULT][key] or tostring(key)
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end

function ui_label(key, stable_id, ...)
  return stable_label(display_label(tr(key, ...)), stable_id or key)
end

function get_language_label(value)
  local normalized = normalize_language(value)
  for _, opt in ipairs(LANGUAGE_OPTIONS) do
    if opt.id == normalized then
      return tr(opt.label_key)
    end
  end
  return tr("language_english")
end

local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
local ctx = reaper.ImGui_CreateContext(TITLE)
local sans_serif = reaper.ImGui_CreateFont('sans-serif', 14)
local font_large = reaper.ImGui_CreateFont("", 20)
local font_medium = reaper.ImGui_CreateFont("", 14)
local font_botton = reaper.ImGui_CreateFont("", 16)
local font_small = reaper.ImGui_CreateFont("", 12)

reaper.ImGui_Attach(ctx, sans_serif)
reaper.ImGui_Attach(ctx, font_large)
reaper.ImGui_Attach(ctx, font_medium)
reaper.ImGui_Attach(ctx, font_botton)
reaper.ImGui_Attach(ctx, font_small)

local preview_font_size  = 14 -- 当前预览字体大小 (像素)
local preview_font_sizes = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 }
local preview_fonts      = {}
for _, sz in ipairs(preview_font_sizes) do
  preview_fonts[sz] = reaper.ImGui_CreateFont("", sz)
  reaper.ImGui_Attach(ctx, preview_fonts[sz])
end

-- 设置菜单
local show_main_preview  = true -- 是否显示主脚本的表格预览
local show_help_markers  = true -- 是否显示help_marker

reaper.ImGui_SetNextWindowSize(ctx, 365, 800, reaper.ImGui_Cond_FirstUseEver())

-- 状态变量
local process_mode           = 0                     -- 0 = Items, 1 = Tracks, ... 9 = Source Files
local enable_rename          = false                 -- true = enable rename
local enable_replace         = false                 -- true = enable rename
local enable_remove          = false                 -- true = enable rename
local enable_insert          = false                 -- true = enable rename
local rename_pattern         = ""                    -- pattern input
local find_text              = ""                    -- find string
local replace_text           = ""                    -- replace string
local remove_count           = 0                     -- number of chars to remove
local remove_position        = 0                     -- position for removal
local remove_side_index      = 0                     -- 0 = beginning, 1 = end
local insert_text            = ""                    -- text to insert
local insert_position        = 0                     -- position for insertion
local insert_side_index      = 0                     -- 0 = beginning, 1 = end
local use_cycle_mode         = true                  -- cycle mode checkbox
local sort_index             = 0                     -- 0 = Track, 1 = Sequence, 2 = Timeline
local preview_mode           = false                 -- 预览模式默认值
local match_case             = false                 -- 匹配大小写
local occurrence_mode        = 2                     -- Occurrence 模式: 0=First,1=Last,2=All
local use_regular_expression = false                 -- Wwise/ECMAScript-style regex for Replace
local write_take_name        = true                  -- true 将新文件名写入 Take 名称，false 保持原 Take 名称
local PREVIEW_TABLE_ID       = "preview_table"       -- 主脚本里共用
local PREVIEW_POPUP_TABLE_ID = "preview_popup_table" -- 弹窗里共用
show_list_window = show_list_window or false
local show_list_data = show_list_data or {}
local show_preview_window = false
local preview_filter
local ctrl_enter_was_down   = false

local batch_modes = {
  { label_key = "batch_items",            menu_key = "items",            tip_key = "tip_items" },
  { label_key = "batch_tracks",           menu_key = "tracks",           tip_key = "tip_tracks" },
  { label_key = "batch_regions_manager",  menu_key = "manager",          tip_key = "tip_regions_manager" },
  { label_key = "batch_regions_time",     menu_key = "time_selection",   tip_key = "tip_regions_time" },
  { label_key = "batch_regions_selected", menu_key = "selected_regions", tip_key = "tip_regions_selected" },
  { label_key = "batch_regions_items",    menu_key = "selected_items",   tip_key = "tip_regions_items" },
  { label_key = "batch_markers_manager",  menu_key = "manager",          tip_key = "tip_markers_manager" },
  { label_key = "batch_markers_selected", menu_key = "selected_markers", tip_key = "tip_markers_selected" },
  { label_key = "batch_markers_time",     menu_key = "time_selection",   tip_key = "tip_markers_time" },
  { label_key = "batch_sources_items",    menu_key = "selected_items",   tip_key = "tip_sources_items" },
}

local batch_mode_groups = {
  { label_key = "media",        modes = { 0, 1 } },
  { label_key = "regions",      modes = { 2, 3, 4, 5 } },
  { label_key = "markers",      modes = { 6, 7, 8 } },
  { label_key = "source_files", modes = { 9 } },
}

function get_batch_mode_label(mode)
  local rec = batch_modes[(mode or 0) + 1]
  return rec and tr(rec.label_key) or ""
end

function get_batch_mode_tip(mode)
  local rec = batch_modes[(mode or 0) + 1]
  return rec and tr(rec.tip_key) or ""
end

--------------------------------------------------------------------------------
-- 用户预设
--------------------------------------------------------------------------------
local presetNames = {}
local selectedPreset = 1 -- 默认为 Reset to factory default
local newPresetName = ""
local showSavePopup = false

local USE_REGEX_EXT_KEY = "UseRegularExpression"

function SaveUseRegularExpressionState()
  reaper.SetExtState(EXT_SECTION, USE_REGEX_EXT_KEY, tostring(use_regular_expression), true)
end

function LoadUseRegularExpressionState()
  local stored_use_regex = reaper.GetExtState(EXT_SECTION, USE_REGEX_EXT_KEY)
  if stored_use_regex == "true" then
    use_regular_expression = true
  elseif stored_use_regex == "false" then
    use_regular_expression = false
  end
end

-- 重置到初始状态
function ResetState(save_regular_expression_state)
  rename_pattern    = ""
  find_text         = ""
  replace_text      = ""
  remove_count      = 0
  remove_position   = 0
  remove_side_index = 0
  insert_text       = ""
  insert_position   = 0
  insert_side_index = 0
  enable_rename     = false
  enable_replace    = false
  enable_remove     = false
  enable_insert     = false
  use_cycle_mode    = true
  write_take_name   = true
  match_case        = false
  use_regular_expression = false
  occurrence_mode   = 2 -- All 模式
  if save_regular_expression_state ~= false then
    SaveUseRegularExpressionState()
  end
end

-- 判断表中是否包含某值
function TableContains(t, val)
  for _,v in ipairs(t) do if v == val then return true end end
  return false
end

-- 读取所有用户预设名
function LoadPresetList()
  presetNames = {}
  local listStr = reaper.GetExtState("BatchRenamePresets", "__list") or ""
  for name in listStr:gmatch("([^,]+)") do
    if name ~= "" then table.insert(presetNames, name) end
  end
  -- 终把 No preset 放到最前面
  table.insert(presetNames, 1, "No preset")
end

-- 保存用户预设名列表
function SavePresetList()
  local userNames = {}
  for i=2, #presetNames do -- skip index 1 (No preset)
    userNames[#userNames+1] = presetNames[i]
  end
  local listStr = table.concat(userNames, ",")
  reaper.SetExtState("BatchRenamePresets", "__list", listStr, true)
end

-- 将当前状态编码为字符串
function EncodePreset()
  local data = {
    rename_pattern,
    find_text,
    replace_text,
    tostring(remove_count),
    tostring(remove_position),
    tostring(remove_side_index),
    insert_text,
    tostring(insert_position),
    tostring(insert_side_index),
    enable_rename  and "1" or "0",
    enable_replace and "1" or "0",
    enable_remove  and "1" or "0",
    enable_insert  and "1" or "0",
    match_case     and "1" or "0",
    tostring(occurrence_mode),
    write_take_name and "1" or "0",
    use_regular_expression and "1" or "0",
  }
  return table.concat(data, "\t")
end

-- 应用某条预设 (解码并赋值)
function ApplyPreset(dataStr)
  local params = {}
  for v in dataStr:gmatch("([^\t]*)") do table.insert(params, v) end
  rename_pattern    = params[1] or ""
  find_text         = params[2] or ""
  replace_text      = params[3] or ""
  remove_count      = tonumber(params[4]) or 0
  remove_position   = tonumber(params[5]) or 0
  remove_side_index = tonumber(params[6]) or 0
  insert_text       = params[7] or ""
  insert_position   = tonumber(params[8]) or 0
  insert_side_index = tonumber(params[9]) or 0
  enable_rename     = params[10]=="1"
  enable_replace    = params[11]=="1"
  enable_remove     = params[12]=="1"
  enable_insert     = params[13]=="1"
  match_case       = params[14]=="1"
  occurrence_mode   = tonumber(params[15]) or 2
  write_take_name   = (params[16] == nil or params[16] == "") and true or (params[16] == "1")
  use_regular_expression = params[17]=="1"
  SaveUseRegularExpressionState()
end

-- 通用 ImGui 文本输入对话框
function ImGui_TextPrompt(ctx, prompt, buf_label, buf_size, callback)
  local popup_id = stable_label(prompt.caption_key and tr(prompt.caption_key) or prompt.id, prompt.id)
  -- 如果 show 被置为 true 就打开弹窗一次
  if prompt.show then
    reaper.ImGui_OpenPopup(ctx, popup_id)
    prompt.show = false
  end

  -- 居中弹窗
  local vp = reaper.ImGui_GetWindowViewport(ctx)
  local cx, cy = reaper.ImGui_Viewport_GetCenter(vp)
  reaper.ImGui_SetNextWindowPos(ctx, cx, cy, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

  -- 真正绘制 Modal
  if reaper.ImGui_BeginPopupModal(ctx, popup_id, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    -- 标题文字
    reaper.ImGui_Text(ctx, prompt.title_key and tr(prompt.title_key) or prompt.title)
    -- 文本输入框
    local changed
    changed, prompt.buffer = reaper.ImGui_InputText(ctx, buf_label, prompt.buffer, buf_size)
    -- 确定按钮
    if reaper.ImGui_Button(ctx, T.ok) then -- ctx, "OK", 120, 0
      callback(prompt.buffer)
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_SameLine(ctx)
    -- 取消按钮
    if reaper.ImGui_Button(ctx, T.cancel) then -- ctx, "OK", 120, 0
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

-- 用于保存预设和重命名预设的两个 prompt 对象
local savePresetPrompt = {
  id          = "save_preset_prompt",
  caption_key = "save_preset",
  title_key   = "save_preset_title",
  buffer = "",
  show   = false
}

local renamePresetPrompt = {
  id          = "rename_preset_prompt",
  caption_key = "rename_preset",
  title_key   = "rename_preset_title",
  buffer  = "",
  show    = false,
  oldName = "" -- 用来暂存旧名字
}

-- 预设初始加载
LoadPresetList()
ResetState(false)
LoadUseRegularExpressionState()

--------------------------------------------------------------------------------
-- 颜色相关
--------------------------------------------------------------------------------
-- 完全透明
local transparent = 0x00000000 -- R=00 G=00 B=00 A=00
local yellow      = 0xFFFF00FF -- 纯黄，RGBA 全不透明
-- 基本色 (100% 不透明)
local white       = 0xFFFFFFFF -- 白色
local black       = 0x000000FF -- 黑色
local red         = 0xFF0000FF -- 红色
local green       = 0x00FF00FF -- 绿色
local blue        = 0x0000FFFF -- 蓝色
local yellow      = 0xFFFF00FF -- 黄色
local cyan        = 0x00FFFFFF -- 青色
local magenta     = 0xFF00FFFF -- 品红
-- 灰度
local gray        = 0x808080FF -- 中灰
local lightGray   = 0xC0C0C0FF -- 浅灰
local darkGray    = 0x404040FF -- 深灰
-- 其他常用色
local orange      = 0xFFA500FF -- 橙色
local purple      = 0x800080FF -- 紫色
local pink        = 0xFFC0CBFF -- 粉色
local brown       = 0xA52A2AFF -- 棕色
local lime        = 0x32CD32FF -- 酸橙绿
local gold        = 0xFFD700FF -- 金色
local silver      = 0xC0C0C0FF -- 银色

-- 预览弹窗
local ext_popup = reaper.GetExtState("BatchRenamePlus", "PopupPreviewOpen")
if ext_popup == "true" then show_preview_window = true
elseif ext_popup == "false" then show_preview_window = false end

-- 预览表格
-- 预览表格的 flags1 初始值。如果全部不勾选，则使用flags1 = 0
local tables = {
  disable_indent = false,
  horizontal = {
    flags1 = reaper.ImGui_TableFlags_Resizable()
    -- + reaper.ImGui_TableFlags_ScrollX()
    + reaper.ImGui_TableFlags_ScrollY(),
    flags2 = reaper.ImGui_TableFlags_Resizable(),
    -- + reaper.ImGui_TableFlags_ScrollX()
    -- + reaper.ImGui_TableFlags_ScrollY()
  },
}

function help_marker(desc)
  if not show_help_markers then
    reaper.ImGui_Text(ctx, "")
    return
  end
  reaper.ImGui_TextDisabled(ctx, '(?)')
  if reaper.ImGui_BeginItemTooltip(ctx) then
    reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
    reaper.ImGui_Text(ctx, desc)
    reaper.ImGui_PopTextWrapPos(ctx)
    reaper.ImGui_EndTooltip(ctx)
  end
end

function make_case_insensitive_pattern(str)
  if use_regular_expression then return str or "" end
  return str:gsub("(%a)", function(c)
    return "["..c:lower()..c:upper().."]"
  end)
end

-- Wwise 的 Batch Rename 使用 ECMAScript 风格正则。Lua 没有 regex，因此这里实现了一个简易匹配器。
local WWISE_REGEX_CACHE = {}

function regex_utf8_char_at(s, i)
  local b = s:byte(i)
  if not b then return nil, nil, i end

  local len = 1
  if b >= 0xF0 and b <= 0xF7 then
    len = 4
  elseif b >= 0xE0 and b <= 0xEF then
    len = 3
  elseif b >= 0xC0 and b <= 0xDF then
    len = 2
  end

  if i + len - 1 > #s then len = 1 end
  local ch = s:sub(i, i + len - 1)
  local ok, cp = pcall(utf8.codepoint, ch)
  if not ok or not cp then
    ch = s:sub(i, i)
    cp = b
    len = 1
  end
  return ch, cp, i + len
end

function regex_make_text(s)
  s = tostring(s or "")
  local text = { source = s, chars = {}, cps = {}, byte_starts = {} }
  local i = 1
  while i <= #s do
    local ch, cp, next_i = regex_utf8_char_at(s, i)
    text.byte_starts[#text.chars + 1] = i
    text.chars[#text.chars + 1] = ch
    text.cps[#text.cps + 1] = cp
    i = next_i
  end
  text.n = #text.chars
  text.byte_starts[text.n + 1] = #s + 1
  return text
end

function regex_slice(text, first_pos, end_pos)
  first_pos = math.max(1, math.min(first_pos or 1, text.n + 1))
  end_pos = math.max(1, math.min(end_pos or (text.n + 1), text.n + 1))
  if end_pos <= first_pos then return "" end
  return text.source:sub(text.byte_starts[first_pos], text.byte_starts[end_pos] - 1)
end

function regex_copy_captures(caps)
  local out = {}
  for k, v in pairs(caps or {}) do
    out[k] = { start = v.start, finish = v.finish }
  end
  return out
end

function regex_state(pos, caps)
  return { pos = pos, caps = regex_copy_captures(caps) }
end

function regex_ascii_lower(cp)
  if cp and cp >= 65 and cp <= 90 then return cp + 32 end
  return cp
end

function regex_cp_equal(a, b, ignore)
  if a == b then return true end
  return ignore and regex_ascii_lower(a) == regex_ascii_lower(b)
end

function regex_is_digit(cp)
  return cp and cp >= 48 and cp <= 57
end

function regex_is_word(cp)
  return cp and ((cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) or cp == 95)
end

function regex_is_space(cp)
  return cp == 32 or cp == 9 or cp == 10 or cp == 11 or cp == 12 or cp == 13 or cp == 0xA0
end

function regex_compile(pattern)
  pattern = tostring(pattern or "")
  local cached = WWISE_REGEX_CACHE[pattern]
  if cached then return cached.compiled, cached.err end

  local p = { s = pattern, i = 1, len = #pattern, group_count = 0, err = nil }
  local parse_expression, parse_sequence, parse_atom, parse_class

  local function peek(offset)
    offset = offset or 0
    local pos = p.i + offset
    if pos > p.len then return "" end
    return p.s:sub(pos, pos)
  end

  local function consume(n)
    n = n or 1
    local out = p.s:sub(p.i, p.i + n - 1)
    p.i = p.i + n
    return out
  end

  local function read_digits()
    local start_i = p.i
    while peek():match("%d") do consume(1) end
    return p.s:sub(start_i, p.i - 1)
  end

  local function read_char()
    local ch, cp, next_i = regex_utf8_char_at(p.s, p.i)
    p.i = next_i
    return ch, cp
  end

  local function literal_node(cp)
    return { type = "literal", cp = cp }
  end

  local function class_node(name)
    return { type = "class", negated = false, parts = { { kind = "pred", name = name } } }
  end

  local function escaped_atom(in_class)
    consume(1)
    if p.i > p.len then return literal_node(92) end
    local c = peek()

    if c == "s" or c == "S" or c == "d" or c == "D" or c == "w" or c == "W" then
      consume(1)
      if in_class then return { kind = "pred", name = c } end
      return class_node(c)
    elseif c == "n" then
      consume(1)
      if in_class then return { kind = "char", cp = 10 } end
      return literal_node(10)
    elseif c == "r" then
      consume(1)
      if in_class then return { kind = "char", cp = 13 } end
      return literal_node(13)
    elseif c == "t" then
      consume(1)
      if in_class then return { kind = "char", cp = 9 } end
      return literal_node(9)
    elseif c == "b" and not in_class then
      consume(1)
      return { type = "boundary", negated = false }
    elseif c == "B" and not in_class then
      consume(1)
      return { type = "boundary", negated = true }
    elseif c == "b" and in_class then
      consume(1)
      return { kind = "char", cp = 8 }
    elseif c == "x" then
      local hex = p.s:sub(p.i + 1, p.i + 2)
      if hex:match("^%x%x$") then
        p.i = p.i + 3
        local cp = tonumber(hex, 16)
        if in_class then return { kind = "char", cp = cp } end
        return literal_node(cp)
      end
      p.err = "Invalid hexadecimal escape"
      return in_class and { kind = "char", cp = 120 } or literal_node(120)
    end

    local _, cp = read_char()
    if in_class then return { kind = "char", cp = cp } end
    return literal_node(cp)
  end

  parse_class = function()
    consume(1)
    local negated = false
    if peek() == "^" then
      negated = true
      consume(1)
    end

    local parts = {}
    local first = true
    local closed = false
    while p.i <= p.len do
      if peek() == "]" and not first then
        consume(1)
        closed = true
        break
      end

      local item
      if peek() == "\\" then
        item = escaped_atom(true)
      else
        local _, cp = read_char()
        item = { kind = "char", cp = cp }
      end

      if item.kind == "char" and peek() == "-" and p.s:sub(p.i + 1, p.i + 1) ~= "]" and p.i < p.len then
        consume(1)
        local item2
        if peek() == "\\" then
          item2 = escaped_atom(true)
        else
          local _, cp2 = read_char()
          item2 = { kind = "char", cp = cp2 }
        end
        if item2.kind == "char" then
          parts[#parts + 1] = { kind = "range", from = item.cp, to = item2.cp }
        else
          parts[#parts + 1] = item
          parts[#parts + 1] = { kind = "char", cp = 45 }
          parts[#parts + 1] = item2
        end
      else
        parts[#parts + 1] = item
      end
      first = false
    end

    if not closed then p.err = "Unclosed character class" end
    return { type = "class", negated = negated, parts = parts }
  end

  local function apply_quantifier(atom)
    local c = peek()
    if c == "*" or c == "+" or c == "?" then
      consume(1)
      if c == "*" then return { type = "repeat", child = atom, min = 0, max = nil } end
      if c == "+" then return { type = "repeat", child = atom, min = 1, max = nil } end
      return { type = "repeat", child = atom, min = 0, max = 1 }
    elseif c == "{" then
      local save_i = p.i
      consume(1)
      local min_s = read_digits()
      if min_s == "" then
        p.i = save_i
        return atom
      end
      local min_n = tonumber(min_s)
      local max_n = min_n
      if peek() == "," then
        consume(1)
        local max_s = read_digits()
        max_n = (max_s == "") and nil or tonumber(max_s)
      end
      if peek() ~= "}" then
        p.i = save_i
        return atom
      end
      consume(1)
      if max_n and max_n < min_n then
        p.err = "Invalid quantifier range"
      end
      return { type = "repeat", child = atom, min = min_n, max = max_n }
    end
    return atom
  end

  parse_atom = function()
    local c = peek()
    if c == "" then return { type = "seq", nodes = {} } end
    if c == "*" or c == "+" or c == "?" then
      p.err = "Nothing to repeat"
      consume(1)
      return literal_node(c:byte())
    elseif c == "^" then
      consume(1)
      return { type = "anchor_start" }
    elseif c == "$" then
      consume(1)
      return { type = "anchor_end" }
    elseif c == "." then
      consume(1)
      return { type = "any" }
    elseif c == "[" then
      return parse_class()
    elseif c == "\\" then
      return escaped_atom(false)
    elseif c == "(" then
      consume(1)
      local capture_id = nil
      if peek() == "?" then
        if p.s:sub(p.i, p.i + 1) == "?:" then
          consume(2)
        else
          p.err = "Unsupported group syntax"
        end
      else
        p.group_count = p.group_count + 1
        capture_id = p.group_count
      end

      local child = parse_expression()
      if peek() == ")" then
        consume(1)
      else
        p.err = "Unclosed group"
      end
      return { type = "group", child = child, capture_id = capture_id }
    end

    local _, cp = read_char()
    return literal_node(cp)
  end

  parse_sequence = function()
    local nodes = {}
    while p.i <= p.len do
      local c = peek()
      if c == ")" or c == "|" then break end
      local atom = parse_atom()
      if p.err then break end
      nodes[#nodes + 1] = apply_quantifier(atom)
      if p.err then break end
    end
    return { type = "seq", nodes = nodes }
  end

  parse_expression = function()
    local branches = { parse_sequence() }
    while not p.err and peek() == "|" do
      consume(1)
      branches[#branches + 1] = parse_sequence()
    end
    if #branches == 1 then return branches[1] end
    return { type = "alt", branches = branches }
  end

  local ast = parse_expression()
  if not p.err and p.i <= p.len then
    p.err = "Unexpected character"
  end

  if p.err then
    WWISE_REGEX_CACHE[pattern] = { compiled = nil, err = p.err }
    return nil, p.err
  end

  local compiled = { ast = ast, group_count = p.group_count }
  WWISE_REGEX_CACHE[pattern] = { compiled = compiled, err = nil }
  return compiled, nil
end

function regex_part_matches(part, cp, ignore)
  if part.kind == "char" then
    return regex_cp_equal(cp, part.cp, ignore)
  elseif part.kind == "range" then
    local test_cp = ignore and regex_ascii_lower(cp) or cp
    local from_cp = ignore and regex_ascii_lower(part.from) or part.from
    local to_cp = ignore and regex_ascii_lower(part.to) or part.to
    if from_cp <= to_cp then
      return test_cp >= from_cp and test_cp <= to_cp
    end
    return test_cp >= to_cp and test_cp <= from_cp
  elseif part.kind == "pred" then
    if part.name == "d" then return regex_is_digit(cp) end
    if part.name == "D" then return not regex_is_digit(cp) end
    if part.name == "w" then return regex_is_word(cp) end
    if part.name == "W" then return not regex_is_word(cp) end
    if part.name == "s" then return regex_is_space(cp) end
    if part.name == "S" then return not regex_is_space(cp) end
  end
  return false
end

local function regex_class_matches(node, cp, ignore)
  local matched = false
  for _, part in ipairs(node.parts or {}) do
    if regex_part_matches(part, cp, ignore) then
      matched = true
      break
    end
  end
  return node.negated and not matched or matched
end

local regex_match_node

function regex_match_sequence(nodes, text, pos, caps, ignore)
  local states = { regex_state(pos, caps) }
  for _, child in ipairs(nodes) do
    local next_states = {}
    for _, st in ipairs(states) do
      local child_states = regex_match_node(child, text, st.pos, st.caps, ignore)
      for _, child_st in ipairs(child_states) do
        next_states[#next_states + 1] = child_st
      end
    end
    states = next_states
    if #states == 0 then break end
  end
  return states
end

regex_match_node = function(node, text, pos, caps, ignore)
  if node.type == "seq" then
    return regex_match_sequence(node.nodes, text, pos, caps, ignore)
  elseif node.type == "literal" then
    if pos <= text.n and regex_cp_equal(text.cps[pos], node.cp, ignore) then
      return { regex_state(pos + 1, caps) }
    end
    return {}
  elseif node.type == "any" then
    if pos <= text.n and text.cps[pos] ~= 10 then
      return { regex_state(pos + 1, caps) }
    end
    return {}
  elseif node.type == "class" then
    if pos <= text.n and regex_class_matches(node, text.cps[pos], ignore) then
      return { regex_state(pos + 1, caps) }
    end
    return {}
  elseif node.type == "anchor_start" then
    if pos == 1 or (pos > 1 and text.cps[pos - 1] == 10) then
      return { regex_state(pos, caps) }
    end
    return {}
  elseif node.type == "anchor_end" then
    if pos == text.n + 1 or text.cps[pos] == 10 or text.cps[pos] == 13 then
      return { regex_state(pos, caps) }
    end
    return {}
  elseif node.type == "boundary" then
    local prev_word = (pos > 1) and regex_is_word(text.cps[pos - 1]) or false
    local next_word = (pos <= text.n) and regex_is_word(text.cps[pos]) or false
    local is_boundary = prev_word ~= next_word
    if (node.negated and not is_boundary) or (not node.negated and is_boundary) then
      return { regex_state(pos, caps) }
    end
    return {}
  elseif node.type == "group" then
    local out = {}
    local child_states = regex_match_node(node.child, text, pos, regex_copy_captures(caps), ignore)
    for _, st in ipairs(child_states) do
      local new_caps = regex_copy_captures(st.caps)
      if node.capture_id then
        new_caps[node.capture_id] = { start = pos, finish = st.pos }
      end
      out[#out + 1] = { pos = st.pos, caps = new_caps }
    end
    return out
  elseif node.type == "alt" then
    local out = {}
    for _, branch in ipairs(node.branches) do
      local states = regex_match_node(branch, text, pos, regex_copy_captures(caps), ignore)
      for _, st in ipairs(states) do out[#out + 1] = st end
    end
    return out
  elseif node.type == "repeat" then
    local out = {}
    local function repeat_from(cur_pos, cur_caps, count)
      if not node.max or count < node.max then
        local states = regex_match_node(node.child, text, cur_pos, regex_copy_captures(cur_caps), ignore)
        for _, st in ipairs(states) do
          if st.pos ~= cur_pos then
            repeat_from(st.pos, st.caps, count + 1)
          elseif count + 1 >= node.min then
            out[#out + 1] = regex_state(st.pos, st.caps)
          end
        end
      end
      if count >= node.min then
        out[#out + 1] = regex_state(cur_pos, cur_caps)
      end
    end
    repeat_from(pos, caps, 0)
    return out
  end
  return {}
end

function regex_find(compiled, text, start_pos, ignore)
  for start_i = start_pos, text.n + 1 do
    local states = regex_match_node(compiled.ast, text, start_i, {}, ignore)
    if #states > 0 then
      return {
        start = start_i,
        finish = states[1].pos,
        caps = states[1].caps,
        group_count = compiled.group_count
      }
    end
  end
  return nil
end

function regex_expand_replacement(repl, text, match)
  repl = tostring(repl or "")
  local out = {}
  local i = 1
  while i <= #repl do
    local c = repl:sub(i, i)
    if c == "$" and i < #repl then
      local n = repl:sub(i + 1, i + 1)
      if n == "&" then
        out[#out + 1] = regex_slice(text, match.start, match.finish)
        i = i + 2
      elseif n == "`" then
        out[#out + 1] = regex_slice(text, 1, match.start)
        i = i + 2
      elseif n == "'" then
        out[#out + 1] = regex_slice(text, match.finish, text.n + 1)
        i = i + 2
      elseif n == "+" then
        local cap
        for id = match.group_count, 1, -1 do
          if match.caps[id] then
            cap = match.caps[id]
            break
          end
        end
        out[#out + 1] = cap and regex_slice(text, cap.start, cap.finish) or ""
        i = i + 2
      elseif n == "$" then
        out[#out + 1] = "$"
        i = i + 2
      elseif n:match("%d") then
        local j = i + 1
        while j <= #repl and repl:sub(j, j):match("%d") do j = j + 1 end
        local id = tonumber(repl:sub(i + 1, j - 1))
        local cap = id and match.caps[id]
        out[#out + 1] = cap and regex_slice(text, cap.start, cap.finish) or ""
        i = j
      else
        out[#out + 1] = "$"
        i = i + 1
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

function regex_next_search_pos(match, text)
  if match.finish == match.start then
    if match.finish <= text.n then return match.finish + 1 end
    return text.n + 2
  end
  return match.finish
end

function wwise_regex_replace(s, pat, repl, occurrence)
  local compiled = regex_compile(pat)
  if not compiled then return s end
  local text = regex_make_text(s)
  local ignore = not match_case

  if occurrence == "last" then
    local search_pos = 1
    local last_match = nil
    while search_pos <= text.n + 1 do
      local match = regex_find(compiled, text, search_pos, ignore)
      if not match then break end
      last_match = match
      search_pos = regex_next_search_pos(match, text)
    end
    if not last_match then return s end
    return regex_slice(text, 1, last_match.start) ..
      regex_expand_replacement(repl, text, last_match) ..
      regex_slice(text, last_match.finish, text.n + 1)
  end

  local out = {}
  local search_pos = 1
  local emit_pos = 1
  while search_pos <= text.n + 1 do
    local match = regex_find(compiled, text, search_pos, ignore)
    if not match then break end
    out[#out + 1] = regex_slice(text, emit_pos, match.start)
    out[#out + 1] = regex_expand_replacement(repl, text, match)
    emit_pos = match.finish
    search_pos = regex_next_search_pos(match, text)
    if occurrence == "first" then break end
  end
  out[#out + 1] = regex_slice(text, emit_pos, text.n + 1)
  return table.concat(out)
end

function replace_last(s, pat, repl)
  if use_regular_expression then
    return wwise_regex_replace(s, pat, repl, "last")
  end
  return s:gsub("^(.*)("..pat..")", function(a,b) return a..repl end)
end

function replace_first(s, pat, repl)
  if use_regular_expression then
    return wwise_regex_replace(s, pat, repl, "first")
  end
  local out = s:gsub(pat, function() return repl end, 1)
  return out
end

function replace_all(s, pat, repl)
  if use_regular_expression then
    return wwise_regex_replace(s, pat, repl, "all")
  end
  local out = s:gsub(pat, function() return repl end)
  return out
end

function escape_pattern(str)
  if use_regular_expression then return str or "" end
  -- 正则元字符转义 ^ $ ( ) % . [ ] + - |
  str = str:gsub("([%^%$%(%)%%%.%[%]%+%-%|])", "%%%1")
  str = str:gsub("%*", ".*")
  str = str:gsub("%?", ".")
  return str
end

function apply_modifiers(name, i)
  local is_preview = preview_mode
  -- 单值步长: d=START/STEP  → START + (i-1)*STEP
  name = name:gsub("d=(%d+)%/(%d+)", function(s, step)
    local width  = #s
    local start0 = tonumber(s)
    local stp    = tonumber(step)
    local val    = start0 + (i-1) * stp
    return string.format("%0"..width.."d", val)
  end)

  -- 1) 循环步长: d=START-END[/STEP]
  if use_cycle_mode then
    -- 带步长
    name = name:gsub("d=(%d+)%-(%d+)%/(%d+)", function(s,e,step)
      local width  = #s
      local s0, e0 = tonumber(s), tonumber(e)
      local stp    = tonumber(step)
      local rng    = math.abs(e0-s0)+1
      local count  = math.floor((rng+stp-1)/stp)
      local off    = ((i-1)%count)*stp
      local val    = (s0 <= e0) and (s0+off) or (s0-off)
      return string.format("%0"..width.."d", val)
    end)
    -- 不带步长，等同 step=1
    name = name:gsub("d=(%d+)%-(%d+)", function(s, e)
      local len  = #s
      local s0, e0 = tonumber(s), tonumber(e)
      local rng  = math.abs(e0 - s0) + 1
      local off  = (i - 1) % rng
      local val  = (s0 <= e0) and (s0 + off) or (s0 - off)
      return string.format("%0"..len.."d", val)
    end)
    -- 循环模式: 字母区间 A-Z 或 a-z
    name = name:gsub("a=([A-Za-z])%-([A-Za-z])", function(c1, c2)
      local b1, b2 = c1:byte(), c2:byte()
      local rng    = math.abs(b2 - b1) + 1
      local off    = (i - 1) % rng
      local bb     = (b1 <= b2) and (b1 + off) or (b1 - off)
      return string.char(bb)
    end)
  end

  -- 2) 累加单字符: a=X 或 a=x
  name = name:gsub("a=([A-Za-z])", function(c)
    local b    = c:byte()
    local base = (b >= 97 and b <= 122) and 97 or 65
    return string.char(base + ((b - base) + (i - 1)) % 26)
  end)

  -- 3) 累加数字: d=N → N+i-1
  name = name:gsub("d=(%d+)", function(n)
    local len = #n
    local num = tonumber(n) + (i - 1)
    return string.format("%0"..len.."d", num)
  end)

  -- 4) 随机字符串 r=n
  if is_preview then
    name = name:gsub("r=(%d+)", function(n)
      return tr("random_preview", n)
    end)
  else
    name = name:gsub("r=(%d+)", function(n)
      local cnt = tonumber(n)
      local pool = {}
      for c = 48, 57  do pool[#pool+1] = string.char(c) end
      for c = 65, 90  do pool[#pool+1] = string.char(c) end
      for c = 97, 122 do pool[#pool+1] = string.char(c) end
      local out = {}
      for _ = 1, cnt do out[#out+1] = pool[math.random(#pool)] end
      return table.concat(out)
    end)
  end

  -- 枚举循环: e=项1|项2|…; (分号后是终止符)
  name = name:gsub("e=([^;]+);", function(list)
    local vals = {}
    for v in list:gmatch("([^|]+)") do
      table.insert(vals, v)
    end
    if #vals == 0 then return "" end
    local idx = ((i - 1) % #vals) + 1
    return vals[idx]
  end)

  return name
end

-- 根据通配符的大小写模式，对原始名称做相应大小写变换
function apply_case_transform(name, token)
  -- 全部大写
  if token:match("^%u+$") then
    return name:upper()
  end
  -- 全部小写
  if token:match("^%l%u+$") then
    return name:lower()
  end
  -- 首字母大写，其它小写
  if token:match("^[%u]%l+$") then
    return name:lower():gsub("^%l", string.upper)
  end
  -- 原样输出
  return name
end

--表格预览
local wildcard_patterns = {}
function get_wildcard_pattern(token)
  if wildcard_patterns[token] then return wildcard_patterns[token] end
  local parts = { "%$" }
  for i = 1, #token do
    local c = token:sub(i, i)
    if c:match("%a") then
      parts[#parts + 1] = "[" .. c:lower() .. c:upper() .. "]"
    else
      parts[#parts + 1] = "%" .. c
    end
  end
  local pat = table.concat(parts)
  wildcard_patterns[token] = pat
  return pat
end

function expand_wildcard(name, token, value, use_case_transform)
  value = tostring(value or "")
  return name:gsub(get_wildcard_pattern(token), function(tok)
    if use_case_transform then
      return apply_case_transform(value, tok:sub(2))
    end
    return value
  end)
end

function render_preview_table(ctx, id, realCount, row_builder)
  preview_mode = true
  local cnt = realCount

  reaper.ImGui_PushID(ctx, id)
  reaper.ImGui_SeparatorText(ctx, tr("preview_objects", cnt))

  -- 压缩复选框样式
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local tblFlags1 = tables.horizontal.flags1 or 0
  local ok
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, T.resize, tblFlags1, reaper.ImGui_TableFlags_Resizable())
  reaper.ImGui_SameLine(ctx)
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, T.horizontal_scroll, tblFlags1, reaper.ImGui_TableFlags_ScrollX())
  reaper.ImGui_SameLine(ctx)
  ok, tblFlags1 = reaper.ImGui_CheckboxFlags(ctx, T.vertical_scroll, tblFlags1, reaper.ImGui_TableFlags_ScrollY())
  tables.horizontal.flags1 = tblFlags1

  -- 恢复复选框样式
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_Separator(ctx)

  -- 开始统计错误数, 如果没有任何选中项就显示 10 行空白
  local displayCount = math.max(cnt, 10)
  local errorCount = 0
  local name_counts = {}
  local tableFlags = tblFlags1 + reaper.ImGui_TableFlags_RowBg() -- reaper.ImGui_TableFlags_Borders()
  if reaper.ImGui_BeginTable(ctx, id .. "_table", 3, tableFlags, -1, 127) then
    reaper.ImGui_TableSetupColumn(ctx, T.before, reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, T.after, reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, T.message, 0)
    reaper.ImGui_TableHeadersRow(ctx)

    for i = 1, displayCount do
      local before, after = "", ""
      if i <= cnt then
        before, after = row_builder(i)
      end

      -- 输出行
      reaper.ImGui_TableNextRow(ctx)
      if i <= cnt then
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, before)
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, after)
        reaper.ImGui_TableNextColumn(ctx)
        if after ~= "" then
          name_counts[after] = (name_counts[after] or 0) + 1
        end
        if #after == 0 then
          errorCount = errorCount + 1
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
          reaper.ImGui_Text(ctx, T.empty_name)
          reaper.ImGui_PopStyleColor(ctx)
        end
      else
        -- placeholder row
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, "--")
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_Text(ctx, T.empty_slot)
        reaper.ImGui_PopStyleColor(ctx)
      end
    end

    reaper.ImGui_EndTable(ctx)
    local dupCount = 0
    for _, c in pairs(name_counts) do
      if c > 1 then dupCount = dupCount + (c - 1) end
    end

    -- 显示错误和重复统计
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
    reaper.ImGui_Text(ctx, tr("counts_status", errorCount, dupCount))
    reaper.ImGui_PopStyleColor(ctx)
  end
  reaper.ImGui_PopID(ctx)
  preview_mode = false
end

function render_preview_table_popup(ctx, id, realCount, row_builder)
  preview_mode = true
  local cnt = realCount
  -- reaper.ImGui_SeparatorText(ctx, string.format("Preview - %d Object(s)", cnt))
  -- 压缩复选框样式
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local tblFlags2 = tables.horizontal.flags2 or 0
  tables.horizontal.flags2 = tblFlags2

  -- 恢复复选框样式
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_Separator(ctx)

  -- 开始统计错误数, 如果没有任何选中项就显示 10 行空白
  local displayCount = math.max(cnt, 0) -- 当前设置为 0，不显示空白行
  local errorCount = 0
  local tableFlags = tblFlags2 + reaper.ImGui_TableFlags_RowBg() + reaper.ImGui_TableFlags_Borders()
  local table_font = preview_fonts[preview_font_size] or preview_fonts[14] or preview_fonts[12]
  reaper.ImGui_PushFont(ctx, table_font)
  if reaper.ImGui_BeginTable(ctx, id .. "_table", 3, tableFlags, -1, 0) then
    reaper.ImGui_TableSetupColumn(ctx, T.before, reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, T.after, reaper.ImGui_TableColumnFlags_NoHide())
    reaper.ImGui_TableSetupColumn(ctx, T.message, 0)
    reaper.ImGui_TableHeadersRow(ctx)

    for i = 1, displayCount do
      local before, after = "", ""
      if i <= cnt then
        before, after = row_builder(i)
      end
      -- 传 filter 和文字内容
      if reaper.ImGui_TextFilter_PassFilter(preview_filter, before) or reaper.ImGui_TextFilter_PassFilter(preview_filter, after) then
        -- 输出行，拿掉if reaper.ImGui_TextFilter_PassFilter则不过滤
        reaper.ImGui_TableNextRow(ctx)
        if i <= cnt then
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, before)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(before)
          end
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, after)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(after)
          end
          reaper.ImGui_TableNextColumn(ctx)
          if #after == 0 then
            local message = T.empty_name
            errorCount = errorCount + 1
            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
            reaper.ImGui_Text(ctx, message)
            if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
              reaper.CF_SetClipboard(message)
            end
            reaper.ImGui_PopStyleColor(ctx)
          end
        else
          -- placeholder row
          reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, "--")
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard("--")
          end
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, "--")
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard("--")
          end
          reaper.ImGui_TableNextColumn(ctx)
          local message = T.empty_slot
          reaper.ImGui_Text(ctx, message)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(message)
          end
          reaper.ImGui_PopStyleColor(ctx)
        end
      end
    end
    reaper.ImGui_EndTable(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  -- 显示状态栏信息
  local dupCount = 0
  local name_counts = {}

  for i = 1, cnt do
    local _, after = row_builder(i)
    if after ~= "" then
      name_counts[after] = (name_counts[after] or 0) + 1
    end
  end
  for _, c in pairs(name_counts) do
    if c > 1 then dupCount = dupCount + (c - 1) end
  end

  local modeName = get_batch_mode_label(process_mode)
  local status = tr("counts_status", errorCount, dupCount)
  status = status .. " " .. T.mode .. ": " .. modeName

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  reaper.ImGui_Text(ctx, status)
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_SameLine(ctx)
  help_marker(
    T.copy_cell_help
  )

  preview_mode = false
end

--------------------------------------------------------------------------------
-- 源文件 相关函数
--------------------------------------------------------------------------------
-- 遍历所有媒体对象，检查是否有选中的
function CountSelectedItems(proj)
  local sel_cnt = 0
  local item_count = reaper.CountMediaItems(proj)

  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(proj, i)
    if reaper.IsMediaItemSelected(item) then
      sel_cnt = sel_cnt + 1
    end
  end

  return sel_cnt
end

-- 保存当前选中的媒体对象
function SaveSelectedItems(t)
  local proj = 0 -- 获取当前工程
  local cnt = reaper.CountMediaItems(proj) -- 获取媒体对象的数量
  for i = 0, cnt - 1 do
    local item = reaper.GetMediaItem(proj, i)
    if reaper.IsMediaItemSelected(item) then
      table.insert(t, item) -- 仅保存选中的对象
    end
  end
end

-- 恢复选中的媒体对象
function RestoreSelectedItems(t)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
  for _, item in ipairs(t) do
    if item then
      reaper.SetMediaItemSelected(item, true) -- 恢复选中的对象
    end
  end
end

-- 获取 Take 的源文件路径
function GetTakeSourceFilePath(take)
  if not take then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end
  local path = reaper.GetMediaSourceFileName(source, "")
  return path
end

-- 收集选中对象的源文件路径
function CollectSelectedSourcePaths()
  local selected_paths = {}
  local cnt = CountSelectedItems(0)
  for i = 0, cnt-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local path = GetTakeSourceFilePath(take)
    if path and path ~= "" then
      selected_paths[path] = true -- 记录路径，便于查找
    end
  end
  return selected_paths
end

-- 根据源路径选中对应的媒体对象
function SelectItemsBySourcePaths(selected_paths)
  local cnt = reaper.CountMediaItems(0)
  for i = 0, cnt-1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local path = GetTakeSourceFilePath(take)
    if path and selected_paths[path] then
      reaper.SetMediaItemSelected(item, true)
    end
  end
end

-- 分离文件名和扩展名
function SplitNameExt(filename)
  local ext = filename:match("%.[^%.]+$") or ""
  if ext ~= "" then
    return filename:sub(1, #filename - #ext), ext
  else
    return filename, ""
  end
end

function OfflineSources(items)
  local state = {} -- key: take 对象, value: 离线前是否在线
  for _, rec in ipairs(items) do
    local take = rec.take
    local src  = reaper.GetMediaItemTake_Source(take)
    -- 对每个 take 独立记录并离线
    local wasOnline = reaper.CF_GetMediaSourceOnline(src)
    state[take] = wasOnline
    if wasOnline then
      reaper.CF_SetMediaSourceOnline(src, false)
    end
  end
  return state
end

-- 检测文件是否存在
function FileExists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

-- 收集选中媒体对象及其源路径
function CollectAudioSources()
  local cnt = CountSelectedItems(0)
  local items, uniqueList, seen = {}, {}, {}
  for i = 0, cnt - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local src = reaper.GetMediaItemTake_Source(take)
      local path = reaper.GetMediaSourceFileName(src, "")
      if path ~= "" then
        table.insert(items, { item = item, take = take, oldPath = path })
        if not seen[path] then
          seen[path] = true
          table.insert(uniqueList, path)
        end
      end
    end
  end
  if #uniqueList == 0 then
    reaper.ShowMessageBox(T.selected_items_no_audio, T.error, 0)
    return nil
  end
  return items, uniqueList
end

--------------------------------------------------------------------------------
-- 区域/标记相关函数
--------------------------------------------------------------------------------
function GetRegionMarkerManager()
  local title = reaper.JS_Localize("Region/Marker Manager", "common")
  local arr = reaper.new_array({}, 1024)
  reaper.JS_Window_ArrayFind(title, true, arr)
  for _, addr in ipairs(arr.table()) do
    local hwnd = reaper.JS_Window_HandleFromAddress(addr)
    -- 验证这个窗口确实是 Region Manager：检查是否有 ID=1056 的子控件
    if reaper.JS_Window_FindChildByID(hwnd, 1056) then
      return hwnd
    end
  end
end

function get_all_regions_mgr()
  local res = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and isrgn then
      table.insert(res, {
        index   = idx,
        isrgn   = true,
        left    = pos,
        right   = rgnend,
        name    = name,
        color   = color,
      })
    end
  end
  -- 按左边界排序(可选)
  -- table.sort(res, function(a,b) return a.left < b.left end)
  return res
end

function get_all_markers_mgr()
  local res = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    -- 只保留 Marker (isrgn == false) 
    if retval and not isrgn then
      table.insert(res, {
        index = idx,
        isrgn = false,
        pos   = pos,
        name  = name,
        color = color,
      })
    end
  end
  -- 按时间位置排序(可选)
  -- table.sort(res, function(a,b) return a.pos < b.pos end)
  return res
end

function get_sel_regions_mgr()
  local hwnd = GetRegionMarkerManager()
  if not hwnd then return {} end
  local container = reaper.JS_Window_FindChildByID(hwnd, 1071) -- ListView 控件
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
  if sel_count == 0 then return {} end

  local all = get_all_regions_mgr()
  local out = {}

  -- sel_indexes 是逗号分隔的行号，直接去读第一列(区域编号)
  for _, row in ipairs( {} ) do end -- 占位用
  for id_str in sel_indexes:gmatch("[^,]+") do
    -- 读取第 1 列: 区域在项目中的索引号
    local txt = reaper.JS_ListView_GetItemText(container, tonumber(id_str), 1)
    local idx = tonumber( txt:match("(%d+)") )
    if idx then
      for _, r in ipairs(all) do
        if r.index == idx then
          table.insert(out, r)
          break
        end
      end
    end
  end
  return out
end

function get_sel_markers_mgr()
  local hwnd = GetRegionMarkerManager()
  if not hwnd then return {} end
  local container = reaper.JS_Window_FindChildByID(hwnd, 1071) -- ListView 控件
  local sel_count, sel_indexes = reaper.JS_ListView_ListAllSelItems(container)
  if sel_count == 0 then return {} end

  local all = get_all_markers_mgr()
  local out = {}

  for id_str in sel_indexes:gmatch("[^,]+") do
    -- 读取第 1 列: Marker 在项目中的索引号
    local txt = reaper.JS_ListView_GetItemText(container, tonumber(id_str), 1)
    local idx = tonumber(txt:match("(%d+)"))
    if idx then
      for _, m in ipairs(all) do
        if m.index == idx then
          table.insert(out, m)
          break
        end
      end
    end
  end

  return out
end

function set_regions_mgr(region)
  reaper.SetProjectMarker3(
    0,
    region.index,
    region.isrgn,
    region.left,
    region.right,
    region.name,
    region.color
  )
end

function set_markers_mgr(marker)
  reaper.SetProjectMarker3(
    0,
    marker.index,
    marker.isrgn,
    marker.pos,
    marker.pos,
    marker.name,
    marker.color
  )
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

function get_all_markers()
  local result = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, _, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
    if retval and not isrgn then
      table.insert(result, {
        index = markrgnindexnumber,
        pos   = pos,
        name  = name,
        color = color,
      })
    end
  end
  return result
end

function get_sel_regions()
  -- 获取时间选区
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then return {} end

  -- 枚举项目中所有 region
  local out = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, is_region, pos, rgnend, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and is_region then
      -- 如果 region 完全在选区范围内就保留
      if pos >= sel_start and rgnend <= sel_end then
        table.insert(out, {
          index = idx,
          isrgn = true,
          left  = pos,
          right = rgnend,
          name  = name,
          color = color,
        })
      end
    end
  end
  -- 按 index 或 left 排序 (可选)
  -- table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

function get_sel_markers()
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then return {} end

  local out = {}
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, is_region, pos, _, name, idx, color = reaper.EnumProjectMarkers3(0, i)
    if retval and not is_region then
      if pos >= sel_start and pos <= sel_end then
        table.insert(out, {
          index = idx,
          isrgn = false,
          pos   = pos,
          name  = name,
          color = color,
        })
      end
    end
  end
  -- 按 index 排序 (可选)
  -- table.sort(out, function(a,b) return a.index < b.index end)
  return out
end

function selected_region_marker_api_error()
  if not (reaper.GetNumRegionsOrMarkers and
          reaper.GetRegionOrMarker and
          reaper.GetRegionOrMarkerInfo_Value and
          reaper.GetSetRegionOrMarkerInfo_String) then
    return T.selected_region_marker_requires_newer
  end
end

function get_selected_region_markers(want_region)
  local api_error = selected_region_marker_api_error()
  if api_error then return nil, api_error end

  local out = {}
  local total = reaper.GetNumRegionsOrMarkers(0)
  for i = 0, total - 1 do
    local marker = reaper.GetRegionOrMarker(0, i, "")
    if marker then
      local is_region = reaper.GetRegionOrMarkerInfo_Value(0, marker, "B_ISREGION") ~= 0
      local selected  = reaper.GetRegionOrMarkerInfo_Value(0, marker, "B_UISEL") ~= 0
      if selected and is_region == want_region then
        local _, name = reaper.GetSetRegionOrMarkerInfo_String(0, marker, "P_NAME", "", false)
        local index = math.floor((reaper.GetRegionOrMarkerInfo_Value(0, marker, "I_NUMBER") or 0) + 0.5)
        local pos = reaper.GetRegionOrMarkerInfo_Value(0, marker, "D_STARTPOS") or 0
        local rgnend = reaper.GetRegionOrMarkerInfo_Value(0, marker, "D_ENDPOS") or pos
        local color = reaper.GetRegionOrMarkerInfo_Value(0, marker, "I_CUSTOMCOLOR") or 0
        table.insert(out, {
          marker = marker,
          index  = index,
          isrgn  = is_region,
          left   = pos,
          right  = rgnend,
          pos    = pos,
          name   = name or "",
          color  = color,
        })
      end
    end
  end

  return out
end

function get_selected_project_regions()
  return get_selected_region_markers(true)
end

function get_selected_project_markers()
  return get_selected_region_markers(false)
end

function set_selected_region_marker_name(rec, name)
  return reaper.GetSetRegionOrMarkerInfo_String(0, rec.marker, "P_NAME", name or "", true)
end

function get_sel_regions_for_items()
  local all_regions = get_all_regions()
  if #all_regions == 0 then return {} end

  -- 没选 Items，直接返回空
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then return {} end

  -- 收集所有选中 Item 的时间区间
  local items = {}
  for i = 0, item_count-1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    local p  = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    local l  = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    table.insert(items, { left = p, right = p + l })
  end
  -- 合并相交区间
  table.sort(items, function(a,b) return a.left < b.left end)
  local merged = {}
  local cur = { left = items[1].left, right = items[1].right }
  for _, it in ipairs(items) do
    if it.left <= cur.right then
      cur.right = math.max(cur.right, it.right)
    else
      table.insert(merged, cur)
      cur = { left = it.left, right = it.right }
    end
  end
  table.insert(merged, cur)

  -- 对每个合并区间，找出所有 overlap 的 Region
  local sel = {}
  for _, mr in ipairs(merged) do
    for _, r in ipairs(all_regions) do
      if r.left < mr.right and r.right > mr.left then
        sel[r.index] = r
      end
    end
  end

  -- 转成数组并按 index 排序
  local out = {}
  for idx, rgn in pairs(sel) do table.insert(out, rgn) end
  table.sort(out, function(a,b) return a.index < b.index end)
  return out
end

function set_region(region)
  reaper.SetProjectMarker3(0, region.index, region.isrgn, region.left, region.right, region.name, region.color)
end

function set_marker(marker)
  reaper.SetProjectMarker3(0, marker.index, false, marker.pos, marker.pos, marker.name, marker.color)
end

--------------------------------------------------------------------------------
-- Build 相关函数 通配符
--------------------------------------------------------------------------------
function build_items(build_pattern, origin_name, tname, track_num, folders, take, i)
  build_pattern = build_pattern or ""
  origin_name   = origin_name   or ""
  tname         = tname         or ""
  track_num     = track_num     or 0
  folders       = folders       or ""
  i             = tonumber(i)   or 1

  -- 通用 token 替换
  local name = apply_modifiers(build_pattern, i)
  local guid = ""
  if take then
    local _, g = reaper.GetSetMediaItemTakeInfo_String(take, "GUID", "", false)
    guid = g or ""
  end
  name = expand_wildcard(name, "tracknumber", track_num)
  name = expand_wildcard(name, "folders", folders, true)
  name = expand_wildcard(name, "track", tname, true)
  name = expand_wildcard(name, "item", origin_name, true)
  name = expand_wildcard(name, "GUID", guid)

  -- 继承循环/累加/随机等功能
  return name
end

function build_tracks(pat, origin, guid, num, parent, i)
  pat    = pat    or ""
  origin = origin or ""
  guid   = guid   or ""
  num    = num    or 0
  i      = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pat, i)
  name = expand_wildcard(name, "tracknumber", num)
  name = expand_wildcard(name, "GUID", guid)
  name = expand_wildcard(name, "folders", parent or "", true)
  name = expand_wildcard(name, "track", origin, true)

  return name
end

function build_region_manager(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pattern, i)
  name = expand_wildcard(name, "regionidx", i)
  name = expand_wildcard(name, "regionid", region_id)
  name = expand_wildcard(name, "region", origin_name, true)

  return name
end

function build_region_time(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pattern, i)
  name = expand_wildcard(name, "regionidx", i)
  name = expand_wildcard(name, "regionid", region_id)
  name = expand_wildcard(name, "region", origin_name, true)

  return name
end

function build_region_for_items(pattern, origin_name, region_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  region_id   = region_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pattern, i)
  name = expand_wildcard(name, "regionidx", i)
  name = expand_wildcard(name, "regionid", region_id)
  name = expand_wildcard(name, "region", origin_name, true)

  return name
end

function build_marker_manager(pattern, origin_name, marker_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  marker_id   = marker_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pattern, i)
  name = expand_wildcard(name, "markeridx", i)
  name = expand_wildcard(name, "markerid", marker_id)
  name = expand_wildcard(name, "marker", origin_name, true)

  return name
end

function build_marker_time(pattern, origin_name, marker_id, i)
  pattern     = pattern     or ""
  origin_name = origin_name or ""
  marker_id   = marker_id   or 0
  i           = tonumber(i) or 1

  -- 通用 token 替换
  local name = apply_modifiers(pattern, i)
  name = expand_wildcard(name, "markeridx", i)
  name = expand_wildcard(name, "markerid", marker_id)
  name = expand_wildcard(name, "marker", origin_name, true)

  return name
end

function build_project_marker_result(origin_name, marker_id, seq, build_fn)
  local new_name = origin_name or ""

  if enable_rename and rename_pattern ~= "" then
    new_name = build_fn(rename_pattern, origin_name, marker_id, seq)
  end

  if enable_replace and find_text ~= "" then
    local pat = escape_pattern(find_text)
    if not match_case then
      pat = make_case_insensitive_pattern(pat)
    end
    local repl = build_fn(replace_text or "", origin_name, marker_id, seq)
    if occurrence_mode == 0 then
      new_name = replace_first(new_name, pat, repl)
    elseif occurrence_mode == 1 then
      new_name = replace_last(new_name, pat, repl)
    else
      new_name = replace_all(new_name, pat, repl)
    end
  end

  if enable_remove and remove_count > 0 then
    local name_length = utf8.len(new_name) or #new_name
    local safe_remove_cnt = math.min(remove_count, 100)
    local safe_remove_pos = math.max(0, math.min(remove_position, 100))
    local s_i, e_i
    if remove_side_index == 0 then
      if safe_remove_pos < name_length then
        s_i = safe_remove_pos
        e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
      end
    else
      if safe_remove_pos < name_length then
        e_i = name_length - safe_remove_pos - 1
        s_i = math.max(0, e_i - safe_remove_cnt + 1)
      end
    end
    if s_i then
      local b1 = utf8.offset(new_name, s_i + 1) or 1
      local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
      new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
    end
  end

  if enable_insert and insert_text ~= "" then
    local insert_str = build_fn(insert_text, origin_name, marker_id, seq)
    local name_length = utf8.len(new_name) or #new_name
    local safe_insert_pos = math.max(0, math.min(insert_position, 100))
    local insert_i
    if insert_side_index == 0 then
      insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
    else
      insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
    end
    local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
    new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
  end

  return new_name
end

function build_sources(build_pattern, origin_name, tname, track_num, folders, i)
  build_pattern = build_pattern or ""
  origin_name   = origin_name   or ""
  tname         = tname         or ""
  track_num     = track_num     or 0
  folders       = folders       or ""
  i             = tonumber(i)   or 1

  -- 通用 token 替换
  local name = apply_modifiers(build_pattern, i)
  name = expand_wildcard(name, "tracknumber", track_num)
  name = expand_wildcard(name, "folders", folders, true)
  name = expand_wildcard(name, "track", tname, true)
  name = expand_wildcard(name, "source", origin_name, true)

  return name
end

--------------------------------------------------------------------------------
-- 0 批量重命名Items
--------------------------------------------------------------------------------
function get_sorted_items_data()
  local cnt = reaper.CountSelectedMediaItems(0)
  local items = {}
  -- 1. 收集原始数据
  for i = 0, cnt-1 do
    local item   = reaper.GetSelectedMediaItem(0, i)
    local take = item and reaper.GetActiveTake(item)
    local orig = take and reaper.GetTakeName(take) or ""
    local track = reaper.GetMediaItem_Track(item)
    local _, tname = reaper.GetTrackName(track, "")
    local tnum = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)
    local parent = reaper.GetParentTrack(track)
    local folders = parent and select(2, reaper.GetTrackName(parent, "")) or ""
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    table.insert(items, {
      item       = item,
      take       = take,
      orig_name  = orig,
      tname      = tname,
      track_num  = tnum,
      folders    = folders,
      position   = pos
    })
  end
  -- 2. 排序逻辑统一处理
  if sort_index == 0 then
    -- 按轨道排序
    local groups = {}
    for _, d in ipairs(items) do
      groups[d.track_num] = groups[d.track_num] or {}
      table.insert(groups[d.track_num], d)
    end
    local tnums = {}
    for tn in pairs(groups) do table.insert(tnums, tn) end
    table.sort(tnums)
    local sorted = {}
    for _, tn in ipairs(tnums) do
      local grp = groups[tn]
      table.sort(grp, function(a,b) return a.position < b.position end)
      for seq, d in ipairs(grp) do
        d.seqIndex = seq
        table.insert(sorted, d)
      end
    end
    items = sorted
  elseif sort_index == 2 then
    -- 按时间线排序
    table.sort(items, function(a,b)
      if a.position == b.position then return a.track_num < b.track_num end
      return a.position < b.position
    end)
    for i, d in ipairs(items) do d.seqIndex = i end
  else
    -- 按原始 Selection 顺序
    for i, d in ipairs(items) do d.seqIndex = i end
  end
  return items
end

function apply_batch_items()
  -- 1. 基本检查
  local item_count = reaper.CountSelectedMediaItems(0)
  if item_count == 0 then
    reaper.ShowMessageBox(T.no_media_items_selected, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  -- 2. 收集数据
  local items = get_sorted_items_data()

  -- 4. 开始 Undo
  reaper.Undo_BeginBlock()
  local changed_any = false

  -- 5. 遍历 items，应用四大功能
  for idx, data in ipairs(items) do
    local new_name = data.orig_name
    local seq = (sort_index == 0 and data.seqIndex) or idx

    -- 5.1 Rename 用 build_items 展开
    if enable_rename and rename_pattern ~= "" then
      new_name = build_items(
        rename_pattern,
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )
    end

    -- 5.2 Replace 也用 build_items 先展开 replace_text
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_items(
        replace_text or "",
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )
      -- 根据 Occurrence 模式执行替换
      if occurrence_mode == 0 then
        -- First: 仅替换首个匹配
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        -- Last: 仅替换最后一个匹配
        new_name = replace_last(new_name, pat, repl)
      else
        -- All: 默认替换所有匹配
        new_name = replace_all(new_name, pat, repl)
      end
    end

    -- 5.3 Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name) or #new_name
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      if safe_remove_pos < 0 then safe_remove_pos = 0 end

      local s_i, e_i
      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s_i = safe_remove_pos
          e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e_i = name_length - safe_remove_pos - 1
          s_i = e_i - safe_remove_cnt + 1
          if s_i < 0 then s_i = 0 end
        end
      end

      if s_i then
        local b1 = utf8.offset(new_name, s_i + 1) or 1
        local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
        new_name = string.sub(new_name, 1, b1 - 1) .. string.sub(new_name, b2)
      end
    end

    -- 5.4 Insert 同样先用 build_items 展开 insert_text
    if enable_insert and insert_text ~= "" then
      local insert_str = build_items(
        insert_text,
        data.orig_name,
        data.tname,
        data.track_num,
        data.folders,
        data.take,
        seq
      )

      local name_length = utf8.len(new_name) or #new_name
      local safe_insert_pos = math.min(insert_position, 100)
      if safe_insert_pos < 0 then safe_insert_pos = 0 end
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = string.sub(new_name, 1, b - 1) .. insert_str .. string.sub(new_name, b)
    end

    -- 6. 写回新名字
    if data.take and new_name ~= data.orig_name then
      reaper.GetSetMediaItemTakeInfo_String(data.take, "P_NAME", new_name, true)
      changed_any = true
    end
  end

  -- 7. 结束 Undo
  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 1 批量重命名Tracks
--------------------------------------------------------------------------------
function apply_batch_tracks()
  local cnt = reaper.CountSelectedTracks(0)
  if cnt == 0 then
    reaper.ShowMessageBox(T.no_tracks_selected, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for i = 0, cnt - 1 do
    local track     = reaper.GetSelectedTrack(0,i)
    local _, origin = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local guid      = reaper.BR_GetMediaTrackGUID(track)
    local track_num = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5)
    local parent    = reaper.GetParentTrack(track) and select(2, reaper.GetTrackName(reaper.GetParentTrack(track), "")) or ""
    local new_name  = origin

    -- 1) Rename
    if enable_rename and rename_pattern~="" then
      new_name = build_tracks(rename_pattern, origin, guid, track_num, parent, i + 1)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_tracks(replace_text, origin, guid, track_num, parent, i + 1)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end

    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_tracks(insert_text, origin, guid, track_num, parent, i + 1)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= origin then
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_name, true)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 2 批量重命名 Regions Manager
--------------------------------------------------------------------------------
function apply_batch_region_manager()
  local hWnd = GetRegionMarkerManager()
  if not hWnd then
    reaper.ShowMessageBox(T.open_region_marker_manager_msg, TITLE, 0)
    return
  end
  local regions = get_sel_regions_mgr()
  if #regions == 0 then
    reaper.ShowMessageBox(T.no_regions_manager, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig = region.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_manager(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_manager(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_manager(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      region.name = new_name
      set_regions_mgr(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 3 批量重命名 Regions (Time Selection)
--------------------------------------------------------------------------------
function apply_batch_region_time()
  -- 获取时间选区
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then
    reaper.ShowMessageBox(T.no_time_selection, TITLE, 0)
    return
  end

  -- 获取选区内区域
  local regions = get_sel_regions()
  if #regions == 0 then
    reaper.ShowMessageBox(T.no_regions_time, TITLE, 0)
    return
  end

  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig = region.name
    local new_name  = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_time(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_time(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_time(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      region.name = new_name
      set_region(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 4 批量重命名 Regions (Selected Regions)
--------------------------------------------------------------------------------
function apply_batch_selected_regions()
  local regions, err = get_selected_project_regions()
  if not regions then
    reaper.ShowMessageBox(err, TITLE, 0)
    return
  end
  if #regions == 0 then
    reaper.ShowMessageBox(T.no_regions_arrange, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig = region.name
    local new_name = build_project_marker_result(orig, region.index, idx, build_region_time)
    if new_name ~= orig then
      if set_selected_region_marker_name(region, new_name) then
        changed_any = true
      end
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 5 批量重命名 Regions For Items
--------------------------------------------------------------------------------
function apply_batch_regions_for_items()
  local regions = get_sel_regions_for_items()
  if #regions == 0 then
    reaper.ShowMessageBox(T.no_regions_items, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, region in ipairs(regions) do
    local orig     = region.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_region_for_items(rename_pattern, orig, region.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_region_for_items(replace_text or "", orig, region.index, idx)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) 插入
    if enable_insert and insert_text ~="" then
      local insert_str = build_region_for_items(insert_text, orig, region.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    -- 写回
    if new_name ~= orig then
      region.name = new_name
      set_region(region)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 5 批量重命名 Markers Manager
--------------------------------------------------------------------------------
function apply_batch_marker_manager()
  local hWnd = GetRegionMarkerManager()
  if not hWnd then
    reaper.ShowMessageBox(T.open_region_marker_manager_msg, TITLE, 0)
    return
  end

  local markers = get_sel_markers_mgr()
  if #markers == 0 then
    reaper.ShowMessageBox(T.no_markers_manager, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, marker in ipairs(markers) do
    local orig     = marker.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_marker_manager(rename_pattern, orig, marker.index, idx)
    end
    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_marker_manager(replace_text or "", orig, marker.index, idx)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end
    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end
    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_marker_manager(insert_text, orig, marker.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      marker.name = new_name
      set_markers_mgr(marker)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 7 批量重命名 Markers (Selected Markers)
--------------------------------------------------------------------------------
function apply_batch_selected_markers()
  local markers, err = get_selected_project_markers()
  if not markers then
    reaper.ShowMessageBox(err, TITLE, 0)
    return
  end
  if #markers == 0 then
    reaper.ShowMessageBox(T.no_markers_arrange, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, marker in ipairs(markers) do
    local orig = marker.name
    local new_name = build_project_marker_result(orig, marker.index, idx, build_marker_time)
    if new_name ~= orig then
      if set_selected_region_marker_name(marker, new_name) then
        changed_any = true
      end
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 8 批量重命名 Markers (Time Selection)
--------------------------------------------------------------------------------
function apply_batch_marker_time()
  local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if sel_start == sel_end then
    reaper.ShowMessageBox(T.no_time_selection, TITLE, 0)
    return
  end
  local markers = get_sel_markers()
  if #markers == 0 then
    reaper.ShowMessageBox(T.no_markers_time, TITLE, 0)
    return
  end

  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  reaper.Undo_BeginBlock()
  local changed_any = false

  for idx, marker in ipairs(markers) do
    local orig     = marker.name
    local new_name = orig

    -- 1) Rename
    if enable_rename and rename_pattern ~= "" then
      new_name = build_marker_time(rename_pattern, orig, marker.index, idx)
    end

    -- 2) Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_marker_time(replace_text or "", orig, marker.index, idx)
      if occurrence_mode == 0 then
        new_name = replace_first(new_name, pat, repl)
      elseif occurrence_mode == 1 then
        new_name = replace_last(new_name, pat, repl)
      else
        new_name = replace_all(new_name, pat, repl)
      end
    end

    -- 3) Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_name)
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      local s, e

      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s = safe_remove_pos
          e = math.min(name_length - 1, s + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e = name_length - safe_remove_pos - 1
          s = e - safe_remove_cnt + 1
          if s < 0 then s = 0 end end
      end

      if s then
        local b1 = utf8.offset(new_name, s + 1) or 1
        local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
        new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
      end
    end

    -- 4) Insert
    if enable_insert and insert_text ~="" then
      local insert_str = build_marker_time(insert_text, orig, marker.index, idx)
      local name_length = utf8.len(new_name)
      local safe_insert_pos = math.min(insert_position, 100)
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
      new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
    end

    if new_name ~= orig then
      marker.name = new_name
      set_marker(marker)
      changed_any = true
    end
  end

  if changed_any then
    reaper.Undo_EndBlock(T.undo_batch, -1)
    reaper.UpdateArrange()
  else
    reaper.Undo_EndBlock(T.undo_no_changes, -1)
    reaper.ShowMessageBox(T.no_changes, TITLE, 0)
  end
end

--------------------------------------------------------------------------------
-- 7 批量重命名 源文件
--------------------------------------------------------------------------------
function get_sorted_sources_data()
  local cnt   = CountSelectedItems(0)
  local items = {}

  -- 1. 收集原始数据
  for i = 0, cnt-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    if not item then goto continue end

    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then goto continue end

    -- 源文件对象及路径
    local src  = reaper.GetMediaItemTake_Source(take)
    local path = reaper.GetMediaSourceFileName(src, "")
    if not path or path == "" then goto continue end

    -- 轨道信息
    local track   = reaper.GetMediaItem_Track(item)
    local _, tname = reaper.GetTrackName(track, "")
    local tnum   = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)
    local parent = reaper.GetParentTrack(track)
    local folders = parent and select(2, reaper.GetTrackName(parent, "")) or ""

    -- item 在时间线上的位置
    local pos    = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    table.insert(items, {
      item      = item,
      take      = take,
      src       = src,
      path      = path,
      orig_name = path:match("[^\\/]+$") or "",
      tname     = tname,
      track_num = tnum,
      folders   = folders,
      position  = pos,
      seqIndex  = 0,   -- 占位，后面会填
    })

    ::continue::
  end

  -- 2. 排序逻辑
  if sort_index == 0 then
    -- 按轨道分组，再按同轨道内时间线排序
    local groups = {}
    for _, d in ipairs(items) do
      groups[d.track_num] = groups[d.track_num] or {}
      table.insert(groups[d.track_num], d)
    end

    local tnums = {}
    for tn in pairs(groups) do table.insert(tnums, tn) end
    table.sort(tnums)

    local sorted = {}
    for _, tn in ipairs(tnums) do
      local grp = groups[tn]
      table.sort(grp, function(a,b) return a.position < b.position end)
      for seq, d in ipairs(grp) do
        d.seqIndex = seq
        table.insert(sorted, d)
      end
    end
    items = sorted

  elseif sort_index == 2 then
    -- 跨轨道时间线排序
    table.sort(items, function(a,b)
      if a.position == b.position then return a.track_num < b.track_num end
      return a.position < b.position
    end)
    for i, d in ipairs(items) do d.seqIndex = i end

  else
    -- 原始选中顺序
    for i, d in ipairs(items) do d.seqIndex = i end
  end

  return items
end

function apply_batch_sources()
  -- 基本检查
  local sel_cnt = CountSelectedItems(0)
  if sel_cnt == 0 then
    reaper.ShowMessageBox(T.no_media_items_selected, TITLE, 0)
    return
  end
  if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    reaper.ShowMessageBox(T.no_options_selected, TITLE, 0)
    return
  end

  -- 保存当前选中状态，禁用界面刷新并开始 Undo
  local init_sel_items = {}
  SaveSelectedItems(init_sel_items)
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()

  local src_paths = CollectSelectedSourcePaths()
  SelectItemsBySourcePaths(src_paths)

  -- 收集并排序所有源文件数据
  local items = get_sorted_sources_data()
  if #items == 0 then
    RestoreSelectedItems(init_sel_items)
    reaper.Undo_EndBlock(T.undo_no_source_files, -1)
    reaper.PreventUIRefresh(-1)
    reaper.ShowMessageBox(T.no_valid_source_files, TITLE, 0)
    return
  end

  -- 构建唯一源列表 (每条路径只保留一次) 
  local seen_paths = {}
  local uniqueRecs = {}
  for _, d in ipairs(items) do
    if not seen_paths[d.path] then
      seen_paths[d.path] = true
      table.insert(uniqueRecs, d)
    end
  end

  -- 轨道和时间线排序，基于选中的item的源文件数量。
  if sort_index == 1 or sort_index == 2 then
    for i, rec in ipairs(uniqueRecs) do
      rec.seqIndex = i
    end
  end

  -- 用 build_sources + replace/删除/插入 生成 nameMap
  local nameMap = {}
  for _, rec in ipairs(uniqueRecs) do
    -- 拆分文件名/扩展
    local filename = rec.path:match("[^\\/]+$") or ""
    local base, ext = SplitNameExt(filename)
    local seq = rec.seqIndex

    -- Rename
    local new_base = base
    if enable_rename and rename_pattern ~= "" then
      new_base = build_sources(rename_pattern, base, rec.tname, rec.track_num, rec.folders, seq)
    end

    -- Replace
    if enable_replace and find_text ~= "" then
      local pat = escape_pattern(find_text)
      if not match_case then
        pat = make_case_insensitive_pattern(pat)
      end
      local repl = build_sources(replace_text, base, rec.tname, rec.track_num, rec.folders, seq)
      if occurrence_mode == 0 then
        new_base = replace_first(new_base, pat, repl)
      elseif occurrence_mode == 1 then
        new_base = replace_last(new_base, pat, repl)
      else
        new_base = replace_all(new_base, pat, repl)
      end
    end

    -- Remove
    if enable_remove and remove_count > 0 then
      local name_length = utf8.len(new_base) or #new_base
      local safe_remove_cnt = math.min(remove_count, 100)
      local safe_remove_pos = math.min(remove_position, 100)
      if safe_remove_pos < 0 then safe_remove_pos = 0 end

      local s_i, e_i
      if remove_side_index == 0 then
        if safe_remove_pos < name_length then
          s_i = safe_remove_pos
          e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
        end
      else
        if safe_remove_pos < name_length then
          e_i = name_length - safe_remove_pos - 1
          s_i = e_i - safe_remove_cnt + 1
          if s_i < 0 then s_i = 0 end
        end
      end

      if s_i then
        local b1 = utf8.offset(new_base, s_i + 1) or 1
        local b2 = utf8.offset(new_base, e_i + 2) or (#new_base + 1)
        new_base = string.sub(new_base, 1, b1 - 1) .. string.sub(new_base, b2)
      end
    end

    -- Insert
    if enable_insert and insert_text ~= "" then
      local insert_str = build_sources(insert_text, base, rec.tname, rec.track_num, rec.folders, seq)
      local name_length = utf8.len(new_base) or #new_base
      local safe_insert_pos = math.min(insert_position, 100)
      if safe_insert_pos < 0 then safe_insert_pos = 0 end
      local insert_i

      if insert_side_index == 0 then
        insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
      else
        insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
      end

      local b = utf8.offset(new_base, insert_i + 1) or (#new_base + 1)
      new_base = string.sub(new_base, 1, b - 1) .. insert_str .. string.sub(new_base, b)
    end

    nameMap[rec.path] = new_base .. ext
  end

  -- 冲突修复(同名加 -001, -002...)
  local count_seen = {}
  for _, rec in ipairs(uniqueRecs) do
    local nm = nameMap[rec.path]
    count_seen[nm] = (count_seen[nm] or 0) + 1
    if count_seen[nm] > 1 then
      local ext = nm:match("(%.[^%.]+)$") or ""
      local base = nm:sub(1, #nm - #ext)
      nameMap[rec.path] = base .. string.format("-%03d", count_seen[nm]-1) .. ext
    end
  end

  -- 离线所有源、执行重命名并更新引用
  local origState = OfflineSources(items)
  local errors = {}
  local function update_source_refs(oldPath, newPath, newName)
    for _, d in ipairs(items) do
      if d.path == oldPath then
        reaper.BR_SetTakeSourceFromFile(d.take, newPath, false)
        if write_take_name then
          reaper.GetSetMediaItemTakeInfo_String(d.take, "P_NAME", newName, true)
        end
      end
    end
  end

  for _, rec in ipairs(uniqueRecs) do
    local oldPath = rec.path
    local newName = nameMap[oldPath]
    local dir     = oldPath:match("^(.*[\\/])") or ""
    local newPath = dir .. newName

    if oldPath == newPath then
      update_source_refs(oldPath, newPath, newName)
    elseif not FileExists(oldPath) then
      table.insert(errors, tr("does_not_exist", oldPath))
    else
      local ok, err = os.rename(oldPath, newPath)
      if not ok then
        ok, err = os.rename(oldPath:gsub("\\","/"), newPath:gsub("\\","/"))
      end
      if ok then
        -- 更新所有引用相同源的 take
        for _, d in ipairs(items) do
          if d.path == oldPath then
            reaper.BR_SetTakeSourceFromFile(d.take, newPath, false)
            if write_take_name then
              -- 使用没有后缀的命名
              -- local onlyName = newName:gsub("%.[^%.]+$", "")
              -- reaper.GetSetMediaItemTakeInfo_String(d.take, "P_NAME", onlyName, true)
              reaper.GetSetMediaItemTakeInfo_String(d.take, "P_NAME", newName, true)
            end
          end
        end
      else
        table.insert(errors, tr("failed_rename", oldPath, newName, err or T.unknown))
      end
    end
  end

  -- 恢复在线状态、重建波形、还原选中、结束 Undo、刷新
  for _, d in ipairs(items) do
    local src = reaper.GetMediaItemTake_Source(d.take)
    reaper.CF_SetMediaSourceOnline(src, origState[d.take])
  end
  reaper.Main_OnCommand(40441, 0) -- Peaks: Rebuild peaks for selected items
  RestoreSelectedItems(init_sel_items)
  reaper.Undo_EndBlock(T.undo_batch, -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.MarkProjectDirty(0) -- 工程改动提示

  -- 打印错误日志
  if #errors > 0 then
    reaper.ShowConsoleMsg(T.renaming_errors_header)
    for _, e in ipairs(errors) do
      reaper.ShowConsoleMsg(e .. "\n")
    end
  end
end

function apply_batch_rename()
  if process_mode == 0 then
    -- Items 模式
    -- local cnt = reaper.CountSelectedMediaItems(0)
    -- if cnt == 0 then reaper.ShowMessageBox("No items selected.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_items()
  elseif process_mode == 1 then
    -- Tracks 模式
    -- local cnt = reaper.CountSelectedTracks(0)
    -- if cnt == 0 then reaper.ShowMessageBox("No tracks selected.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_tracks()
  elseif process_mode == 2 then
    -- Region Manager 模式
    apply_batch_region_manager()
  elseif process_mode == 3 then
    -- Regions (Time Selection) 模式
    -- local sel_start, sel_end = reaper.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    -- if sel_start == sel_end then reaper.ShowMessageBox("No time selection.", "Error", 0) return end
    -- local regions = get_sel_regions()
    -- if #regions == 0 then reaper.ShowMessageBox("No regions found in time selection.", "Error", 0) return end
    -- if not (enable_rename or enable_replace or enable_remove or enable_insert) then
    --   reaper.ShowMessageBox("No options selected.", "Error", 0)
    --   return
    -- end
    apply_batch_region_time()
  elseif process_mode == 4 then
    apply_batch_selected_regions()
  elseif process_mode == 5 then
    apply_batch_regions_for_items()
  elseif process_mode == 6 then
    apply_batch_marker_manager()
  elseif process_mode == 7 then
    apply_batch_selected_markers()
  elseif process_mode == 8 then
    apply_batch_marker_time()
  elseif process_mode == 9 then
    apply_batch_sources()
  end
end

--------------------------------------------------------------------------------
-- 表格预览和构建
--------------------------------------------------------------------------------
function get_preview_data_and_builder()
  local data, builder
  if process_mode == 0 then
    data = get_sorted_items_data()
    builder =  function(i)
      local rec     = data[i]
      local orig     = rec.orig_name
      local seq      = rec.seqIndex
      local new_name = orig

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_items(rename_pattern, orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_items(replace_text or "", orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_items(insert_text, orig, rec.tname, rec.track_num, rec.folders, rec.take, seq)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Tracks
  elseif process_mode == 1 then
    data = {}
    for ti = 0, reaper.CountSelectedTracks(0)-1 do
      data[#data+1] = reaper.GetSelectedTrack(0, ti)
    end
    builder = function(i)
      local track    = data[i]
      local _, orig  = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      local guid     = reaper.BR_GetMediaTrackGUID(track)
      local num      = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5)
      local parent = reaper.GetParentTrack(track) and select(2, reaper.GetTrackName(reaper.GetParentTrack(track), "")) or ""
      local seq      = i
      local new_name  = orig

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_tracks(rename_pattern, orig, guid, num, parent, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_tracks(replace_text, orig, guid, num, parent, seq)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_tracks(insert_text, orig, guid, num, parent, seq)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Region Manager
  elseif process_mode == 2 then
    data = get_sel_regions_mgr()
    builder = function(i)
      local region   = data[i]
      local orig     = region.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_manager(rename_pattern, orig, region.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_manager(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end

      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end

      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_manager(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Regions (Time Selection)
  elseif process_mode == 3 then
    data = get_sel_regions()
    builder = function(i)
      local region = data[i]
      local orig = region.name
      local new_name  = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_time(rename_pattern, orig, region.index, i)
      end

      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_time(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_time(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Regions (Selected Regions)
  elseif process_mode == 4 then
    data = get_selected_project_regions() or {}
    builder = function(i)
      local region = data[i]
      local orig = region.name
      local new_name = build_project_marker_result(orig, region.index, i, build_region_time)
      return orig, new_name
    end

  -- 表格预览 - Regions for Selected Items
  elseif process_mode == 5 then
    data = get_sel_regions_for_items()
    builder = function(i)
      local region   = data[i]
      local orig     = region.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_region_for_items(rename_pattern, orig, region.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_region_for_items(replace_text or "", orig, region.index, i)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
  
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
  
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_region_for_items(insert_text, orig, region.index, i)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Marker Manager
  elseif process_mode == 6 then
    data = get_sel_markers_mgr()
    builder = function(i)
      local marker   = data[i]
      local orig     = marker.name
      local new_name = orig
  
      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_marker_manager(rename_pattern, orig, marker.index, i)
      end
  
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_marker_manager(replace_text or "", orig, marker.index, i)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
  
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name)
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.min(remove_position, 100)
        if safe_remove_pos < 0 then safe_remove_pos = 0 end
        local s, e

        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s = safe_remove_pos
            e = math.min(name_length - 1, s + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e = name_length - safe_remove_pos - 1
            s = e - safe_remove_cnt + 1
            if s < 0 then s = 0 end
          end
        end

        if s then
          local b1 = utf8.offset(new_name, s + 1) or 1
          local b2 = utf8.offset(new_name, e + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
  
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_marker_manager(insert_text, orig, marker.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end
  
      return orig, new_name
    end

  -- 表格预览 - Markers (Selected Markers)
  elseif process_mode == 7 then
    data = get_selected_project_markers() or {}
    builder = function(i)
      local marker = data[i]
      local orig = marker.name
      local new_name = build_project_marker_result(orig, marker.index, i, build_marker_time)
      return orig, new_name
    end

  -- 表格预览 - Marker (Time Selection)
  elseif process_mode == 8 then
    data = get_sel_markers()
    builder = function(i)
      local marker   = data[i]
      local orig     = marker.name
      local new_name = orig

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_marker_time(rename_pattern, orig, marker.index, i)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_marker_time(replace_text or "", orig, marker.index, i)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_marker_time(insert_text, orig, marker.index, i)
        local name_length = utf8.len(new_name)
        local safe_insert_pos = math.min(insert_position, 100)
        if safe_insert_pos < 0 then safe_insert_pos = 0 end
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name
    end

  -- 表格预览 - Source Files (Selected Items)
  elseif process_mode == 9 then
    data = get_sorted_sources_data()
    builder = function(i)
      local data     = data[i]
      local orig     = data.orig_name
      local base, ext = SplitNameExt(orig)
      local seq      = data.seqIndex
      local new_name = base

      -- 1) Rename
      if enable_rename and rename_pattern ~= "" then
        new_name = build_sources(rename_pattern, base, data.tname, data.track_num, data.folders, seq)
      end
      -- 2) Replace
      if enable_replace and find_text ~= "" then
        local pat = escape_pattern(find_text)
        if not match_case then
          pat = make_case_insensitive_pattern(pat)
        end
        local repl = build_sources(replace_text or "", base, data.tname, data.track_num, data.folders, seq)
        if occurrence_mode == 0 then
          new_name = replace_first(new_name, pat, repl)
        elseif occurrence_mode == 1 then
          new_name = replace_last(new_name, pat, repl)
        else
          new_name = replace_all(new_name, pat, repl)
        end
      end
      -- 3) Remove
      if enable_remove and remove_count > 0 then
        local name_length = utf8.len(new_name) or #new_name
        local safe_remove_cnt = math.min(remove_count, 100)
        local safe_remove_pos = math.max(0, math.min(remove_position, 100))
        local s_i, e_i
        if remove_side_index == 0 then
          if safe_remove_pos < name_length then
            s_i = safe_remove_pos
            e_i = math.min(name_length - 1, s_i + safe_remove_cnt - 1)
          end
        else
          if safe_remove_pos < name_length then
            e_i = name_length - safe_remove_pos - 1
            s_i = math.max(0, e_i - safe_remove_cnt + 1)
          end
        end
        if s_i then
          local b1 = utf8.offset(new_name, s_i + 1) or 1
          local b2 = utf8.offset(new_name, e_i + 2) or (#new_name + 1)
          new_name = new_name:sub(1, b1 - 1) .. new_name:sub(b2)
        end
      end
      -- 4) Insert
      if enable_insert and insert_text ~= "" then
        local insert_str = build_sources(insert_text, base, data.tname, data.track_num, data.folders, seq)
        local name_length = utf8.len(new_name) or #new_name
        local safe_insert_pos = math.max(0, math.min(insert_position, 100))
        local insert_i

        if insert_side_index == 0 then
          insert_i = (safe_insert_pos <= name_length) and safe_insert_pos or name_length
        else
          insert_i = (safe_insert_pos >= name_length) and 0 or (name_length - safe_insert_pos)
        end

        local b = utf8.offset(new_name, insert_i + 1) or (#new_name + 1)
        new_name = new_name:sub(1, b - 1) .. insert_str .. new_name:sub(b)
      end

      return orig, new_name .. ext
    end
  else
    data = {}
    builder = function() return "", "" end
  end
  return data, builder
end

-- function transparent_link(ctx, label, url)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
--   reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

--   if reaper.ImGui_Button(ctx, label) then
--     -- 在默认浏览器中打开指定链接
--     reaper.CF_ShellExecute(url)
--   end

--   reaper.ImGui_PopStyleColor(ctx, 3)
-- end

function transparent_link(ctx, label, url)
  -- 推入透明按钮样式
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  -- 计算按钮高度，让文字垂直居中
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, label)
  local button_h  = text_h + pad_y * 3.5

  -- 宽度设为 0 (自动)，高度设为 button_h
  if reaper.ImGui_Button(ctx, label, 0, button_h) then
    -- 在默认浏览器中打开指定链接
    reaper.CF_ShellExecute(url)
  end
  -- 弹出样式
  reaper.ImGui_PopStyleColor(ctx, 3)
end

function support_popup(ctx)
  local popup_id = ui_label("support", "SupportPopup")

  -- reaper.ImGui_PushFont(ctx, font_small)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, T.support)
  local button_h  = text_h + pad_y * 3.5

  if reaper.ImGui_Button(ctx, ui_label("support", "SupportButton"), 0, button_h) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end

  -- reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 3)

  -- 弹窗内容
  if reaper.ImGui_BeginPopupModal(ctx, popup_id, nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_Text(ctx, T.support_text_1)
    reaper.ImGui_Text(ctx, T.support_text_2)
    reaper.ImGui_Separator(ctx)

    -- “Visit” 透明按钮
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
    if reaper.ImGui_Button(ctx, ui_label("visit_soundengine", "VisitSoundEngineButton")) then
      reaper.CF_ShellExecute("https://www.soundengine.cn")
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_PopStyleColor(ctx, 3)

    reaper.ImGui_Separator(ctx)
    -- 关闭按钮
    if reaper.ImGui_Button(ctx, ui_label("close", "SupportCloseButton")) then
      reaper.ImGui_CloseCurrentPopup(ctx)
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

function preview_popup(ctx)
  -- “Preview” 按钮
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          yellow)

  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, T.preview)
  local button_h  = text_h + pad_y * 3.5

  reaper.ImGui_PushFont(ctx, font_small)
  if reaper.ImGui_Button(ctx, ui_label("preview", "PreviewMenuButton"), 0, button_h) then
    show_preview_window = true
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)

  -- 弹窗逻辑
  if show_preview_window then
    -- 首次打开时设置尺寸
    reaper.ImGui_SetNextWindowSize(ctx, 600, 400, reaper.ImGui_Cond_FirstUseEver())
    local data, builder = get_preview_data_and_builder()
    local title = tr("preview_objects", #data) .. "###Preview Panel"
    local visible, open = reaper.ImGui_Begin(ctx, title, show_preview_window)
    show_preview_window = open
    -- 保存当前状态到 ExtState，下次脚本启动时恢复
    reaper.SetExtState("BatchRenamePlus", "PopupPreviewOpen", tostring(show_preview_window), true)
    if visible then
      reaper.ImGui_PushItemWidth(ctx, -1)
      -- 创建并绘制文本过滤器
      if not preview_filter then
        preview_filter = reaper.ImGui_CreateTextFilter()
        reaper.ImGui_Attach(ctx, preview_filter)
      end
      reaper.ImGui_Text(ctx, T.filter)
      reaper.ImGui_SameLine(ctx, nil, 10)
      reaper.ImGui_TextFilter_Draw(preview_filter, ctx, "##Filter")

      -- 渲染预览表格
      -- local data, builder = get_preview_data_and_builder()
      render_preview_table_popup(ctx, PREVIEW_POPUP_TABLE_ID, #data, builder)

      reaper.ImGui_End(ctx)
    end
  end
end

-- 设置菜单
local stored_font = tonumber(reaper.GetExtState("BatchRenamePlus", "PreviewFontSize") or "")
if stored_font and stored_font >= 10 and stored_font <= 24 then
  preview_font_size = stored_font
end

local stored_show = reaper.GetExtState("BatchRenamePlus", "ShowMainPreview")
if stored_show == "true" then
  show_main_preview = true
elseif stored_show == "false" then
  show_main_preview = false
end

local stored_help_markers = reaper.GetExtState("BatchRenamePlus", "ShowHelpMarkers")
if stored_help_markers == "true" then
  show_help_markers = true
elseif stored_help_markers == "false" then
  show_help_markers = false
end

function DrawSettings(ctx)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, T.options)
  local button_h  = text_h + pad_y * 3.5

  reaper.ImGui_PushFont(ctx, font_small)
  if reaper.ImGui_Button(ctx, ui_label("options", "SettingsButton"), 0, button_h) then
    reaper.ImGui_OpenPopup(ctx, ui_label("options", "SettingsPopup"))
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 3)

  if reaper.ImGui_BeginPopupModal(ctx, ui_label("options", "SettingsPopup"), nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
    reaper.ImGui_SeparatorText(ctx, tr("interface"))
    -- reaper.ImGui_PushItemWidth(ctx, -95)
    if reaper.ImGui_BeginCombo(ctx, ui_label("language", "language_select"), get_language_label(language)) then
      for _, opt in ipairs(LANGUAGE_OPTIONS) do
        local selected = language == opt.id
        if reaper.ImGui_Selectable(ctx, stable_label(tr(opt.label_key), "language_" .. opt.id), selected) then
          set_language(opt.id, true)
        end
        if selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
      end
      reaper.ImGui_EndCombo(ctx)
    end
    -- reaper.ImGui_PopItemWidth(ctx)

    reaper.ImGui_SeparatorText(ctx, tr("preview_options"))
    -- 弹窗表格字体大小
    -- reaper.ImGui_Text(ctx, "Popup Table Font Size")
    local changed_font, new_font = reaper.ImGui_SliderInt(ctx, ui_label("popup_table_font_size", "font_size"), preview_font_size, 10, 24)
    if changed_font then preview_font_size = new_font end
  
    -- 是否显示主脚本的表格预览
    local changed_prev, new_prev = reaper.ImGui_Checkbox(ctx, ui_label("show_main_preview_table"), show_main_preview)
    if changed_prev then show_main_preview = new_prev end

    -- 是否显示help_marker
    local changed_help, new_help = reaper.ImGui_Checkbox(ctx, ui_label("show_help_markers"), show_help_markers)
    if changed_help then show_help_markers = new_help end
  
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_Button(ctx, ui_label("save_and_close", "settings_save")) then
      reaper.SetExtState("BatchRenamePlus", "PreviewFontSize",    tostring(preview_font_size),  true)
      reaper.SetExtState("BatchRenamePlus", "ShowMainPreview", tostring(show_main_preview), true)
      reaper.SetExtState("BatchRenamePlus", "ShowHelpMarkers", tostring(show_help_markers), true)
      reaper.SetExtState(EXT_SECTION, LANGUAGE_EXT_KEY, language, true)
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, ui_label("reset", "settings_reset")) then
      set_language(LANGUAGE_DEFAULT, true)
      preview_font_size = 14
      show_main_preview = true
      show_help_markers = true
    end

    reaper.ImGui_EndPopup(ctx)
  end
end

function open_region_marker_manager(ctx, label)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

  if reaper.ImGui_Button(ctx, label) then
    reaper.Main_OnCommand(40326, 0) -- View: Region/marker manager
  end
  reaper.ImGui_PopStyleColor(ctx, 3)
end

function get_file_name(path)
  if not path then return "" end
  if reaper.GetOS():match("Win") then
    return path:match(".*\\([^\\]+)$") or path
  else
    return path:match(".*/([^/]+)$") or path
  end
end

-- 修复 Item vs Source 列表空文件名问题，兼容 SECTION 类型
function gather_show_list_data()
  local data = {}
  local count_sel = CountSelectedItems(0) -- reaper.CountSelectedMediaItems(0)
  -- 按开始位置分组
  local startEvents = {}
  for i = 0, count_sel - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local name = reaper.GetTakeName(take)
      startEvents[pos] = startEvents[pos] or {}
      table.insert(startEvents[pos], { item = item, take_name = name })
    end
  end

  -- 对开始位置排序
  local starts = {}
  for pos in pairs(startEvents) do table.insert(starts, pos) end
  table.sort(starts)

  -- 自定义函数：获取真实文件路径，兼容 SECTION 类型和 SWS
  local function get_full_path(src)
    -- 核心 API
    local full = reaper.GetMediaSourceFileName(src, "") or ""
    -- SECTION 类型：取父源
    if full == "" then
      local st = reaper.GetMediaSourceType(src, "") or ""
      if st == "SECTION" and reaper.GetMediaSourceParent then
        local parent = reaper.GetMediaSourceParent(src)
        if parent then
          full = reaper.GetMediaSourceFileName(parent, "") or ""
        end
      end
    end
    -- SWS 扩展回退
    if full == "" and reaper.BR_GetMediaSourceFileName then
      full = reaper.BR_GetMediaSourceFileName(src) or ""
    end
    return full
  end

  -- 扁平化并提取文件名
  for _, pos in ipairs(starts) do
    for _, ev in ipairs(startEvents[pos]) do
      local take   = reaper.GetActiveTake(ev.item)
      local source = reaper.GetMediaItemTake_Source(take)
      local full   = get_full_path(source)
      local filename = get_file_name(full)
      table.insert(data, { take_name = ev.take_name, file_name = filename })
    end
  end

  return data
end

function item_vs_source()
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)

  -- 取 FramePadding 的垂直值，用来计算按钮高度
  local _, pad_y  = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local _, text_h = reaper.ImGui_CalcTextSize(ctx, T.compare)
  local button_h  = text_h + pad_y * 3.5

  reaper.ImGui_PushFont(ctx, font_small)
  if reaper.ImGui_Button(ctx, T.compare, 0, button_h) then
    local cnt = reaper.CountSelectedMediaItems(0)
    if cnt > 0 then
      show_list_data   = gather_show_list_data()
      show_list_window = true
    else
      reaper.ShowMessageBox(T.no_items_selected_compare, TITLE, 0)
    end
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 3)

  if show_list_window then
    reaper.ImGui_SetNextWindowSize(ctx, 600, 300, reaper.ImGui_Cond_FirstUseEver())
    local title = tr("compare_objects", #show_list_data) .. "###Compare"
    local visible, open = reaper.ImGui_Begin(ctx, title, show_list_window)
    show_list_window = open
    if visible then
      local function split_utf8_chars(str)
        local chars = {}
        str = tostring(str or "")
        for _, code in utf8.codes(str) do
          chars[#chars + 1] = utf8.char(code)
        end
        return chars
      end

      local function longest_common_text(a, b)
        local a_chars = split_utf8_chars(a)
        local b_chars = split_utf8_chars(b)
        local best_len, best_end = 0, 0
        local prev = {}

        for i = 1, #a_chars do
          local curr = {}
          for j = 1, #b_chars do
            if a_chars[i] == b_chars[j] then
              curr[j] = (prev[j - 1] or 0) + 1
              if curr[j] > best_len then
                best_len = curr[j]
                best_end = i
              end
            else
              curr[j] = 0
            end
          end
          prev = curr
        end

        if best_len < 2 then return "" end
        local shared = {}
        for i = best_end - best_len + 1, best_end do
          shared[#shared + 1] = a_chars[i]
        end
        local text = table.concat(shared)
        if not text:match("[%w\128-\255]") then return "" end
        return text
      end

      local function get_compare_message(entry)
        local take_name = entry.take_name or ""
        local file_name = entry.file_name or ""
        if take_name == file_name then return "" end

        local shared = longest_common_text(take_name, file_name)
        if shared ~= "" then
          return tr("different_same", shared)
        end
        return T.different
      end

      -- 把可拖拽标志合入 table_flags
      local table_flags =
          reaper.ImGui_TableFlags_Borders()     -- 带边框
        + reaper.ImGui_TableFlags_Resizable()   -- 可拖拽列分隔
        + reaper.ImGui_TableFlags_RowBg()      -- 斑马纹背景
  
      local table_font = preview_fonts[preview_font_size] or preview_fonts[14] or preview_fonts[12]
      reaper.ImGui_PushFont(ctx, table_font)
      if reaper.ImGui_BeginTable(ctx, "show_list_table", 4, table_flags) then
        -- 第一列固定宽度
        reaper.ImGui_TableSetupColumn(ctx, T.index, reaper.ImGui_TableColumnFlags_WidthFixed(), 50)
        -- 后三列伸展但依然可调整
        reaper.ImGui_TableSetupColumn(ctx, T.item_name, reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
        reaper.ImGui_TableSetupColumn(ctx, T.source_name, reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
        reaper.ImGui_TableSetupColumn(ctx, T.message, reaper.ImGui_TableColumnFlags_WidthStretch(), 0)
  
        reaper.ImGui_TableHeadersRow(ctx)
  
        -- for i, entry in ipairs(show_list_data) do
        --   reaper.ImGui_TableNextRow(ctx)
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, tostring(i))
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, entry.take_name)
        --   reaper.ImGui_TableNextColumn(ctx)
        --   reaper.ImGui_Text(ctx, entry.file_name)
        -- end
        
        k = tostring(#show_list_data)
        k = #k
        -- 支持Ctrl+鼠标左键点击复制栏目内容
        for i, entry in ipairs(show_list_window and show_list_data or {}) do
          reaper.ImGui_TableNextRow(ctx)
          -- 序号列
          reaper.ImGui_TableNextColumn(ctx)
          local idx_str = string.format("%0" .. k .. "d", i)
          reaper.ImGui_Text(ctx, idx_str)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(idx_str)
          end

          -- Item Name 列
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, entry.take_name)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(entry.take_name)
          end

          -- Source Name 列
          reaper.ImGui_TableNextColumn(ctx)
          reaper.ImGui_Text(ctx, entry.file_name)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(entry.file_name)
          end

          -- Message 列
          reaper.ImGui_TableNextColumn(ctx)
          local message = get_compare_message(entry)
          reaper.ImGui_Text(ctx, message)
          if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Left()) then
            reaper.CF_SetClipboard(message)
          end
        end
  
        reaper.ImGui_EndTable(ctx)
      end
      reaper.ImGui_PopFont(ctx)

      if reaper.ImGui_Button(ctx, T.copy_table) then
        local lines = {}
        for i, entry in ipairs(show_list_data) do
          -- 格式：[序号]   项目名称   源文件名称   比较信息
          lines[#lines+1] = string.format("[%d]\t%s\t%s\t%s", i, entry.take_name, entry.file_name, get_compare_message(entry))
        end
        local clip = table.concat(lines, "\n")
        reaper.CF_SetClipboard(clip)
      end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, T.copy_items) then
        local lines = {}
        for _, entry in ipairs(show_list_data) do
          lines[#lines+1] = entry.take_name
        end
        reaper.CF_SetClipboard(table.concat(lines, "\n"))
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, T.copy_sources) then
        local lines = {}
        for _, entry in ipairs(show_list_data) do
          lines[#lines+1] = entry.file_name
        end
        reaper.CF_SetClipboard(table.concat(lines, "\n"))
      end
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, T.refresh) then
        show_list_data = gather_show_list_data()
      end
      reaper.ImGui_SameLine(ctx)
      help_marker(
        T.copy_cell_help
      )

      reaper.ImGui_End(ctx)
    end
  end
end

function draw_wildcards(ctx, button_label, popup_id, target)
  -- 占位符按钮
  local mode_labels = {
    T.items,
    T.tracks,
    T.regions,
    T.markers,
    T.source_files,
  }
  local wildcards_by_mode = {
    [0] = { "$item", "$track", "$tracknumber", "$folders", "$GUID" },
    [1] = { "$track", "$tracknumber", "$folders", "$GUID" },
    [2] = { "$region", "$regionid", "$regionidx" },
    [3] = { "$marker", "$markerid", "$markeridx" },
    [4] = { "$source", "$track", "$tracknumber", "$folders" },
  }

  reaper.ImGui_SameLine(ctx)
  -- 透明按钮，仅文字
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          reaper.ImGui_ColorConvertDouble4ToU32(0,0.5,0,1))
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, button_label) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)
  
  if reaper.ImGui_BeginPopup(ctx, popup_id) then
    -- 一级菜单：各模式
    for idx, modeName in ipairs(mode_labels) do
      if reaper.ImGui_BeginMenu(ctx, modeName) then
        -- 二级菜单：对应通配符
        for _, wc in ipairs(wildcards_by_mode[idx-1] or {}) do
          if reaper.ImGui_MenuItem(ctx, wc) then
            if target == "rename" then
              if rename_pattern ~= "" then rename_pattern = rename_pattern .. wc else rename_pattern = wc end
            elseif target == "replace" then
              if replace_text ~= "" then replace_text = replace_text .. wc else replace_text = wc end
            elseif target == "insert" then
              if insert_text ~= "" then insert_text = insert_text .. wc else insert_text = wc end
            end
          end
        end
        reaper.ImGui_EndMenu(ctx)
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

function draw_specifiers(ctx, button_label, popup_id, target)
  -- 格式说明符按钮
  reaper.ImGui_SameLine(ctx)
  local specifiers = { "d=0001", "d=01-03", "d=10/2", "d=01-10/2", "a=a", "a=a-c", "r=5", "e=ABC|BCD|CDE;" }

  -- 将按钮背景设为透明，仅保留文字
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),        reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),  reaper.ImGui_ColorConvertDouble4ToU32(0,0,0,0))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),          reaper.ImGui_ColorConvertDouble4ToU32(0, 0.5, 0, 1))
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, button_label) then
    reaper.ImGui_OpenPopup(ctx, popup_id)
  end
  reaper.ImGui_PopFont(ctx)
  reaper.ImGui_PopStyleColor(ctx, 4)

  if reaper.ImGui_BeginPopup(ctx, popup_id) then
    -- reaper.ImGui_SeparatorText(ctx, "Specifiers")
    for _, wc in ipairs(specifiers) do
      if reaper.ImGui_Selectable(ctx, wc) then
        if target == "rename" then
          if rename_pattern ~= "" then rename_pattern = rename_pattern .. wc else rename_pattern = wc end
        elseif target == "replace" then
          if replace_text ~= "" then replace_text = replace_text .. wc else replace_text = wc end
        elseif target == "insert" then
          if insert_text ~= "" then insert_text = insert_text .. wc else insert_text = wc end
        end
      end
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

function draw_batch_mode_selector(ctx)
  reaper.ImGui_SeparatorText(ctx, tr("apply_to"))
  -- reaper.ImGui_Text(ctx, "Target")
  -- reaper.ImGui_SameLine(ctx)
  reaper.ImGui_PushItemWidth(ctx, -95)
  if reaper.ImGui_BeginCombo(ctx, ui_label("target", "batch_mode_combo"), get_batch_mode_label(process_mode)) then
    for group_i, group in ipairs(batch_mode_groups) do
      reaper.ImGui_TextDisabled(ctx, tr(group.label_key))
      for _, mode in ipairs(group.modes) do
        local mode_def = batch_modes[mode + 1]
        local selected = process_mode == mode
        if mode_def and reaper.ImGui_Selectable(ctx, stable_label(tr(mode_def.menu_key), "batch_mode_" .. tostring(mode)), selected) then
          process_mode = mode
        end
        if selected then
          reaper.ImGui_SetItemDefaultFocus(ctx)
        end
      end
      if group_i < #batch_mode_groups then
        reaper.ImGui_Separator(ctx)
      end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_PopItemWidth(ctx)
  reaper.ImGui_SameLine(ctx)
  help_marker(T.choose_target_help)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0x808080FF)
  reaper.ImGui_Text(ctx, get_batch_mode_tip(process_mode))
  reaper.ImGui_PopStyleColor(ctx)
end

function frame()
  reaper.ImGui_PushFont(ctx, font_large)
  reaper.ImGui_Text(ctx, TITLE)
  reaper.ImGui_PopFont(ctx)

  reaper.ImGui_SameLine(ctx, nil, 0)
  local avail = reaper.ImGui_GetContentRegionAvail(ctx) -- 计算可用宽度
  local frame_pad_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding()))
  local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))

  reaper.ImGui_PushFont(ctx, font_small)
  local compare_w = select(1, reaper.ImGui_CalcTextSize(ctx, T.compare)) + frame_pad_x * 2
  local preview_w = select(1, reaper.ImGui_CalcTextSize(ctx, T.preview)) + frame_pad_x * 2
  local options_w = select(1, reaper.ImGui_CalcTextSize(ctx, T.options)) + frame_pad_x * 2
  reaper.ImGui_PopFont(ctx)

  local total_w = math.ceil(compare_w + preview_w + options_w + item_spacing_x * 2) + 8

  -- 如果可用宽度足够，把光标推到右侧
  if avail > total_w then
    reaper.ImGui_Dummy(ctx, avail - total_w, 0)
    reaper.ImGui_SameLine(ctx, nil, 0)
  end

  reaper.ImGui_SameLine(ctx)
  item_vs_source()

  reaper.ImGui_SameLine(ctx)
  preview_popup(ctx)

  reaper.ImGui_SameLine(ctx)
  DrawSettings(ctx)

  -- reaper.ImGui_PushFont(ctx, font_small)
  -- reaper.ImGui_SameLine(ctx)
  -- support_popup(ctx)
  -- reaper.ImGui_PopFont(ctx)

  -- reaper.ImGui_SameLine(ctx)
  -- reaper.ImGui_PushFont(ctx, font_small)
  -- transparent_link(ctx, "Zaibuyidao", "https://www.soundengine.cn")
  -- reaper.ImGui_PopFont(ctx)

  -- reaper.ImGui_SameLine(ctx)
  -- reaper.ImGui_PushFont(ctx, font_small)
  -- -- reaper.ImGui_Text(ctx, 'Script by zaibuyidao v1.0')
  -- reaper.ImGui_TextColored(ctx, reaper.ImGui_ColorConvertDouble4ToU32(0, 1, 0, 0.5), 'Advanced renaming for REAPER')
  -- reaper.ImGui_PopFont(ctx)

  reaper.ImGui_PushItemWidth(ctx, -95)
  reaper.ImGui_Separator(ctx)
  -- 用户预设
  local comboLabel = (selectedPreset == 1) and T.no_preset or presetNames[selectedPreset]
  if reaper.ImGui_BeginCombo(ctx, "##Presets", comboLabel) then
    -- 1. 清空当前设置
    if reaper.ImGui_Selectable(ctx, T.reset_factory, false) then
      selectedPreset = 1
      ResetState()
    end

    -- 2. 如果当前选中 Reset to factory default, 就在下面显示提示文本 No preset
    -- if selectedPreset == 1 then
    --   reaper.ImGui_TextDisabled(ctx, "No preset") -- 灰色
    --   -- reaper.ImGui_Text(ctx, "No preset")
    -- end

    -- 3. 列出所有用户预设 (从 index=2 开始) 
    for i = 2, #presetNames do
      local name = presetNames[i]
      local isSel = (selectedPreset == i)
      if reaper.ImGui_Selectable(ctx, name, isSel) then
        selectedPreset = i
        local dataStr = reaper.GetExtState("BatchRenamePresets", name)
        if dataStr and dataStr ~= "" then
          ApplyPreset(dataStr)
        end
      end
    end

    reaper.ImGui_EndCombo(ctx)
  end

  reaper.ImGui_SameLine(ctx)
  -- 管理预设按钮
  if reaper.ImGui_Button(ctx, " + ##PresetManagerBtn") then
    reaper.ImGui_OpenPopup(ctx, "PresetManagerPopup")
  end

  -- 管理预设列表
  if reaper.ImGui_BeginPopup(ctx, "PresetManagerPopup") then
    local canModify = (selectedPreset > 1)

    -- 1. 保存预设，始终可用
    -- if reaper.ImGui_MenuItem(ctx, "Save Preset...", nil, false, true) then
    --   newPresetName = ""
    --   showSavePopup = true
    -- end

    if reaper.ImGui_MenuItem(ctx, T.save_preset_menu, nil, false, true) then
      savePresetPrompt.buffer = ""
      savePresetPrompt.show   = true
    end

    -- 2. 删除预设
    if reaper.ImGui_MenuItem(ctx, T.delete_preset, nil, false, canModify) then
      local nameToDel = presetNames[selectedPreset]
      table.remove(presetNames, selectedPreset)
      SavePresetList()
      reaper.DeleteExtState("BatchRenamePresets", nameToDel, true)
      selectedPreset = 1
      ResetState()
    end

    -- 3. 重命名预设
    if reaper.ImGui_MenuItem(ctx, T.rename_preset_menu, nil, false, canModify) then
      renamePresetPrompt.oldName = presetNames[selectedPreset]
      renamePresetPrompt.buffer  = renamePresetPrompt.oldName
      renamePresetPrompt.show    = true
    end

    -- 4. 导出所有用户预设
    reaper.ImGui_Separator(ctx)
    if reaper.ImGui_MenuItem(ctx, T.export_presets) then
      local filter = T.text_files_filter
      local retval, file = reaper.JS_Dialog_BrowseForSaveFile(
        T.export_presets, -- 标题
        "",               -- 初始路径
        filter,           -- 过滤器
        "txt"             -- 默认后缀，不含点
      )
      -- retval==1 表示用户点了保存
      if retval == 1 and file and file ~= "" then
        -- 如果用户没加后缀就补 .txt
        if not file:match("%.[^%.]+$") then file = file .. ".txt" end
        local f, err = io.open(file, "w")
        if not f then
          reaper.MB(tr("failed_open_write", err), T.error, 0)
        else
          for i = 2, #presetNames do
            local name = presetNames[i]
            local data = reaper.GetExtState("BatchRenamePresets", name) or ""
            f:write(name, "\t", data, "\n")
          end
          f:close()
          reaper.MB(tr("exported_presets", #presetNames - 1, file), T.export_presets, 0)
        end
      end
    end
    -- 5. 导入用户预设
    if reaper.ImGui_MenuItem(ctx, T.import_presets) then
      local r1, r2 = reaper.GetUserFileNameForRead("", T.import_presets, "*.txt")
      local file
      if type(r1)=="string" then
        file = r1
      elseif type(r2)=="string" then
        file = r2
      end
      -- 如果用户取消或结果不是字符串就跳过
      if not file or file == "" then
        -- 无操作
      else
        local f, err = io.open(file, "r")
        if not f then
          reaper.MB(tr("failed_open_read", err), T.error, 0)
        else
          local count = 0
          for line in f:lines() do
            local name, data = line:match("([^\t]+)\t?(.*)")
            if name and name ~= "" and name ~= presetNames[1] then
              if not TableContains(presetNames, name) then
                table.insert(presetNames, name)
              end
              reaper.SetExtState("BatchRenamePresets", name, data or "", true)
              count = count + 1
            end
          end
          f:close()
          SavePresetList()
          reaper.MB(tr("imported_presets", count, file), T.import_presets, 0)
        end
      end
    end

    reaper.ImGui_EndPopup(ctx)
  end

  -- Save Preset 对话框
  ImGui_TextPrompt(ctx, savePresetPrompt, "##savePresetInput", 128, function(name)
    -- 确认保存时的回调
    -- 1. 插入新预设名
    table.insert(presetNames, name)
    SavePresetList()
    -- 2. 写入当前设置
    local dataStr = EncodePreset()
    reaper.SetExtState("BatchRenamePresets", name, dataStr, true)
    -- 3. 选中刚创建的预设
    for i,n in ipairs(presetNames) do
      if n == name then selectedPreset = i; break end
    end
  end)
  -- Rename Preset 对话框
  ImGui_TextPrompt(ctx, renamePresetPrompt, "##renamePresetInput", 128, function(name)
    local old = renamePresetPrompt.oldName
    if old and old ~= name then
      -- 1. 读取并迁移数据
      local dataStr = reaper.GetExtState("BatchRenamePresets", old)
      reaper.DeleteExtState("BatchRenamePresets", old, true)
      reaper.SetExtState("BatchRenamePresets", name, dataStr or "", true)
      -- 2. 更新列表
      presetNames[selectedPreset] = name
      SavePresetList()
    end
  end)

  draw_batch_mode_selector(ctx)

  reaper.ImGui_SeparatorText(ctx, T.settings)
  if process_mode == 0 then
    example_text = T.example .. " $item_d=0001_a=E-A_r=4"
  elseif process_mode == 1 then
    example_text = T.example .. " $track_d=0001_a=E-A_r=4"
  elseif process_mode == 2 then
    example_text = T.example .. " $region_d=0001_a=E-A_r=4"
  elseif process_mode == 3 then
    example_text = T.example .. " $region_d=0001_a=E-A_r=4"
  elseif process_mode == 4 then
    example_text = T.example .. " $region_d=0001_a=E-A_r=4"
  elseif process_mode == 5 then
    example_text = T.example .. " $region_d=0001_a=E-A_r=4"
  elseif process_mode == 6 then
    example_text = T.example .. " $marker_d=0001_a=E-A_r=4"
  elseif process_mode == 7 then
    example_text = T.example .. " $marker_d=0001_a=E-A_r=4"
  elseif process_mode == 8 then
    example_text = T.example .. " $marker_d=0001_a=E-A_r=4"
  elseif process_mode == 9 then
    example_text = T.example .. " $track_$source_d=0001_a=E-A_r=4"
  end

  -- 1) Rename
  local ch_n, new_n = reaper.ImGui_Checkbox(ctx, T.rename, enable_rename)
  if ch_n then enable_rename = new_n end

  if enable_rename then
    draw_wildcards(ctx, ui_label("wildcards", "wildcards_rename"), 'wildcards_popup##1', 'rename')
    draw_specifiers(ctx, ui_label("specifiers", "specifiers_rename"), 'item_mode_specifiers##1', 'rename')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_rename)
  local ch_p, newPattern = reaper.ImGui_InputTextWithHint(
    ctx,
    T.pattern,
    example_text,
    rename_pattern
  )

  if ch_p then rename_pattern = newPattern end
  reaper.ImGui_EndDisabled(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)

  help_marker(T.wildcard_help)
  reaper.ImGui_Separator(ctx)

  -- 2) Replace
  local ch_rp, new_rp = reaper.ImGui_Checkbox(ctx, T.replace, enable_replace)
  if ch_rp then enable_replace = new_rp end

  if enable_replace then
    draw_wildcards(ctx, ui_label("wildcards", "wildcards_replace"), 'wildcards_popup##2', 'replace')
    draw_specifiers(ctx, ui_label("specifiers", "specifiers_replace"), 'item_mode_specifiers##2', 'replace')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_replace)
  local ch_f, new_find = reaper.ImGui_InputText(ctx, ui_label("find_what", "find"), find_text or "")
  if ch_f then find_text = new_find end
  local ch_w, new_repl = reaper.ImGui_InputText(ctx, ui_label("replace_with", "repl"), replace_text or "")
  if ch_w then replace_text = new_repl end

  -- 匹配大小写选项
  local fp_x, fp_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding())
  local is_x, is_y = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), fp_x, math.floor(fp_y * 0.5))
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), is_x, math.floor(is_y * 0.5))

  local ch_mc, new_mc = reaper.ImGui_Checkbox(ctx, ui_label("match_case", "mc"), match_case)
  if ch_mc then match_case = new_mc end
  reaper.ImGui_PopStyleVar(ctx, 2)

  reaper.ImGui_SameLine(ctx)
  -- Occurrence 列表: First, Last, All
  if reaper.ImGui_BeginCombo(ctx, ui_label("occurrence", "occ"), (occurrence_mode==0 and T.first) or (occurrence_mode==1 and T.last) or T.all) then
    local occ_opts = {T.first, T.last, T.all}
    for i = 0, 2 do
      local sel = (i == occurrence_mode)
      if reaper.ImGui_Selectable(ctx, occ_opts[i+1], sel) then occurrence_mode = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end

  local ch_regex, new_regex = reaper.ImGui_Checkbox(ctx, ui_label("use_regular_expression", "regex"), use_regular_expression)
  if ch_regex then
    use_regular_expression = new_regex
    SaveUseRegularExpressionState()
  end
  reaper.ImGui_SameLine(ctx)
  help_marker(T.regex_help)
  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Separator(ctx)

  -- 3) Remove
  local ch_rm, new_rm = reaper.ImGui_Checkbox(ctx, T.remove, enable_remove)
  if ch_rm then enable_remove = new_rm end
  reaper.ImGui_BeginDisabled(ctx, not enable_remove)
  reaper.ImGui_PushItemWidth(ctx, -95)
  local ch_cnt, newCnt = reaper.ImGui_DragInt(ctx, ui_label("count", "rmcnt"), remove_count, 1, 0, 100, "%d")
  if ch_cnt then remove_count = newCnt end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(T.slider_help)

  reaper.ImGui_PushItemWidth(ctx, -95)
  local ch_pos, newPos = reaper.ImGui_DragInt(ctx, ui_label("at_position", "rmpos"), remove_position, 1, 0, 100, "%d")
  if ch_pos then remove_position = newPos end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(T.slider_help)

  if reaper.ImGui_BeginCombo(ctx, ui_label("from", "rmside"), (remove_side_index==0) and T.beginning or T.ending) then
    local opts = { T.beginning, T.ending }
    for i = 0, 1 do
      local sel = (i == remove_side_index)
      if reaper.ImGui_Selectable(ctx, opts[i+1], sel) then remove_side_index = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)
  reaper.ImGui_Separator(ctx)

  -- 4) Insert
  local ch_i, new_i = reaper.ImGui_Checkbox(ctx, T.insert, enable_insert)
  if ch_i then enable_insert = new_i end

  if enable_insert then
    draw_wildcards(ctx, ui_label("wildcards", "wildcards_insert"), 'wildcards_popup##3', 'insert')
    draw_specifiers(ctx, ui_label("specifiers", "specifiers_insert"), 'item_mode_specifiers##3', 'insert')
  end

  reaper.ImGui_BeginDisabled(ctx, not enable_insert)
  local ch_txt, newTxt = reaper.ImGui_InputText(ctx, ui_label("to_insert", "ins"), insert_text or "")
  if ch_txt then insert_text = newTxt end

  reaper.ImGui_PushItemWidth(ctx, -95)
  local ch_ip, new_ip = reaper.ImGui_DragInt(ctx, ui_label("at_position_insert", "inspos"), insert_position, 1, 0, 100, "%d")
  if ch_ip then insert_position = new_ip end
  reaper.ImGui_PopItemWidth(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(T.slider_help)

  if reaper.ImGui_BeginCombo(ctx, ui_label("from_insert", "insside"), (insert_side_index==0) and T.beginning or T.ending) then
    for i = 0, 1 do
      local sel = (i == insert_side_index)
      local lbl = (i == 0) and T.beginning or T.ending
      if reaper.ImGui_Selectable(ctx, lbl, sel) then insert_side_index = i end
      if sel then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  reaper.ImGui_EndDisabled(ctx)

  reaper.ImGui_SeparatorText(ctx, T.behavior)

  local changed7, newCycle = reaper.ImGui_Checkbox(ctx, T.range_cycle, use_cycle_mode)
  if changed7 then use_cycle_mode = newCycle end
  reaper.ImGui_SameLine(ctx)
  help_marker(T.range_cycle_help)
  if process_mode == 9 then
    reaper.ImGui_SameLine(ctx)
    local changed_take_name, new_take_name = reaper.ImGui_Checkbox(ctx, ui_label("match_src", "write_take_name"), write_take_name)
    if changed_take_name then write_take_name = new_take_name end
    reaper.ImGui_SameLine(ctx)
    help_marker(T.match_src_help)
  end

  if process_mode == 0 or process_mode == 9 then
    reaper.ImGui_PushItemWidth(ctx, -95)
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_BeginCombo(ctx, T.sort_by, (sort_index == 0 and T.track) or (sort_index == 1 and T.sequence) or T.timeline) then
      local sort_options = { T.track, T.sequence, T.timeline }
      for i = 0, #sort_options-1 do
        local is_selected = (i == sort_index)
        if reaper.ImGui_Selectable(ctx, sort_options[i+1], is_selected) then
          sort_index = i
        end
        if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
      end
      reaper.ImGui_EndCombo(ctx)
    end
    reaper.ImGui_PopItemWidth(ctx)
  end

  if process_mode == 2 or process_mode == 6 then
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushFont(ctx, font_small)
    open_region_marker_manager(ctx, T.open_region_marker_manager)
    reaper.ImGui_PopFont(ctx)
  end

  local data, builder = get_preview_data_and_builder()
  if show_main_preview then
    render_preview_table(ctx, PREVIEW_TABLE_ID, #data, builder)
  end

  -- draw_batch_mode_selector(ctx)

  -- 检测/按下 Ctrl + Enter 快捷键
  local ctrl_enter_down =
    reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Ctrl()) and
    reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_Enter())
  if ctrl_enter_down and not ctrl_enter_was_down then
    apply_batch_rename()
  end
  ctrl_enter_was_down = ctrl_enter_down

  -- reaper.ImGui_Separator(ctx)
  -- reaper.ImGui_Dummy(ctx, 0, 0)
  -- 计算可用宽度并分成两半 (减去 SameLine 之间的间距)
  local avail_x, _     = reaper.ImGui_GetContentRegionAvail(ctx)
  local item_spacing_x = select(1, reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing()))
  local half_width     = (avail_x - item_spacing_x) * 0.5
  
  local default_h      = reaper.ImGui_GetFrameHeight(ctx)
  local button_h       = default_h + 10

  -- 左侧按钮，占一半宽度
  reaper.ImGui_PushFont(ctx, font_medium)
  if reaper.ImGui_Button(ctx, T.clear, half_width, button_h) then
    selectedPreset = 1
    ResetState()
  end
  
  reaper.ImGui_SameLine(ctx)
  
  -- 右侧按钮，占一半宽度
  if reaper.ImGui_Button(ctx, ui_label("rename_all", "do_rename"), half_width, button_h) then
    apply_batch_rename()
  end
  reaper.ImGui_PopFont(ctx)
  -- 帮助
  reaper.ImGui_SameLine(ctx)
  help_marker(T.rename_all_help)

  if tables.disable_indent then
    reaper.ImGui_PopStyleVar(ctx)
  end

  return true
end

function loop()
  reaper.ImGui_PushFont(ctx, sans_serif)
  reaper.ImGui_SetNextWindowBgAlpha(ctx, 1.0) -- 背景透明
  -- reaper.ImGui_SetNextWindowSizeConstraints(ctx, 450, 850, FLT_MAX, FLT_MAX) -- 锁定界面
  -- 在 Begin 之前推入 WindowRounding 和 FrameRounding
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 8.0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(),  4.0)

  -- 1) 开始窗口
  local visible, open = reaper.ImGui_Begin(ctx, ui_label("window_title", "MainWindow"), true)
  if visible then
    -- 圆角处理: 弹出菜单、子区域、滚动条、滑块
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(),     4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(),      4.0)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(),     4.0)
    -- 2) 读取默认行间距，放大 2 倍
    local ix, iy = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), ix, iy * 2.0)
    -- 3) 绘制所有 UI
    if not frame() then
      open = false
    end
    -- 4) 恢复行间距样式
    reaper.ImGui_PopStyleVar(ctx, 5) -- 4 次圆角 + 1 次行间距
    -- 5) 结束窗口
    reaper.ImGui_End(ctx)
  end

  -- 6) Pop 最早 Push 的 WindowRounding + FrameRounding
  reaper.ImGui_PopStyleVar(ctx, 2)
  reaper.ImGui_PopFont(ctx)

  if open then
    reaper.defer(loop)
  else
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
  end
end

loop()
