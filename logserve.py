"""Termux / 电脑通用启动器。

- 没显式给 PUBLIC_URL 时，自动探测本机局域网 IP，保证 /config 返回的 apiUrl 是对的
- 每条请求记录 REQ（方法/路径/来源/UA）与 RES（状态码）
- 兼容 /config/config 这种被客户端多拼一层的地址（返回同一份配置，而不是 404）
"""
import os
import socket
import sys

sys.stdout.reconfigure(line_buffering=True)
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(BASE, "cloud-functions"))


def detect_lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(1.0)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


PORT = int(os.environ.get("PORT", "3002"))
# 成品图片落盘缓存：同一页第二次看直接读盘，重启也还在；协调仍走内存，避免单进程抢锁
os.environ.setdefault("CACHE_DB", os.path.join(BASE, "cache.db"))
os.environ.setdefault("CACHE_COORD", "memory")
if not os.environ.get("PUBLIC_URL"):
    os.environ["PUBLIC_URL"] = "http://%s:%d" % (detect_lan_ip(), PORT)

from backend import app
from flask import request

# 别名：/config/config -> 与 /config 同一个视图，避免同步器/客户端多拼一层拿到 404
for rule in list(app.url_map.iter_rules()):
    if rule.rule == "/config":
        app.add_url_rule("/config/config", endpoint="config_alias",
                         view_func=app.view_functions[rule.endpoint])


@app.before_request
def _log_req():
    print("REQ %s %s from %s ua=%s" % (
        request.method, request.full_path, request.remote_addr,
        (request.headers.get("User-Agent") or "")[:70]
    ), flush=True)


@app.after_request
def _log_resp(resp):
    print("RES %s %s -> %s" % (request.method, request.path, resp.status_code), flush=True)
    return resp


from waitress import serve

def _warm():
    # 启动就把 jmcomic 的连接与 cookie 建好，免得手表第一次搜索等 3~4 秒超时
    try:
        from backend import shared_client, warm_domains
        shared_client()
        print("WARM client ready", flush=True)
        warm_domains()
    except Exception as error:
        print("WARM failed: %s: %s" % (type(error).__name__, error), flush=True)


if __name__ == "__main__":
    print("SERVE 0.0.0.0:%d  PUBLIC_URL=%s  IP=%s" % (PORT, os.environ["PUBLIC_URL"], detect_lan_ip()), flush=True)
    import threading
    threading.Thread(target=_warm, daemon=True).start()
    serve(app, host="0.0.0.0", port=PORT, threads=24)
