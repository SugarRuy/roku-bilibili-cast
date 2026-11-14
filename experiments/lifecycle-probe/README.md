# Roku 本机后台网络实验

这是独立诊断频道，不是发布包。它只在 Roku 上运行 TCP/UDP 服务；`measure.py` 是一次性测量客户端，不提供发现广播、转发或启动代理。

## 2026-11-14 实测

设备：M302X，Roku OS 16.0.4。启用 `sdk_instant_resume=1`、`run_as_process=1`、`Scene.allowBackgroundTask=true`。

| 状态 | 已测持续时间 | TCP / UDP | 进程 |
|---|---:|---|---|
| 频道前台 | 基准 | 均响应随机请求标识 | 同一实例 |
| Home，系统报告频道 stopped | 35 秒 | 均响应 | 同一实例 |
| PowerOff，系统报告 Ready、首页前台 | 35 秒 | 均响应 | 同一实例 |
| YouTube 前台 | 45 秒 | 均响应 | 同一实例 |

系统控制台确实记录了 `AppSuspendComplete` / `AppResumeComplete`，不是误把前台频道当作后台。任务循环完全使用本地变量，不读取或写入场景节点。

随后请求只发往电视的实验端口 9959，**由电视任务自己**向 `127.0.0.1:8060/dial/RokuLifecycleProbe` 发起 POST：

- 首页：DIAL 201，重新进入诊断频道，测得请求耗时 0.453 秒。
- 待机：DIAL 201，`Ready` 变为 `PowerOn`，测得请求耗时 0.641 秒。
- YouTube 前台：DIAL 201，重新进入诊断频道。
- 使用电视自身的 LAN 地址调用 DIAL 也成功。

这些结果证明本设备上的短期后台监听和本机唤回界面可行；不能据此保证开机自启、永久常驻、内存压力下存活、其他型号或未来系统版本。

## 与文档的差异

[Roku Instant Resume 官方文档](https://developer.roku.com/dev/docs/instant-resume)写到挂起后的后台任务在 5 秒后阻塞。本实验的独立任务在 35 / 45 秒仍然执行请求，因此不能把那句话直接当作所有网络任务停止的实测结论。界面节点访问会不会导致额外阻塞，需要对真实接收器单独验证。

[ECP 官方文档](https://developer.roku.com/dev/docs/external-control-api)也说明不再支持应用内部发出 ECP 指令，并有商店静态检查。本实验使用同机 DIAL 路由；实机成功不等于获得商店发布许可，不能把它视为官方保证的后台服务机制。

## 复现

先打包本目录的 `manifest`、`source/`、`components/`，安装为开发频道。不要把 Python、日志或本地凭据打入包。

```powershell
python experiments/lifecycle-probe/measure.py --ip <电视IP>
python experiments/lifecycle-probe/measure.py --ip <电视IP> --exercise --output build/lifecycle-results.json
```

第一条命令只读取。`--exercise` 会切换首页、待机并通过电脑发送 DIAL 恢复诊断频道；它测的是网络生命周期，**不能单独证明电视自行唤起**。

本机唤起单独测量：频道在首页或待机至少 10 秒后，向电视 9959 端口 POST `/self-wake/loopback`。检查响应的 `wake.code` 和电视 `/query/active-app`、`/query/device-info`。这里启动请求由电视执行。`/self-wake/lan` 用于对照同机 LAN 地址。

每次测量使用不同的随机标识，检查响应内容、实例 ID 和计数器，避免把 TCP 握手、缓存或旧响应误判为任务仍在执行。

原始测量仅保存在忽略目录 `build/lifecycle-*-results.json`，不包含账号、视频 URL 或凭据。
