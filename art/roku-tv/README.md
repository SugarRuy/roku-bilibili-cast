# Roku小电视品牌资源

采用用户在 2026-11-14 提供并确认接入的粉色小电视设计：

- `icon-reference.png`：512 × 512 原始图标参考。
- `tile-reference.png`：540 × 405 原始磁贴；直接用于 FHD 首页磁贴。
- `scripts/make_branding.py`：按参考图描绘透明小电视，用于不同尺寸的页头、启动图和缺图占位图；HD 磁贴由原始磁贴缩小得到。

在项目根目录运行（需要 Pillow）：

```sh
python scripts/make_branding.py
```

启动画面字体使用项目已有的 `channel/fonts/hei.ttf`，与新的界面默认黑体一致；
首页磁贴保留原图文字。完整的 `scripts/make-art.py`
也调用这份品牌生成脚本，重建图片时会保留新名称和图标。

品牌、App 内文字、磁贴及手机投屏名称为 **Roku小电视**。
Roku 系统 Apps 列表名称使用 **Roku BiliBiliTV**：用户确认该系统页面把三个汉字显示为空框，
而频道字体覆盖表包含「小电视」，App 内也已单独加载中文字体。系统列表采用 manifest
的名称，不能复用频道 Label 的 Font 设置，因此采用英文作为系统文字回退。
此修正由 `fix/roku-system-title` 分支完成，已合入本地 main，尚未发布；
v0.2.0 标签保持原内容。本轮本地合并没有更新电视安装版。
内部 DIAL 名称
`RokuBiliCast`、协议标识和登录存储不因品牌调整而更改；发布版本号单独维护。

默认主题色为粉色，默认字体为黑体。已保存的主题和字体选择继续生效；
无设置或无效值分别回退到粉色、黑体。

本次工作由 `feature/roku-tv-branding` 分支完成，按用户确认以 `--no-ff` 合入
`main` 并推送，纳入 v0.2.0 预发布版。合并提交 `c43f064` 已安装到当前 Roku TV，
确认首页新名称、Logo、粉色主题、列表加载及登录状态保留；新名称的手机投屏列表
尚未单独复验。安装包和本地预览保存在被 Git 忽略的 `build/` 中。
