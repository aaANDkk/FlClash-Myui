# FlClash Myui vVERSION

基于 [FlClash 官方 0.9.4](https://github.com/chen08209/FlClash/tree/v0.9.4) 的个性化定制版本，增强 IP 查询、配置登机牌与图标集、流量统计、网络测速、仪表盘、字体与 Emoji 定制，以及 Android VPN 后台保活与液态玻璃流畅度。

支持 Android、Windows、macOS、Linux，开源、无广告。

## 本次更新

- **Android VPN 保活与无感接管**：重开应用时直接接管已在运行的 VPN 服务而不重复重载配置；将后台服务升级为 `startService` + `START_STICKY` 粘性前台服务，补充 `establish()` / `protect(fd)` 瞬时重试与停止回调双向复核，修复后台偶发自动暂停运行的问题。
- **配置页登机牌与内置图标集**：配置页重构为登机牌布局，横屏票根统一采用两行平铺全部操作并移除票面装饰水印；支持为各配置单独选择自定义图标，并内置 [Qure-Style-SVG](https://github.com/aaANDkk/Qure_Style_SVG) 图标集（2,370 枚 SVG 图标）。
- **全站 `tone2` 灰轨统一与 IP 登机牌对齐**：首页当前配置、配置页波浪条与圆环、IP 查询欺诈值刻度条、流量统计与网速测试的所有未填充底轨统一为 `DashboardColors.tone2`；IP 查询横屏归属卡竖虚线新增上下半圆缺口并与上方双卡中缝严格垂直对齐。
- **液态玻璃切页与关于页转场优化**：开启液态玻璃时底栏淡入切页全程保留页面快照防闪烁，关于页着色器延后至进入工具页且转场完全静止后空闲预热，修复关于页下滑顶部回跳，规范简体中文界面中英文间距。

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

- **独立「IP 查询」页面**：位于工具页 `DNS 查询 → IP 查询 → 流量统计 → 网速测试 → 资源`；默认自动检测并展示当前「出站 IP 地址」，支持输入任意公网 IPv4 / IPv6（自动提取端口）即时查询，提供一键切回出站 IP 与隐藏 IP 隐私保护。
- **横竖屏自适应与登机牌归属卡**：横屏顶部按 `9 : 13` 并排展示欺诈值与命中标记，下方归属信息卡片采用带上下半圆缺口的竖虚线分隔国家/地区与运营商、ASN、主机名，且撕口中线与上方双卡间距严格垂直对齐；竖屏采用流式纵向卡片。
- **双源并发与全局联动**：Scamalytics 与 IPLocate.io 双源并行查询、自动重试（最多 3 次）与 30 天本地持久化缓存；请求详情与 DNS 查询结果中的公网 IP 支持直接点击弹出 IP 风险与归属详情。

### 配置页登机牌与自定义图标

- **配置页登机牌布局**：当前配置按远程订阅、本地 YAML 与自定义配置重构为登机牌卡片；远程订阅内嵌波浪流量进度条与到期信息（无流量上限或无期限时自动显示「长期有效」），本地 YAML 与自定义配置统一显示「上次编辑」时间与 3 格统计块（资源/策略组、节点、规则）；下方「其他配置」以独立卡片展示剩余流量 + `28dp` 圆环或类型徽标。
- **横竖屏自适应票根**：竖屏右上角保留主操作与 `⋯` 液态玻璃弹出菜单；横屏票根通过上下半圆缺口竖虚线分隔，将全部操作直接排为紧凑两行（远程上排 3 枚胶囊 + 下排 6 枚圆钮，本地 YAML 与自定义按各自操作双行平铺），无需二次弹窗。
- **自定义配置图标与内置图标集**：远程、本地 YAML 与自定义配置分别配备专属默认矢量图标，支持点击主卡图标或配置菜单为任意配置单独绑定自定义图标；应用内置 [Qure-Style-SVG](https://github.com/aaANDkk/Qure_Style_SVG) 图标集（预置 2,370 枚 SVG 图标，标注「内置」，长按支持同步更新与跳转项目地址）。

### 本地流量统计与网络测速

- **本地流量统计**：总览卡片采用 20 刻度分段圆环展示下载与上传占比，底部灰块集中呈现跨设备休眠累计运行时长（剥离单调时钟防止深睡漏计，标题采用实测字形基线对齐）及代理/直连分流明细；支持按 **3 / 6 / 12 个自然月**保留数据，按时间范围查看域名、进程、节点、配置和规则的流量与请求排行。
- **Speedtest by Ookla 网络测速**：支持指定出站节点与测速服务器，实时展示赛博仪表盘、下载/上传双通道波形、阶段进度、延迟、抖动、负载延迟与响应性指标，支持测速设置与历史记录管理。
- **全站统一 `tone2` 轨道色**：首页当前配置、配置页远程波浪条与用量圆环、IP 查询欺诈值刻度条、流量统计圆环与排行横条、网速测试仪表盘与阶段进度条的未填充灰轨统一接入 `DashboardColors.tone2`（`SurfaceLevel.inset`），深浅色层次一致。

### 动态流体关于页、字体与液态玻璃

- **关于页 Miuix 视觉与转场精调**：移植流动色彩高斯模糊背景着色器，采用 `96dp` 无框三条杠 SVG Logo 与 `FlClash` 标题同源实时变色，搭配毛玻璃卡片呈现项目信息与致谢；着色器在进入「工具」页且转场动画完全静止后空闲预热，路由过渡期间暂停背景 Ticker 并延后毛玻璃采样，且消除了页面下滑时的顶部回跳。
- **自定义字体与双风格 Emoji**：支持导入多款 `.ttf` / `.otf` 字体，预览、切换、导出和删除并跨重启持久化；Emoji 支持 Twemoji 与内置 OpenMoji 两种风格，节点名称、国旗与编辑器同步生效；内置等宽字体更换为 Maple Mono（常规与粗体）。
- **液态玻璃帧率与切页优化**：为页面底板建立独立 `RepaintBoundary` 图层，减少菜单展开时的背景重绘；开启液态玻璃时，底栏淡入与滑动切页全程复用离屏页面快照直至过渡结束，消除切页闪烁并修正 RTL 位移；关闭液态玻璃时还原官方底栏底板并保留不透明彩色选中滑块。

### 首页小部件与代理页增强

- **首页小部件重排**：状态卡片在 IP 下方展示所属国家/地区与欺诈值（悬浮提示完整地区与城市），底部显示运行时长与网络类型；网络速度采用手机双栏上下分向柱状图、电脑独立上传与下载双卡；「当前配置」小部件（火箭图标）展示订阅用量或配置统计；策略组小部件保留 `0.9.3` 分层 5 图标并移除宽度比例上限，保持原尺寸完整显示；服务状态新增经典蓝鸟 Twitter 检测且宽屏支持 4 列；电脑与横屏内存信息固定分两行右对齐。
- **原生矢量图标精修**：按 `prism_ui` 原生矢量规范重绘「服务状态」极简开弧雷达图标与「备份与恢复」云端勾选图标；部分界面图标采用 Fluent 风格。
- **代理页图标样式、正则匹配与缓存**：右上角菜单支持切换策略组图标风格（填充 / 朴素 / 隐藏），支持通过正则表达式自上而下为策略组自动匹配自定义图标（支持拖拽排序与批量管理）；支持嵌套策略组图片图标，列表组标题下显示「分组类型 · 当前节点」；代理页小 SVG 图标按设备像素比光栅化并纳入 Flutter `ImageCache`，远程图标持久化至应用数据目录、设置 7 天最低有效下限并在回前台时异步预热，彻底解决长后台返回时靠下策略组图标重新加载的问题；外部资源中代理提供者排在规则集前，无到期时间时同时显示节点数与「长期有效」。

### Android 后台保活与系统体验

- **Android VPN 保活与防自动暂停**：重开应用时若原生 VPN 已在运行则直接无感接管启动时间与状态，不再重复执行配置重载或重启网卡；原生 `VpnService` / `ProxyService` 升级为 `startService` + `START_STICKY` 粘性前台服务，防止主界面被后台清理断开绑定时连带销毁 VPN；为 `establish()`（300ms 延迟重试）与 `protect(fd)`（5 次重试）增加瞬时容错，并在收到延迟停止回调时双向复核 `isRunRequested` 运行意图，消除切网或唤醒时的假停止回旋镖与莫名自动暂停。
- **桌面端与多语言细节**：电脑首页新增亮屏锁按钮并记忆开关状态；Windows 单色托盘未运行时随任务栏深浅色自动切换黑白图标（适配 `v0.9.4` `rust_api` 托盘架构）；Windows 采用连续曲率圆角与自适应宽度侧边栏；GeoIP、ASN、GeoSite 默认改用 `bett-rules` 下载源；语言精简为简体中文、英语、日语、韩语和俄语（适配官方 `gen-l10n` 并自动规范简体中文中英文间距）；修复公开仓库应用内更新的 `SHA256SUMS` 校验清单匹配。

## 致谢与许可

感谢 [FlClash](https://github.com/chen08209/FlClash)、[mihomo](https://github.com/MetaCubeX/mihomo) 及原项目所有贡献者。

特别致敬 [Bettbox](https://github.com/appshubcc/Bettbox)：IP 查询与欺诈值、流量统计、网络测速功能借鉴并改编自 Bettbox。

本项目遵循 [GPL-3.0](https://github.com/aaANDkk/FlClash-Myui/blob/Myui/LICENSE) 协议。Maple Mono、Twemoji、OpenMoji 等资源保留各自的开源许可与署名。
