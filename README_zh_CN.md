# FlClash Myui

基于 [FlClash 官方 0.9.4](https://github.com/chen08209/FlClash/tree/v0.9.4) 的个性化定制版本，主要增强独立 IP 查询、流量统计、网络测速、动态流体关于页、字体/Emoji 定制及仪表盘交互体验。

支持 Android、Windows、macOS、Linux，开源、无广告。

## 下载

[下载最新版本](https://github.com/aaANDkk/FlClash-Myui/releases/latest) · [全部版本](https://github.com/aaANDkk/FlClash-Myui/releases)

| 平台 | 安装包 |
| --- | --- |
| Android | [ARM64](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-android-arm64.apk) · [ARMv7](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-android-armv7.apk) · [x86_64](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-android-amd64.apk) |
| Windows x64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-windows-amd64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-windows-amd64-portable.zip) |
| Windows ARM64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-windows-arm64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-windows-arm64-portable.zip) |
| macOS | [Apple Silicon](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-macos-arm64.dmg) · [Intel](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-macos-amd64.dmg) |
| Linux x64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-amd64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-amd64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-amd64.rpm) |
| Linux ARM64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-arm64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-arm64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/v0.9.4/FlClash-dev-0.9.4-linux-arm64.rpm) |

选择与你的系统和设备架构对应的安装包，点击即可下载。

## 相比官方 0.9.4 的主要改动

### 独立 IP 查询与风险评估

- **独立「IP 查询」页面**（工具页位于 DNS 查询下方，顺序为 `DNS 查询 → IP 查询 → 流量统计 → 网速测试 → 资源`）：默认自动展示当前出站 IP，支持输入任意公网 IPv4 / IPv6（自动提取端口）即时查询，并支持一键切回出站 IP 与隐藏 IP 隐私保护。
- **自适应横竖屏排版**：横屏上排采用 `9 : 13` 紧凑等高双卡（左：带风险色微光与彩色刻度条的欺诈值卡片；右：固定三组结构的命中标记卡片），底栏采用登机牌虚线分隔风格展示国家/地区、运营商、单行 `ASN · 网络名` 与主机名（左侧国旗与地名随右侧行数自动缩放，右侧叠加全局图标水印）；竖屏采用紧凑等距流式排布。
- **双源并发与缓存**：Scamalytics 与 IPLocate.io 双源并行查询、自动重试与 30 天本地缓存；请求详情与 DNS 查询结果中的公网 IP 支持点击查看 IP 详情，快捷识别归属地、组织、ASN 及线路类型。

### 本地流量统计与网络测速

- **本地流量统计**：总览卡片采用分段刻度圆环展示下载与上传占比，支持按 **3 / 6 / 12 个自然月**保留数据，跨设备休眠精准记录累计运行时间（标题采用字形基线实测对齐），按时间查看域名、进程、节点、配置和规则的流量与请求排行。
- **Speedtest by Ookla 网络测速**：支持选择出站节点和测速服务器，展示阶段进度、下载、上传、延迟、抖动、负载延迟与响应性，保留仪表动画、实时波形、设置与测速记录。

### 动态流体关于页、字体与主题

- **关于页 Miuix 视觉升级**：移植流动色彩高斯模糊背景着色器，采用 `96dp` 无框三条杠 SVG Logo 与 `FlClash` 标题同源实时变色，搭配毛玻璃卡片呈现项目信息与致谢。
- **自定义字体与 Emoji**：支持导入多款 `.ttf`、`.otf` 字体，预览、切换、导出和删除，重启后保留选择；Emoji 支持 Twemoji、OpenMoji 两种风格，节点名称、国旗和编辑器同步使用；内置等宽字体更换为 Maple Mono（常规与粗体）。
- **主题与交互**：文字缩放改为连续调节；弹窗增加背景模糊，纯黑主题下保留深色弹窗层次，启用液态玻璃时避免重复模糊。

### 首页小部件与界面图标

- 状态卡片在 IP 下方显示所属国家/地区与欺诈值（悬浮提示完整地区与城市），底部显示运行时长和网络类型。
- 网络速度重新排版：手机端下载、上传双栏显示，配合上下分向柱状图；电脑端分别显示上传和下载卡片，使用不同颜色区分。
- 配置卡片改为“当前配置”（火箭图标），底部展示“外部资源”和“代理节点”统计；配置详情统一展示“外部资源、代理节点、路由规则、策略组”。
- 策略组小部件保留 `0.9.3` 分层图标；服务状态新增 Twitter 经典蓝鸟检测，宽屏支持四项展示。
- 按 `prism_ui` 原生矢量规范重绘「服务状态」极简开弧雷达图标与「备份与恢复」云端勾选图标。
- 电脑和横屏下，内存信息固定分两行显示，数值靠右对齐；调整连接和策略组大卡片展开条件，适配高缩放和较矮窗口。

### 代理页与配置列表

- 新增「图标样式」与「正则图标」设置（代理页右上角菜单）：支持切换策略组图标展示风格（填充 / 朴素 / 隐藏）；支持通过正则表达式自上而下为策略组自动匹配自定义图标，规则列表支持拖拽排序与批量管理。
- 列表、标签模式统一使用浅主题色选中背景和主题色边框，取消选中对勾，保留固定节点图钉。
- 支持显示嵌套策略组的图片图标，列表组标题下显示“分组类型 · 当前节点”。
- 外部资源中代理提供者排在规则集前，无到期时间时同时显示节点数量和“长期有效”。
- 配置列表用标签区分“长期有效”“本地”和自定义配置策略组数量，副标题集中显示用量与更新时间。

### 其他调整与修复

- 电脑首页新增亮屏锁，支持记住开关状态。
- Windows 单色托盘未运行时随任务栏主题自动切换黑色或白色图标（适配 `v0.9.4` `rust_api` 托盘架构）。
- Windows 使用连续曲率圆角，侧边栏宽度随菜单文字调整，部分界面图标采用 Fluent 风格。
- GeoIP、ASN、GeoSite 等资源默认改用 `bett-rules` 下载源，保留用户自行设置的地址。
- 语言精简为简体中文、英语、日语、韩语和俄语（完整适配 `v0.9.4` 官方 `gen-l10n`）。

## 致谢与许可

感谢 [FlClash](https://github.com/chen08209/FlClash)、[mihomo](https://github.com/MetaCubeX/mihomo) 及原项目所有贡献者。

特别致敬 [Bettbox](https://github.com/appshubcc/Bettbox)：IP 查询与欺诈值、流量统计、网络测速功能借鉴并改编自 Bettbox，界面与交互已适配 FlClash 的整体设计。

本项目遵循 [GPL-3.0](LICENSE) 协议。Maple Mono、Twemoji、OpenMoji 等资源保留各自的开源许可与署名。
