# 腕上漫画源（watch-comic-source）

在安卓手机 Termux（或 Windows / Linux）里跑一个轻量 HTTP 服务，把上游漫画站点的公开接口转发成 Vela 手表快应用「腕上漫画」能读的格式。

手表本身不能直接联网取图，所有请求经手机转发，所以手机上的「小米运动健康」必须与手表保持连接。

- 端口固定 `3002`，只支持局域网，不含内网穿透。
- 运行目录固定 `~/jmapi`（手机）。
- 不提供、不托管、不分发任何内容，只做格式转发；详见仓库内 `免责声明.txt`。

---

## 一、装之前确认

- 手机是安卓，能装 Termux。
- 手机和手表连**同一个 WiFi**。
- 「小米运动健康」保持连着手表。
- 不需要服务器、不需要公网。

---

## 二、安装（三条命令）

把压缩包 `jmapi-watch-comic.zip` 传到手机，然后在 Termux 里：

```sh
pkg install -y python
unzip jmapi-watch-comic.zip -d ~/manhua
cd ~/manhua && sh install.sh
```

`install.sh` 会依次做完：装依赖 → 复制文件到 `~/jmapi` → 停掉旧进程 → 启动 → 打印地址。

跑完屏幕上会出现两行：

```
SERVE 0.0.0.0:3002 PUBLIC_URL=http://192.168.x.x:3002 IP=192.168.x.x
手表里要填的地址：  http://192.168.x.x:3002
```

把这一行地址记下来（每次手机换 WiFi 后地址都会变）。

---

## 三、在手表上填

1. 手表 → 腕上漫画 → 关于 → 漫画源 → 编辑源
2. 地址填上一步打印的 `http://192.168.x.x:3002`
3. 保存后先搜索一次。首次慢是正常的（中文关键词上游本身要 4~6 秒），第二次起命中缓存接近瞬开。

验证手表真的连上了（手机上跑）：

```sh
grep -a "Vela" ~/jmapi/run.log | tail -5
```

有输出 = 通了；空 = 没连上。

---

## 四、日常命令

| 要做的事 | 命令 |
|---|---|
| 看服务是否在跑 | `ps -ef \| grep -E "logserve\|run.sh"` |
| 看当前地址 | `grep -a "SERVE" ~/jmapi/run.log \| tail -1` |
| 看最近请求 | `grep -a "RES" ~/jmapi/run.log \| tail -10` |
| 看每页耗时 | `grep -a "PAGE " ~/jmapi/run.log \| tail -20` |
| 重启 | `pkill -9 -f run.sh; pkill -9 -f "python logserve.py"; sleep 2; cd ~/jmapi && nohup sh run.sh >/dev/null 2>&1 &` |
| 停止 | `sh ~/manhua/stop.sh` |
| 清缓存 | `pkill -9 -f "python logserve.py"; rm -f ~/jmapi/cache.db; cd ~/jmapi && nohup sh run.sh >/dev/null 2>&1 &` |

日志在 `~/jmapi/run.log`，跨重启累积，用 `grep -a` 看。

---

## 五、出问题怎么办

**1. 手表提示「搜索失败」「请求失败」**

- 手机换过 WiFi，IP 变了。重新查地址：`grep -a "SERVE" ~/jmapi/run.log | tail -1`，手表里改成新地址。
- 「小米运动健康」没连手表 → 手表发不出请求。
- 手机开了 VPN：部分域名解析失败，先关掉 VPN 再试。

**2. 浏览器打不开 `http://127.0.0.1:3002/config`**

说明服务没起来。

```sh
cd ~/jmapi && nohup sh run.sh >/dev/null 2>&1 &
sleep 15
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3002/config
```

返回 200 才算起来了。

**3. 页数显示不对 / 显示 0 页**

本包按「第一话真实图片张数」算页数，不会出 0 页。个别漫画上游数据本身就残缺，换一本试。

**4. 翻到十几二十页突然卡住（进度 0 上传 0 下载）**

```sh
grep -a "PAGE " ~/jmapi/run.log | tail -20
```

- 有 `8000ms` 以上的行 → 上游慢，退出重进这本漫画即可。
- 完全没有那一页的记录 → 手表端自己卡住（Vela 内存/渲染），退出重进。

可选手表端优化：设置里关掉「相邻页预加载」、图片尺寸调到 320。

**5. 图片很糊 / 字看不清**

手表 UA 会自动把宽度限制在 320，可在 `~/jmapi/run.sh` 里放宽：

```sh
export WATCH_MAX_WIDTH=380
export WATCH_MAX_QUALITY=65
```

改完重启。调太高手表更容易卡。

---

## 六、目录结构

```
~/jmapi/
├── run.sh                   守护启动，进程掉了自动重启，日志超限自动轮转
├── logserve.py              启动器，自动探测本机 IP，打印每条 REQ/RES
├── cloud-functions/
│   ├── backend.py           接口实现（搜索/详情/章节/取图/封面）
│   └── runtime.py           缓存、单飞、请求预算
├── Crypto/                  纯 Python AES（换域名时必需，免装 pycryptodome）
├── cache.db                 缓存（上限 4GB，可随时删）
└── run.log                  日志
```

---

## 七、已验证的行为

- 同一专辑连续 200 页：200/200 成功，总耗时约 202 秒，p50 481 ms，无失败。
- 40 并发突发 320 次请求：无 5xx，p50 213 ms。
- 同一张图 20 并发：20/20 成功，最慢 136 ms（单飞不互相抢锁）。
- 3 分钟持续混合负载 4745 次请求：失败率 0.1%，结束后 `/health` 仍 1 ms。
- 内存随缓存增长至约 167 MB 后稳定（上限 256 MB，非泄漏）。

---

## 八、署名与来源

| 项目 | 作者 | 许可 | 关系 |
|---|---|---|---|
| 腕上漫画（Vela 客户端） | **sf-yuzifu** — [sf-yuzifu/bandcomic](https://github.com/sf-yuzifu/bandcomic) | AGPL-3.0 | 按它约定的接口格式提供数据，**未包含、未改编其源码** |
| 上游接口库 jmcomic | **hect0x7** — [hect0x7/JMComic-Crawler-Python](https://github.com/hect0x7/JMComic-Crawler-Python) | MIT | 通过 pip 安装使用，未修改源码 |
| 漫画作品内容 | 各原作者 / 出版方 | 版权保留 | 本服务不提供、不托管、不分发任何作品 |

完整说明见 `NOTICE.md`。

---

## 九、给 AI 读的资料

不会用或者想排查问题，把仓库里的 `AI-知识卡.md` 整份复制给任意 AI（豆包 / ChatGPT / Claude / DeepSeek），再按里面的提问模板提问。

---

## 十、免责

本工具只是把第三方站点的公开接口转发成手表能读的格式，不提供、不托管、不分发任何内容；所有内容版权归原作者与相应权利人，仅供个人学习与技术调试使用，不得商用或二次分发。使用产生的一切后果由使用者自负。完整条款见 `免责声明.txt`。
