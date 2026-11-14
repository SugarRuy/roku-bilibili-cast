# 手机 B 站投屏（实验功能）

电视打开狗哩狗哩后，在同一局域网的 Bilibili 手机 App 中打开一个视频，从**视频播放页的投屏按钮**选择「Roku 小电视 · 投屏测试」。手机发送视频标识，电视使用自身的登录状态获取并播放视频。2026-11-14 用户已确认本研究分支退出 App 后的手机投屏可用；适用条件和验证范围见下述后台唤起记录。

本功能使用 B 站的「哔哩必连」局域网发现和 NVA 控制协议。实测成功的入口是视频播放页。个人页出现的「哔哩必连／云视听小电视」独立入口尚未验证能找到这台 Roku。这里也没有实现 Chromecast 接收器。

## DIAL 唤起（实验功能）

频道在 manifest 中注册 `RokuBiliCast`，Roku 系统会在频道关闭及电视待机时保留 DIAL 入口。支持从同一局域网的电脑发送 BV 视频编号，唤醒电视并自动播放：

```bash
python scripts/push.py BV1xx411c7mD --roku-ip 192.168.1.177
```

也可以传入包含 BV 编号的 B 站视频 URL。这个命令通过 Roku 系统的 DIAL 接口启动频道。手机日志中的 `upnp:rootdevice` 搜索不能单独证明它支持或不支持 DIAL；它拿到设备描述后是否继续查询 DIAL 应用名，此前没有记录到。

## 电视端后台唤起（研究分支，未发布）

2026-11-14 在 M302X / Roku OS 16.0.4 重新实测：Instant Resume 下的独立 TCP/UDP 任务，在回到首页和待机后仍能执行。电视任务也能自行调用本机 DIAL 唤回频道。因此增加一个完全在 Roku 内部运行的原型：

1. 先打开频道一次，使接收器启动；退出界面后保留独立网络任务。
2. 任务在电视本机继续提供 SSDP、设备描述、NVA 握手；这些请求不会亮屏。
3. 收到有效的 NVA `Play` 后，任务调用本机 `RokuBiliCast` DIAL 入口。
4. 界面恢复后再交付排队的视频请求。手机沿用现有投屏协议，不需要理解 DIAL。

程序在后台不主动同步读取界面节点；播放状态、登录标记和生命周期通过消息缓存到网络任务。测试脚本只模拟手机请求，不提供发现服务、转发或代发频道启动命令。

### 本机结果

测试播放器实际播放同一个普通投稿视频，按收到合成 NVA `Play` 到 ECP 报告本频道正在播放计时。每种状态都先完成 SSDP、设备描述、`GetAppInfo` 和 NVA 握手，并确认发现阶段没有改变电源或前台频道。

| 投放前的状态 | 等待时间 | 自行唤起并起播 |
|---|---:|---:|
| Roku 首页 | 20 秒 | 5.687 秒 |
| 电视待机，`Ready` | 120 秒 | 6.453 秒 |
| YouTube 前台 | 45 秒 | 4.719 秒 |

控制台记录了挂起、恢复，以及**电视接收器自己发出的 DIAL 请求返回 201**。YouTube 前台这一轮还验证了唤起后的 NVA 暂停、继续和停止。表格中的数值来自合成协议测试，不能代替分别验证 Android / iPhone 的原生投屏列表，也没有验证 YouTube 长时间播放造成的内存压力。

待机 120 秒这一轮已记录成功起播，但初版测试脚本在最后读取 Stop 确认时，读满 12 帧状态通知后退出，没有完成确认读取；这一轮不算完整脚本通过。已改为按时限读取，后续 YouTube 前台这一轮的暂停、继续、停止和整个脚本均通过。设备的原始控制台记录与部分本地 JSON 保存在 `build/`，不随仓库发布。

### 实际手机验收与当前部署

2026-11-14 将 `research/roku-background-casting` 的 `bc40515` 安装并保留在电视上。此前实验结束时曾恢复旧版，旧版退出后无法被手机发现；该现象不能作为后台实验分支失败的证据。

本次在退出到 Roku 首页后，接收器依次记录到手机客户端的 Platinum SSDP 搜索、设备描述查询、NVA `Play`、电视本机 `DIAL status=201` 和 `suspended=false`。ECP 随后报告 `dev` 播放器处于 `play`，用户也确认「可以了」。自动测试当时尚在首页等待阶段，没有发送合成 `Play`；它因 App 已被外部请求唤起而结束，不能记作整轮自动回归通过。

原始事件的相对时间更明确：挂起 `5.061s`，`12.575s` 起读取频道的设备描述，`12.618s` 搜索 `upnp:rootdevice`，`12.694s` 读取 `NirvanaControl.xml`，`14.771s` 调用 `GetAppInfo`，`14.831s` 建立 NVA 连接，`15.190s` 发出 `Play`，`15.356s` 才出现 `self-wake DIAL status=201`，`15.393s` 频道恢复。`self-wake` 是频道接收 `Play` 后向本机 `127.0.0.1:8060/dial/RokuBiliCast` 发出的请求；它不是手机的 DIAL 启动请求。

用户此次确认的是实际手机后台投屏可用，没有分别记录 Android、iPhone 及其客户端版本。原始部署信息和脱敏事件保存在忽略目录 `build/background-cast-current-deployment.json`。

**仍无永久常驻保证。** 频道被系统回收后接收器也会消失。长期待机、内存压力、其他系统版本及两种手机平台的分别验收仍待完成。Roku 不再支持应用内 ECP 调用；本机 DIAL 在实机可用，不代表获得商店发布许可。当前证据支持评估将其作为实验功能合并，但不等于完成稳定版或商店发布验收。

### 电视重启后的启动：重新调查

遥控器关机进入 `Ready` 待机、返回 Roku 首页、系统菜单里的「系统重启」是三种不同状态。前两种已经在本机验证；真正重启后接收器是否启动，尚未做实机验收。前一轮调查期间电视正在播放，因此当时只进行了不会打断播放的网络读取；后续主动实验见下文。

2026-11-14 在 M302X / Roku OS 16.0.4 向电视搜索不同的 SSDP 类型，实际收到：

| 请求类型 | Roku 系统回应 | 本频道接收器回应 |
| --- | --- | --- |
| `upnp:rootdevice` | `:8060/` | `:9958/description.xml` |
| `urn:app-bilibili-com:service:NirvanaControl:3` | 无 | `:9958/description.xml` |
| `urn:dial-multiscreen-org:service:dial:1` | `:8060/dial/dd.xml` | 无 |

Roku 系统的 `:8060/` 描述了 ECP 和 DIAL，但没有 `MediaRenderer` 或 `NirvanaControl`；本频道的 `:9958/description.xml` 才提供这些 B 站手机端实际访问过的服务。系统**有** `upnp:rootdevice` 发现入口，却没有直接提供所需的 B 站接收协议。此前手机真实投屏依次访问本频道的描述、`GetAppInfo` 和 NVA `Play`，因此仅添加 `dial_title` 尚不能证明手机会在频道冷启动前发现它。手机是否存在另一个未观察到的 DIAL 路径，需要在没有 `:9958` 接收器时单独验证。

现有日志只来自频道自己的 `:9958` TCP/UDP 服务，记录不到手机对 Roku 系统 `:8060` 的单播请求。频道的 SSDP 处理器也只有在自己对搜索类型作出回应时才写 `discovery` 日志；它不会记录不匹配的 DIAL 搜索。因此日志足以确定本次成功投屏使用了 `NirvanaControl`/NVA，**不能单凭日志中没有 DIAL 搜索就断定手机绝不支持 DIAL**。旧版控制台记录的多轮手机投屏也出现相同的 B 站服务路径，但没有弥补这个观测盲区。

[Manifest 官方文档](https://developer.roku.com/dev/docs/channel-manifest)列出的 `dial_title` 把频道注册到系统 DIAL，由**知道 DIAL 应用名的外部发送方**发起启动；`usb_media_handler` 只针对 USB 设备插入。没有找到普通频道可注册的开机后台任务。[Instant Resume 官方文档](https://developer.roku.com/dev/docs/instant-resume)说明它保留的是设备 RAM 中的进程，也可能因内存压力被回收；文档还写明后台任务在挂起五秒后被阻塞。本机实验曾观察到任务在挂起超过两分钟后继续响应，这说明当前固件上的行为与文档不一致，不能把实验现象当作重启后自动启动的保证。

[Roku 屏保](https://developer.roku.com/dev/docs/screensavers)会在用户设定的闲置时间后自动运行，是一个可进一步实验的电视端触发器；它不会在重启瞬间启动，而且官方要求屏保独立成应用，禁止将屏保打包进视频应用。即使做独立屏保，也必须验证其接收器在屏保退出后能否继续工作，否则不能满足「任何时候从手机投屏」的目标。留置 USB 设备则要验证重启时是否会产生插入事件，还会把视频应用带到前台，不能视为静默开机服务。

### 进程彻底结束后的手机验收

2026-11-14 后续实际运行了一个更小的对照实验，直接保留当前播放器包，
使用官方 ECP `POST /exit-app/dev/true` 强制结束进程，而不更换 DIAL 名称：

| 检查项 | 结果 |
| --- | --- |
| ECP 强制结束 | HTTP 200，`status=OK` |
| `/query/app-state/dev` | `inactive` |
| `/dial/RokuBiliCast` | HTTP 200，`state=stopped` |
| App 接收器 `:9958/status` | 连接失败 |
| 用户从 Android B 站视频页重新搜索 | 用户明确反馈「找不到」 |

同时在电脑进行了**不按 ST 过滤的被动组播记录**，没有应答搜索、
代理设备或转发投屏。到恢复 App 时已记录到手机的 78 条
`upnp:rootdevice` 搜索，UA 与先前的 Platinum 日志一致。这补上了
App 只记录已回应 ST 的盲区，但仍不覆盖手机与电视之间的单播 HTTP。

这次验收确认的是：**当前 `RokuBiliCast` 配置在 App 进程消失后，
不能单靠系统 DIAL 出现在该手机的投屏列表里。**
不能扩展成「所有 B 站版本、所有可能的 DIAL 名称都不支持」。
恢复时由电脑明确发出 DIAL 请求，返回 201，接收器重新在线；
这属于测试后的人工恢复，不能记作手机冷启动成功。

此前通过 ECP 发送遥控器重启组合后，没有观察到 uptime 归零。
系统 UI 查询也只给出 NativeUIFacadeScreen，无法可靠读取设置菜单。
**本轮仍未完成真正的系统重启测试，进程结束对照不冒充重启。**
原始证据保存在忽略目录 `build/cold-boot-observation.json`、
`build/process-termination-phone-acceptance.json`。

可复用的被动观测器：

```powershell
python tests/cast/cold_boot_probe.py --ip <电视IP> --seconds 180 --output build/cold-boot-observation.json
```

它只发送 GET 请求、被动记录组播 M-SEARCH，不发送启动、重启、
投屏或发现应答。重启/退出命令需独立执行并记录；判定真实重启依赖
uptime 下降，不能只看网络短暂断开。它每次查询 DIAL 的固定名称是
`RokuBiliCast`，因此不适合直接判断其他实验包的 DIAL 是否注册。

### 官方 Android 安装包的静态核对

从 Bilibili 官方下载页取得 Android 64 位包，只在电脑解包检查；
没有给手机安装软件。包标识 `tv.danmaku.bili`，版本 `9.19.0`、
versionCode `9190400`。`classes12.dex` 含 Nirvana 服务类型、
`GetAppInfo` 与 Nirvana/投屏实现类；`libnirvana.so` 含 Platinum、
MediaRenderer、AVTransport 等实现标记，和实际手机日志相符。

扫描包内 36 个 DEX 和 94 个本地库时，没有找到所检查的 DIAL/Roku 标记，
包括 `dial-multiscreen`、`DIALService`、`roku:ecp`、`/dial/`。
这是缩小调查方向的静态线索，**不是完整反编译后的控制流证明**；
未排除动态加载或拼接，也未确认用户手机运行的就是这个版本。
下载来源、SHA-256、版本和命中记录保存在忽略目录 `build/`。

### 屏保启动入口的实机对照

进一步部署了三种仅在电视上运行的小型诊断包：

- 普通 `Main` 与 `RunScreenSaver` 同包：安装成功，但没有加入系统屏保列表。
- 同包增加旧的 `screensaver_private=0`：仍没有加入系统屏保列表。
- 去掉 `Main` 的独立屏保：加入系统屏保列表，但安装后没有自动启动接收器。

所以在这台电视上，**简单地给当前播放器附加屏保入口没有成功**。
独立屏保是否能在闲置启动后承担接收器尚未验证；它会改变应用形态、
依赖用户选用屏保和闲置计时，不能描述为已经实现开机后台自启。
详情与构建脚本见 [启动入口实验](../experiments/startup-probe/README.md)。

所有临时诊断包均已替换回原来可用的后台投屏包，校验了安装包哈希、
9958 监听和组播加入。系统选中的屏保仍为 Roku City。本轮没有修改
生产 `channel/`、合并 main 或发布。

### 本阶段结论与暂停点

2026-11-14 按用户要求记录结论，暂停自动启动方向的实现，先合并已经
完成的播放页与后台投屏工作。已证实的是「先打开过频道、进程仍在时，
退出界面后可以从手机投屏唤回」，没有实现或验收「系统重启后自动就绪」。

当前使用前提是：系统重启或接收进程被清理后，先手动打开频道一次，
再退出到首页使用手机投屏。此处是现有启动机制的使用约定，不代表完成了
完整重启后的验收。后续若继续研究，需要找到可重复验证的电视端启动入口；
独立屏保保留为未验证候选，不作为已提供的功能，也不引入电脑桥接或手机 APK。

独立诊断记录见 [网络生命周期实验](../experiments/lifecycle-probe/README.md)。真实接收器回归：

```powershell
python tests/cast/background_wake.py --ip <电视IP> --bvid <允许测试的视频BV号> --case standby --idle-seconds 120 --output build/background-cast-standby-results.json
```

该命令会切换电视电源和播放状态，必须先安装并打开实验包。`--case home` 和 `--case other-app` 分别测试首页与其他频道前台。

## 当前状态

- 0.1.4 首次由手机视频播放页投放并在电视播放。0.1.7 修复快速切换时强制停止请求导致的 Roku 执行超时，以及大视频详情解析慢的问题。
- 对一条约 77 万字符的视频详情响应，编号精度保护的替换步骤从约 15.7 秒降为实机三次测量的 0.43–0.53 秒。同一视频从收到投放指令到起播，实测约 2.4–3.6 秒。这些数字只描述被测设备、视频和网络。
- 真实 Roku 上已自动验证连续六次投放时只播放最新请求、请求中途停止后不会迟到起播、取消后重新播放、替换播放器。后续实际手机后台投屏验收见上文；合并后的播放页与投屏组合仍需完整回归，电脑模拟协议通过不能代替所有手机入口的兼容性验证。
- 当前针对普通投稿视频的 BV/av 标识及分 P。电视端点播画质与弹幕设置已合并到 `main`，见[播放页实现与验收状态](player-controls-plan.md)。直播投屏、完整番剧投屏、倍速、通用 Chromecast 接收，以及个人页独立发现入口尚未完成。`GetVolume` 当前返回固定值，不代表电视实际音量。

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
