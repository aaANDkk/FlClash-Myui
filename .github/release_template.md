# FlClash Myui vVERSION

基于 [FlClash 官方 BUILD_VERSION](https://github.com/chen08209/FlClash/tree/vBUILD_VERSION) 的个性化定制版本，增强 IP 查询、配置登机牌与图标集、流量统计、网络测速、仪表盘、字体与 Emoji 定制，以及 Android VPN 后台保活与液态玻璃流畅度。

支持 Android、Windows、macOS、Linux，开源、无广告。

## 本次更新

- 连接与 DNS 查询集中到「请求」页。连接详情新增时间线与路由路径，公网 IP 仍可直接打开风险与归属详情，并继承隐藏 IP 设置。
- 升级代理列表、仪表盘、配置加载与编辑器的渲染性能，继续提供配置登机牌、独立 IP 查询、流量统计、网络测速和自定义字体。
- 统一 IP 查询、IP 详情和出站 IP 的欺诈值刻度与标签。缺少类型数据时显示「未知」。
- 恢复随应用内置的 GeoSite 数据，启动时自动修复已知的损坏缓存。切换配置时取消旧配置的延迟测试，避免其结果覆盖当前节点状态。
- 关于页新增自动检查更新及更新频道设置。macOS 支持应用内安装更新。

## 下载

[下载最新版本](https://github.com/aaANDkk/FlClash-Myui/releases/latest) · [全部版本](https://github.com/aaANDkk/FlClash-Myui/releases)

| 平台 | 安装包 |
| --- | --- |
| Android | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-android-arm64.apk">ARM64</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-android-armv7.apk">ARMv7</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-android-amd64.apk">x86_64</a> |
| Windows x64 | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-windows-amd64-setup.exe">EXE 安装版</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-windows-amd64-portable.zip">ZIP 便携版</a> |
| Windows ARM64 | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-windows-arm64-setup.exe">EXE 安装版</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-windows-arm64-portable.zip">ZIP 便携版</a> |
| macOS | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-macos-arm64.dmg">Apple Silicon</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-macos-amd64.dmg">Intel</a> |
| Linux x64 | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-amd64.AppImage">AppImage</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-amd64.deb">DEB</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-amd64.rpm">RPM</a> |
| Linux ARM64 | <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-arm64.AppImage">AppImage</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-arm64.deb">DEB</a> · <a href="https://github.com/aaANDkk/FlClash-Myui/releases/download/TAG/FlClash-VERSION-linux-arm64.rpm">RPM</a> |

请按设备架构下载，校验文件为 `FlClash-VERSION-SHA256SUMS`。

## 致谢与许可

感谢 [FlClash](https://github.com/chen08209/FlClash)、[mihomo](https://github.com/MetaCubeX/mihomo) 及原项目所有贡献者。

特别致敬 [Bettbox](https://github.com/appshubcc/Bettbox)：IP 查询与欺诈值、流量统计、网络测速功能借鉴并改编自 Bettbox。

本项目遵循 [GPL-3.0](https://github.com/aaANDkk/FlClash-Myui/blob/Myui/LICENSE) 协议。Maple Mono、Twemoji、OpenMoji 等资源保留各自的开源许可与署名。
