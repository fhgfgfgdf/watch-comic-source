#!/bin/sh
pkill -9 -f run.sh >/dev/null 2>&1 || true
pkill -9 -f "python logserve.py" >/dev/null 2>&1 || true
echo "已停止"
