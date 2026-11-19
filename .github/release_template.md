# FlClash Myui vVERSION

基于 [FlClash 官方 0.9.4](https://github.com/chen08209/FlClash/tree/v0.9.4) 的个性化定制版本，主要增强独立 IP 查询、流量统计、网络测速、动态流体关于页、字体/Emoji 定制及仪表盘交互体验。

支持 Android、Windows、macOS、Linux，开源、无广告。

## 下载

[下载最新版本](https://github.com/aaANDkk/FlClash-Myui/releases/latest) · [全部版本](https://github.com/aaANDkk/FlClash-Myui/releases)

| 平台 | 安装包 |
| --- | --- |
| Android | [ARM64](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-android-arm64.apk) · [ARMv7](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-android-armv7.apk) · [x86_64](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-android-amd64.apk) |
| Windows x64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-windows-amd64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-windows-amd64-portable.zip) |
| Windows ARM64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-windows-arm64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-windows-arm64-portable.zip) |
| macOS | [Apple Silicon](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-macos-arm64.dmg) · [Intel](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-macos-amd64.dmg) |
| Linux x64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-amd64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-amd64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-amd64.rpm) |
| Linux ARM64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-arm64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-arm64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-dev-VERSION-linux-arm64.rpm) |

选择与你的系统和设备架构对应的安装包，点击即可下载。

## 相比官方 0.9.4 的主要改动

### 独立 IP 查询与风险评估

- **独立「IP 查询」页面**（工具页位于 DNS 查询下方，顺序为 `DNS 查询 → IP 查询 → 流量统计 → 网速测试 → 资源`）：默认自动展示当前出站 IP，支持输入任意公网 IPv4 / IPv6（自动提取端口）即时查询，并支持一键切回出站 IP 与隐藏 IP 隐私保护。
- **自适应横竖屏排版**：横屏上排采用 `9 : 13` 紧凑等高双卡（左：带风险色微光与彩色刻度条的欺诈值卡片；右：固定三组结构的命中标记卡片），底栏采用登机牌虚线分隔风格展示国家/地区、运营商、单行 `ASN · 网络名` 与主机名（左侧国旗与地名随右侧行数自动缩放，右侧叠加全局图标水印）；竖屏采用紧凑等距流式排布。
- **双源并发与缓存**：Scamalytics 与 IPLocate.io 双源并行查询、自动重试与 30 天本地缓存；支持点击请求详情与 DNS 查询结果中的公网 IP 快捷查看 IP 详情，辅助识别机房、住宅代理及线路归属。

### 本地流量统计与网络测速

- **本地流量统计**：总览卡片采用分段刻度圆环展示下载与上传占比，支持按 **3 / 6 / 12 个自然月**保留数据，跨设备休眠精准记录累计运行时间（标题采用字形基线实测对齐），按时间查看域名、进程、节点、配置和规则排行。
- **Speedtest by Ookla 网络测速**：支持选择出站节点与测速服务器，提供阶段进度、实时波形、下载/上传速率、延迟、抖动与响应性指标，以及测速设置与历史记录。

### 动态流体关于页、字体与主题

- **关于页 Miuix 视觉升级**：移植流动色彩高斯模糊背景着色器，采用 `96dp` 无框三条杠 SVG Logo 与 `FlClash` 标题同源实时变色，搭配毛玻璃卡片呈现项目信息与致谢。
- **自定义字体与 Emoji**：支持导入多款 `.ttf` / `.otf` 字体，预览、切换、导出和删除并持久化；Emoji 支持 Twemoji 与 OpenMoji 两种风格，节点名称、国旗与编辑器同步生效；内置等宽字体更换为 Maple Mono（常规 + 粗体）。
- **主题与交互**：文字缩放改为连续调节；弹窗增加背景模糊，纯黑主题下保留层次，启用液态玻璃时避免重复模糊。

### 首页小部件与界面图标

- **首页小部件重排**：状态卡片在 IP 下方展示所属国家/地区与欺诈值，底部显示运行时长与网络类型；网络速度采用手机双栏 / 桌面独立上传下载卡；配置卡片改为“当前配置”（火箭图标）；策略组卡片保留 `0.9.3` 分层图标；服务状态新增经典蓝鸟 Twitter 检测且宽屏支持 4 项展示；桌面/横屏内存固定分两行右对齐。
- **原生矢量图标精修**：按 `prism_ui` 规范重绘「服务状态」极简开弧雷达图标与「备份与恢复」云端勾选图标；部分界面图标采用 Fluent 风格。

### 代理页与配置列表

- **图标样式与正则图标**：代理页右上角菜单支持切换策略组图标风格（填充 / 朴素 / 隐藏），支持通过正则表达式自上而下自动匹配自定义图标并支持拖拽排序。
- **视觉与信息优化**：列表与标签模式统一浅主题色选中背景与主题色边框；支持嵌套策略组图片图标与“分组类型 · 当前节点”副行；外部资源代理提供者置前且无到期时标注“长期有效”；配置列表标签清晰区分本地/长期有效/策略组数。

### 其他调整与修复

- 电脑首页新增亮屏锁按钮并记忆开关状态。
- Windows 单色托盘未运行时随任务栏深浅色自动切换黑白图标（适配 `v0.9.4` `rust_api` 托盘架构）。
- GeoIP、ASN、GeoSite 等资源默认改用 `bett-rules` 下载源（保留用户自定义地址）。
- 语言精简为简体中文、英语、日语、韩语和俄语（完整适配 `v0.9.4` 官方 `gen-l10n`）。

## 致谢与许可

感谢 [FlClash](https://github.com/chen08209/FlClash)、[mihomo](https://github.com/MetaCubeX/mihomo) 及原项目所有贡献者。

特别致敬 [Bettbox](https://github.com/appshubcc/Bettbox)：IP 查询与欺诈值、流量统计、网络测速功能借鉴并改编自 Bettbox。

本项目遵循 [GPL-3.0](https://github.com/aaANDkk/FlClash-Myui/blob/Myui/LICENSE) 协议。Maple Mono、Twemoji、OpenMoji 等资源保留各自的开源许可与署名。
