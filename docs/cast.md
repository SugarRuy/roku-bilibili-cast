# 手机 B 站投屏（实验功能）

电视打开狗哩狗哩后，在同一局域网的 Bilibili 手机 App 中打开一个视频，从**视频播放页的投屏按钮**选择「Roku 小电视 · 投屏测试」。接收器仅在 Roku 应用前台运行。手机发送视频标识，电视使用自身的登录状态获取并播放视频。

本功能使用 B 站的「哔哩必连」局域网发现和 NVA 控制协议。实测成功的入口是视频播放页。个人页出现的「哔哩必连／云视听小电视」独立入口尚未验证能找到这台 Roku。这里也没有实现 Chromecast 接收器。

## DIAL 唤起（实验功能）

频道在 manifest 中注册 `RokuBiliCast`，Roku 系统会在频道关闭及电视待机时保留 DIAL 入口。支持从同一局域网的电脑发送 BV 视频编号，唤醒电视并自动播放：

```bash
python scripts/push.py BV1xx411c7mD --roku-ip 192.168.1.177
```

也可以传入包含 BV 编号的 B 站视频 URL。这个命令通过 Roku 系统的 DIAL 接口启动频道；B 站手机 App 是否使用 DIAL 搜索设备，仍需单独验证。若手机只搜索 UPnP 接收器，须由常开的局域网桥接进程提供发现和转发。

## 当前状态

- 0.1.4 首次由手机视频播放页投放并在电视播放。0.1.7 修复快速切换时强制停止请求导致的 Roku 执行超时，以及大视频详情解析慢的问题。
- 对一条约 77 万字符的视频详情响应，编号精度保护的替换步骤从约 15.7 秒降为实机三次测量的 0.43–0.53 秒。同一视频从收到投放指令到起播，实测约 2.4–3.6 秒。这些数字只描述被测设备、视频和网络。
- 真实 Roku 上已自动验证连续六次投放时只播放最新请求、请求中途停止后不会迟到起播、取消后重新播放、替换播放器。0.1.7 尚未由官方手机 App 单独重新验收；电脑模拟协议通过不能代替手机入口兼容性。
- 当前针对普通投稿视频的 BV/av 标识及分 P。直播、完整番剧、倍速和画质控制、通用 Chromecast 接收，以及个人页独立发现入口尚未完成。`GetVolume` 当前返回固定值，不代表电视实际音量。

这是社区原型，与 Bilibili 和云视听小电视没有官方关系。设备描述中的 Bilibili 字段用于协议兼容，设备名称明确标为「投屏测试」。

## 本地测试

把 Roku IP 放进项目根目录的 `.env.local`，或设环境变量 `ROKU_IP`。测试脚本只读取 IP，不读取开发者密码。

```bash
python tests/cast/network_probe.py
npm ci --prefix tools
tools/node_modules/.bin/bsc --no-project --root-dir channel --create-package false --copy-to-staging false --deploy false --ignore-error-codes 1104
```

`network_probe.py` 向真实电视检查设备描述、SSDP、GetAppInfo、NVA 握手、分片与合并请求及边界处理；它不投放视频。BrighterScript 检查 BrightScript 语法。大 JSON 的编号精度、转义文本、逗号和取消路径曾在本地模拟器通过；0.1.7 的起播结果来自真实电视。

切换回归会**改变电视播放状态**。先在被 Git 忽略的 `tests/cast/recovery.local.json` 写入一个自己能播放的视频标识，例如：

```json
{"bvid":"BVxxxxxxxxxx","cid":"123456789","position":0}
```

然后运行 `python tests/cast/switch_regression.py`。脚本在结束时尝试恢复指定视频；测试失败时也会尝试恢复。不要把本地恢复文件、`.env.local`、设备日志或安装包提交到仓库。

测试依据来自 Roku 上实际播放状态和分阶段日志。手机端入口及长期稳定性仍需真实手机验收。
