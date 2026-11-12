#!/data/data/com.termux/files/usr/bin/sh
# 守护启动脚本：进程挂掉自动重启，日志超 5MB 自动轮转
# 锁用 PID 判活：进程已死的老锁会自动清掉，不会挡住重启
cd "$(dirname "$0")" || exit 1
LOG="$HOME/jmapi/run.log"
LOCK="$HOME/jmapi/.run.lock"
mkdir -p "$HOME/jmapi"

if [ -f "$LOCK" ]; then
  old=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
    echo "[supervisor] 已有实例在运行 (PID $old)，本次启动放弃"
    exit 0
  fi
  rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"; exit 0' EXIT INT TERM

termux-wake-lock >/dev/null 2>&1

if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 5000000 ]; then
  mv "$LOG" "$LOG.old"
fi

while true; do
  echo "[supervisor] start $(date +%H:%M:%S)" >> "$LOG"
  python logserve.py >> "$LOG" 2>&1
  code=$?
  echo "[supervisor] exited code=$code, restart in 3s" >> "$LOG"
  sleep 3
done
