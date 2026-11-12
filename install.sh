#!/bin/sh
# 一键安装 / 更新。用法：  sh install.sh
set -e

cd "$(dirname "$0")"
HERE="$(pwd)"
TARGET="$HOME/jmapi"

echo "==> 1/5 检查 Python"
if ! command -v python >/dev/null 2>&1; then
    echo "!! 没有 python，先运行： pkg install -y python"
    exit 1
fi
python -V

echo "==> 2/5 安装依赖（国内清华源，1~3 分钟）"
python -m pip install -q --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
python -m pip install -q -i https://pypi.tuna.tsinghua.edu.cn/simple \
    flask waitress requests pillow jmcomic

echo "==> 3/5 复制文件到 $TARGET"
mkdir -p "$TARGET"
cp -f logserve.py run.sh check-image.py "$TARGET"/
mkdir -p "$TARGET/cloud-functions" "$TARGET/Crypto/Cipher"
cp -f cloud-functions/backend.py cloud-functions/runtime.py "$TARGET/cloud-functions"/
cp -f Crypto/__init__.py "$TARGET/Crypto"/
cp -f Crypto/Cipher/AES.py Crypto/Cipher/__init__.py "$TARGET/Crypto/Cipher"/
# 换换行符，避免从 Windows 传过来带 \r
sed -i 's/\r$//' "$TARGET/run.sh" 2>/dev/null || true

echo "==> 4/5 停掉旧进程"
pkill -9 -f run.sh >/dev/null 2>&1 || true
pkill -9 -f "python logserve.py" >/dev/null 2>&1 || true
sleep 2

echo "==> 5/5 启动"
cd "$TARGET"
nohup sh run.sh >/dev/null 2>&1 &
sleep 15

IP=$(python -c "import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.connect(('8.8.8.8',80));print(s.getsockname()[0])" 2>/dev/null || echo "未知")

echo ""
echo "=================================================="
grep -a "SERVE" "$TARGET/run.log" 2>/dev/null | tail -1
echo "--------------------------------------------------"
echo " 手表里要填的地址：  http://$IP:3002"
echo " 本机自测：          curl -s http://127.0.0.1:3002/config"
echo " 看日志：            grep -a \"Vela\" ~/jmapi/run.log | tail -5"
echo " 停服务：            sh $HERE/stop.sh"
echo "=================================================="
