# 全屏播放卡死：诊断与防护修复

修复分支：`fix/player-progress-timeout`，基于评论功能分支的 `1682df5`。
本分支包含尚未合并的评论功能，不应当作 main 的独立补丁包发布。

## 已取得的证据

用户确认故障发生在全屏播放期间。电视调试日志记录：

```text
Execution timeout (runtime error &h23)
pkg:/components/widgets/DanmakuLayer.brs(153)
sub onPosition()
    p = m.top.video.position
```

渲染线程进入 BrightScript 调试暂停，之后出现
`EXIT_DECODER_NOT_RELEASED`；再次打开时还出现 `EXIT_SYSTEM_KILL`。
原安装包的 Source Digest 为 `65d4e5c7`，与评论测试包对应。

这是明确的程序／运行时超时，不能归结为用户按了暂停。
但报错行仅能定位超时被报告的位置，不能证明该字段读取是全部根因。
这段弹幕监听逻辑也存在于 main，评论分支没有修改它。

强制终止并重开 App 后，ECP 的 active-app 能返回 dev，但 app-ui 查询超时，
日志停在编译结束、进入 main 之前。安装新的测试包也没有清除此状态。
两次远程重启按键序列均未观察到 uptime 归零，因此不能宣称重启成功；
当时曾请用户实际断电重启；后续已找到并验证开发者 HTTP 重启接口，
无需用户拔电，见下方恢复记录。

## 针对性修改

1. 弹幕进度回调使用 `roSGNodeEvent.getData()`，状态回调使用状态事件及其
   `getInfo().position`，不在高频回调中再次读取播放器字段。
2. 弹幕关闭时移除自己的 state／position 监听并停掉时钟；重新开启时只做
   一次播放器快照同步。使用 scoped 监听，避免移除播放器其他组件的监听。
3. 更换绑定的视频时解除旧监听，并拒绝旧视频的迟到事件。
4. 更换／清空 cid 时取消原弹幕任务，迟到结果必须匹配当前任务才能接收。
5. 统一 `releasePlayback()`：停止视频、移除监听、清空弹幕绑定、关闭评论、
   停止 HUD 计时器、取消未完成请求并发布 stopped 状态。重复清理不重复保存进度。
6. 所有 PlayerScreen 出栈路径都执行清理，包括普通返回、deep link 替换、
   投屏换视频和 Home。播放结束后的清理保留已经写入的完成进度。

这些是防护性修复；仍需实机回归和正常长时间使用确认，不能仅凭编译通过
或短时间未复现就认定长期卡死已经彻底解决。

## 验证记录

`python tests/ui/run_comments.py` 共 85 项断言通过。其中新增 25 项覆盖：

- 关闭弹幕不监听视频；重绑只解除自身监听。
- 回调只用事件值，即使模拟的 Video 字段已不可读也能更新。
- 旧视频事件、关闭后的排队事件被忽略；重新开启按当前进度同步。
- 释放时取消弹幕任务，移除播放器监听，停止解码。
- 解码器尚未回报 stopped 时，投屏状态仍立即标为停止。
- 重复退出不重复保存；已完成进度不被退出清理覆盖。

BrighterScript 编译及电视端编译通过。该修复完成时尚未恢复真机，
不能把当时的安装成功当作 App 已恢复响应。

## 后续恢复记录

在 `fix/remote-seek-controls` 分支安装并验证遥控器修正时，继续排查：

1. 强制退出已生效，`query/app-state/dev` 返回 `inactive`，
   接收端口关闭；当时 YouTube 仍可正常播放。不是没有权限结束 App。
2. 新测试包仍停在编译完成后。调试终端 `clear_launch_caches` 返回 `Done.`，
   再启动也没有恢复。
3. 临时去掉 `sdk_instant_resume` 和 `run_as_process` 的诊断包仍然挂起。
   随后只有 `Main`、一个 Scene 和一条 Label 的最小程序也没有输出
   `Main entered`；排查范围因此缩小到开发程序启动环节，不能归因于快进或评论代码。
4. 找到官方 [MCP device_reboot](https://developer.roku.com/dev/docs/rsg-sdk-mcp-device-reboot)
   文档描述的开发者接口：经过开发者认证，向 `/plugin_swup` 提交
   `mysubmit=Reboot`。本机网页的表单明确使用 **multipart/form-data**。
   最初的 URL encoded 请求未重启；按网页表单格式提交后返回 HTTP 200，
   设备短暂离线，`uptime` 从约 791841 秒降到 18 秒，证实真正重启。
5. 在重启前已恢复完整遥控器测试包，保留后台启动配置。
   重启后 App 正常启动，9958 接收服务在线，视频、评论分屏、
   暂停／继续、遥控选位和手机控制回归通过。

没有清空账号、恢复出厂设置或留下最小诊断程序。
本次恢复需要实际重启电视；单独结束 App、清缓存和关闭后台启动配置
没有解除当时的挂起状态。不能因此推论每次 App 故障都必须重启电视。
短时间正常工作也不能证明最初执行超时的全部根因已修复。
