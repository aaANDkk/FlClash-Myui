# FlClash Myui vVERSION

基于 [FlClash 官方 0.9.3](https://github.com/chen08209/FlClash/tree/v0.9.3) 的个性化定制版本，主要调整字体、首页小部件、代理页和 IP 查询体验。

支持 Android、Windows、macOS、Linux，开源、无广告。

## 下载

[下载最新版本](https://github.com/aaANDkk/FlClash-Myui/releases/latest) · [全部版本](https://github.com/aaANDkk/FlClash-Myui/releases)

| 平台 | 安装包 |
| --- | --- |
| Android | [ARM64](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-android-arm64-v8a.apk) · [ARMv7](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-android-armeabi-v7a.apk) · [x86_64](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-android-x86_64.apk) |
| Windows x64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-windows-amd64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-windows-amd64.zip) |
| Windows ARM64 | [EXE 安装版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-windows-arm64-setup.exe) · [ZIP 便携版](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-windows-arm64.zip) |
| macOS | [Apple Silicon](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-macos-arm64.dmg) · [Intel](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-macos-amd64.dmg) |
| Linux x64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-amd64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-amd64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-amd64.rpm) |
| Linux ARM64 | [AppImage](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-arm64.AppImage) · [DEB](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-arm64.deb) · [RPM](https://github.com/aaANDkk/FlClash-Myui/releases/download/vVERSION/FlClash-BUILD_VERSION-linux-arm64.rpm) |

选择与你的系统和设备架构对应的安装包，点击即可下载。

## 相比官方 0.9.3 的主要改动

### 字体与主题

- 支持导入多款 `.ttf`、`.otf` 字体，预览、切换、导出和删除，重启后保留选择。
- Emoji 支持 Twemoji、OpenMoji 两种风格，节点名称、国旗和编辑器同步使用。
- 内置等宽字体更换为 Maple Mono，支持常规和粗体。
- 文字缩放改为连续调节。
- 弹窗增加背景模糊；纯黑主题下保留深色弹窗层次，启用液态玻璃时避免重复模糊。

### 首页小部件

- 状态卡片在 IP 下方显示当前代理节点，底部显示运行时长和网络类型，替换原来的组织信息。
- 网络速度重新排版：手机端下载、上传双栏显示，配合上下分向柱状图；电脑端分别显示上传和下载卡片，使用不同颜色区分。
- 配置卡片改为“当前配置”，使用火箭图标，底部展示“外部资源”和“代理节点”统计。
- 配置详情统一展示“外部资源、代理节点、路由规则、策略组”。
- 服务状态新增 Twitter 检测，使用经典蓝鸟图标；首页在宽度足够时显示四个服务。
- 电脑和横屏下，内存信息固定分两行显示，数值靠右对齐。
- 调整连接和策略组大卡片的展开条件，适配高缩放和较矮窗口。

### 代理页与配置列表

- 列表、标签模式统一使用浅主题色选中背景和主题色边框，取消选中对勾，保留固定节点图钉。
- 支持显示嵌套策略组的图片图标，列表组标题下显示“分组类型 · 当前节点”。
- 风格、布局和卡片尺寸选项使用随当前选择变化的图标。
- 外部资源中代理提供者排在规则集前，无到期时间时同时显示节点数量和“长期有效”。
- 配置列表用标签区分“长期有效”“本地”和自定义配置策略组数量，副标题集中显示用量与更新时间。

### 请求、DNS 与 IP 查询

- 请求详情的公网目标地址、远程目标，以及 DNS 查询结果中的公网 IP，支持点击查看“IP 详情”。
- **快捷查看节点相关 IP 的归属地、组织和 ASN，辅助判断是否涉及“狗妈”“奶爸”，以及国内入口、专线等线路。**
- 公网 IP 前显示可识别的国家或地区旗帜，支持 IPv4、IPv6 查询。
- IP 详情在当前面板内切换，全局“隐藏 IP”设置同步生效；公网地址连同端口一起隐藏，内网、保留地址和 Fake-IP 保持明文。

### 其他调整与修复

- 电脑首页新增亮屏锁，支持记住开关状态。
- Windows 单色托盘未运行时随任务栏主题显示黑色或白色图标。
- Windows 使用连续曲率圆角，侧边栏宽度随菜单文字调整，部分界面图标采用 Fluent 风格。
- 工具页“进阶配置”改为“配置”，内部划分“进阶”和“自定义”。
- 修复运行时配置中的国旗、Emoji 显示为转义字符的问题。
- 修复代理组图片短暂消失、工具页启动后自动滚到底部、配置统计长期不显示，以及部分动态策略组停留在空回退的问题。
- GeoIP、ASN、GeoSite 等资源默认改用 bett-rules 下载源，保留用户自行设置的地址。
- 语言精简为简体中文、英语、日语、韩语和俄语。

## 致谢与许可

感谢 [FlClash](https://github.com/chen08209/FlClash)、[mihomo](https://github.com/MetaCubeX/mihomo) 及原项目所有贡献者。

本项目遵循 [GPL-3.0](https://github.com/aaANDkk/FlClash-Myui/blob/Myui/LICENSE) 协议。Maple Mono、Twemoji、OpenMoji 等资源保留各自的开源许可与署名。
