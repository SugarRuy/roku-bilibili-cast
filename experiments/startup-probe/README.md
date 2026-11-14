# Roku 启动入口实验

仅用于 M302X / Roku OS 16.0.4 的可撤销侧载实验，不是播放器更新包。
复用 `../lifecycle-probe` 的 TCP/UDP 9959 诊断任务；响应增加 `entry`，
用于区分 `Main` 与 `RunScreenSaver`。包内不含电脑服务、账号信息或视频。

## 2026-11-14 实测

| 变体 | 安装 | 系统 `/query/screensavers` | 启动情况 |
| --- | --- | --- | --- |
| `Main` + `RunScreenSaver` + `screensaver_title` | 成功 | 没有 `dev` | 正常启动 App，9959 返回 `entry=main` |
| 上述变体加 `screensaver_private=0` | 成功 | 没有 `dev` | 正常启动 App |
| 仅 `RunScreenSaver`，无 `Main` | 成功 | 出现 `Roku startup experiment (dev)` | 安装后停在首页；9959 没有启动 |

对独立屏保发送 ECP `/launch/dev`，请求超时，观察期内仍在首页、
9959 不可用。**没有实际选用该屏保，也没有验证闲置启动、
`RunScreenSaver` 执行、退出屏保后的服务存活或系统重启。**

这个结果排除了在本机直接给普通 App 附加全局屏保入口的简单做法。
它没有排除独立屏保经过进一步开发后承担接收器的可能性，但独立屏保
并非重启立即触发，也不等同于现有视频 App。官方屏保文档禁止
`Main` / `RunUserInterface`，并要求屏保独立；hybrid 模式只探测
实际侧载行为，不能用于证明具备发布资格。

实验后已重新安装原来的 `roku-background-cast-test.zip`：
SHA-256 `1336fb96949de08a12c97cf7021b376dbdc99674388962d936dea2571dd3bd80`。
检查了 `dev` 正常启动、9958 SSDP 绑定和组播加入成功；原有 Roku City
屏保仍被选中。原始结果保存在忽略目录 `build/startup-*.json`。

## 构建

从仓库根目录运行：

```powershell
python experiments/startup-probe/build_package.py --mode hybrid --output build/startup-hybrid-probe.zip
python experiments/startup-probe/build_package.py --mode hybrid --legacy-public-flag --output build/startup-hybrid-public-probe.zip
python experiments/startup-probe/build_package.py --mode screensaver --output build/startup-screensaver-probe.zip
```

上述命令只生成包。部署会替换当前唯一的开发频道，应先保留当前可用
播放器的安装包，实验后恢复它。

参考：Roku 官方 [屏保文档](https://developer.roku.com/dev/docs/screensavers)、
[manifest 文档](https://developer.roku.com/dev/docs/channel-manifest)，以及
[官方屏保示例](https://github.com/rokudev/home-screensaver)。
