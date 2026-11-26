# AI 代理启动器 · 手机版 (Android & iOS)

基于 **Flutter（零第三方网络/系统插件依赖）+ 原生 Kotlin / Swift 平台桥接**，将桌面端 `AIProxyLauncher` 的全协议代理探测、节点地区核验、快捷切节点测速、SOCKS5 自动桥接中继、DNS / IPv6 深度体检与一键 AI 应用唤起完整移植到 **Android 与 iOS 手机**。

---

## 核心功能（与桌面版对齐）

- **全协议移动代理与旁路由通用适配**
  - 自动检测手机系统 VPN / 虚拟网卡（Android `NetworkCapabilities.TRANSPORT_VPN` / `tun0`；iOS `CFNetwork` `utun`）及 Wi-Fi 系统代理。
  - 自动发现本机或局域网（如电脑端 / 旁路由）的 **Clash / Mihomo / Stash / Sing-box 控制接口**、HTTP 代理与纯 **SOCKS5** 代理。
  - 适配 **FlClash、Clash Meta (CMFA)、v2rayNG、Hiddify、sing-box、NekoBox、Karing、Surfboard、Shadowsocks、WireGuard、Stash、Shadowrocket、Surge、Loon、Quantumult X、Clash Mi、V2Box** 等主流客户端，且无本机代理端口时自动执行非中国大陆出口实测兜底（兼容 **路由器 / 旁路由透明代理**）。
- **12+ AI 服务与真实出口地区核验**
  - 直接通过原生 `RawSecureSocket` / HTTP `CONNECT` / RFC 1928 `SOCKS5` 验证 `ChatGPT`、`ChatGPT WS`、`Codex WS`、`Claude`、`Anthropic API`、`Gemini`、`Google OAuth`、`Code Assist`、`Antigravity`、`Grok`、`Perplexity` 等端点连通性、延迟与 Cloudflare 出口地区，遇到香港 / 中国大陆等受限地区自动标黄提醒。
- **快捷切节点 + 一键避开受限地区**
  - 连接本机或局域网 Clash 控制接口后，可在 App 内浏览分流组、并发测速并一键切换至最快的非受限地区节点（密钥仅驻留内存，绝不落盘）。
- **内置本地中继（`127.0.0.1:17890` · HTTP + SOCKS5 自动桥接）**
  - 遇到纯 SOCKS5 端口自动拉起本地 HTTP 桥接中继，严格限制在 `127.0.0.1`，无上游时返回 `HTTP 502`，绝不发生直连泄漏。
- **VPN / DNS / IPv6 深度体检与脱敏诊断报告**
  - 排查 Fake-IP、DNS 污染与公网 IPv6 泄漏风险，支持一键复制不含密钥与敏感尾段 IP 的脱敏诊断报告。
- **一键唤起手机 AI App 与网页版**
  - 自动识别手机已安装的 ChatGPT、Claude、Gemini、Grok、Perplexity 原生 App 并直达唤起，未安装则自动打开官方网页版；支持自定义扩展 AI 网址与深浅双主题。

---

## 安装方式

### 1. Android（直接安装 APK）
1. 在 GitHub Actions（`Mobile Build & Release`）或 Releases 中下载 **`AIProxyLauncher-Android.apk`**。
2. 传输到手机后点击安装即可（无需任何商店或签名工具）。

### 2. iOS（免签 / 自签 / Xcode）
1. **TrollStore / AltStore / Sideloadly / 爱思助手**：直接下载 **`AIProxyLauncher-iOS-unsigned.ipa`** 导入签名安装。
2. **Xcode 自行签名或上架 TestFlight**：
   - 下载 **`AIProxyLauncher-iOS-XcodeProject.zip`**（或直接克隆本分支的 `mobile/` 目录），在 Mac 上执行：
     ```bash
     cd mobile
     bash scripts/setup_native.sh
     flutter pub get
     open ios/Runner.xcworkspace
     ```
   - 在 Xcode `Signing & Capabilities` 中选择你的 Apple ID / Team 后点击 Run 真机安装。

---

## 本地开发与测试

```bash
cd mobile
bash scripts/setup_native.sh   # 生成/同步 Android Gradle 与 iOS Xcode 工程
flutter pub get
flutter analyze                # 静态分析
flutter test                   # 运行全部单元测试与 Widget 测试
flutter build apk --release    # 构建 Android 通用 APK
flutter build ios --release --no-codesign  # 构建 iOS Release（需 macOS）
```

