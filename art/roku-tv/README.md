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

对外显示名称统一为 **Roku小电视**，包括手机投屏列表。内部 DIAL 名称
`RokuBiliCast`、协议标识、应用版本号和登录存储不因品牌调整而更改。

默认主题色为粉色，默认字体为黑体。已保存的主题和字体选择继续生效；
无设置或无效值分别回退到粉色、黑体。

本次工作由 `feature/roku-tv-branding` 分支完成，按用户确认以 `--no-ff` 合入
`main` 并推送；尚未发布或部署此品牌版本。安装包和本地合成预览生成在被 Git
忽略的 `build/` 中。实机界面和手机投屏列表仍需在安装新版本后验证。
