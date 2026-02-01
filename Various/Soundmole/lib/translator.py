# NoIndex: true
# ===================== 环境安装说明 / Setup Instructions ======================
#
# 1. 安装 Python (Install Python):
#    - 下载地址: https://www.python.org/downloads/
#    - Windows注意: 安装界面底部务必勾选 "Add Python to PATH" (添加到环境变量)
#    - Mac注意: 推荐安装 Python 3.x
#
# 2. 安装依赖库 (Install Dependencies):
#    请打开终端 (Terminal) 或 命令提示符 (CMD)，运行以下命令安装 openai 库:
#
#    pip install openai
#    (如果 Mac 下提示 pip 命令不存在, 请尝试使用: pip3 install openai)
#
# ==============================================================================

import sys
import os
import traceback

# 设置编码
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr = sys.stdout

# debug_log 开关设置
# True = 开启日志 (生成 debug_log.txt)
# False = 关闭日志
DEBUG_MODE = False

def log(msg):
    if not DEBUG_MODE:
        return
    
    try:
        log_path = os.path.join(os.path.dirname(__file__), "debug_log.txt")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(str(msg) + "\n")
    except:
        pass

# 检查库
try:
    from openai import OpenAI
except ImportError:
    if not DEBUG_MODE: # 强行写错误，防止找不到原因
        pass
    log("错误: 缺少 openai 库。请运行 'pip install openai' 进行安装。")
    sys.exit(1)

# 配置
API_KEY = "b66c733069d84025b2e7de2e585e9527.17fPGQG66919RWLT" 
BASE_URL = "https://open.bigmodel.cn/api/paas/v4/"
MODEL_NAME = "glm-4-flash"

def atomic_write(filepath, content):
    temp_file = filepath + ".tmp"
    try:
        # 先写到临时文件
        with open(temp_file, 'w', encoding='utf-8') as f:
            f.write(content)
            f.flush()            # 清空 Python 缓冲区
            os.fsync(f.fileno()) # 强制 Windows 把数据写死在硬盘上

        # 改名
        if os.path.exists(filepath):
            os.remove(filepath)
        os.rename(temp_file, filepath)

    except Exception as e:
        log(f"写入失败: {e}")

def translate_and_save(text, output_file):
    log(f"请求: {text}")

    try:
        client = OpenAI(api_key=API_KEY, base_url=BASE_URL)
        response = client.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "你是一个音效搜索关键词翻译器。无论用户输入什么语言（包括中文、日文、英文等），请将其直接翻译为对应的英文关键词。如果输入已经是英文，请优化或原样输出。只输出结果，不要标点。"},
                {"role": "user", "content": text}
            ],
            temperature=0.1, max_tokens=60
        )
        result = response.choices[0].message.content.strip()
        log(f"结果: {result}")
        
        # 使用原子写入！
        atomic_write(output_file, result)

    except Exception as e:
        log(f"API错误: {e}")
        atomic_write(output_file, "Error")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        translate_and_save(sys.argv[1], sys.argv[2])