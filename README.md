# AI 代理启动器 (AIProxyLauncher)

跨平台（Windows / macOS）AI 客户端与网页代理启动器。**100% 纯 Python 3.11+ 标准库编写，零第三方运行时依赖**。

自动检测本机正在运行的各类代理软件（不局限于某一款客户端），实时验证 12+ 项主流 AI 服务连通性与出站节点，并安全引导桌面客户端、CLI 与独立网页窗口通过正确代理运行。

---

## 下载安装包

请前往本仓库右侧 **[Releases](../../releases)** 页面直接下载编译好的可执行程序：

- **Windows**：下载 `AIProxyLauncher.exe`（单文件绿色版，双击即用，无需安装 Python）
- **macOS**：下载 `AIProxyLauncher-macOS-arm64.zip`（解压后双击 `AIProxyLauncher.app`）或通用源码包 `AIProxyLauncher-macOS-Source.zip`（需安装带 Tk 的 Python 3.11+，双击 `macos-start.command`）

详细使用与排查步骤请参阅：[Windows 使用说明](使用说明.md) ｜ [macOS 使用说明](macOS使用说明.md)

---

## 核心特性

- **通用代理自动适配**：支持 Clash Verge Rev、Clash Party / Mihomo Party、JImmm、FlClash、Clash Nyanpasu、Sparkle、ClashX、Stash、Surge、v2rayN、Hiddify、NekoBox / Throne、Karing、Shadowsocks、Xray / Sing-box 等 20+ 代理客户端；任何开启系统代理或本地 HTTP 端口的未知客户端均可自动发现，并保留「手动指定端口」兜底模式。
- **统一本地中继（换代理免重启、网页免重登）**：内置严格仅监听 `127.0.0.1:17890` 的纯标准库 HTTP/CONNECT 中继层（[relay.py](relay.py)）。开启后独立网页窗口共用持久化资料目录（换代理软件不再掉登录），后台按目标域名热切换上游与 `350ms` 快速故障转移，无可用上游时严格返回 `HTTP 502` 绝不直连泄漏。
- **按服务精准识别出口节点与真实地区**：直连 `chatgpt.com` / `claude.ai` 等目标域名检测出口，并从 Clash `/connections` 提取每个服务实际命中的出站节点名与延迟；遇受限地区自动高亮提醒并在择优与换节点时自动避开。
- **零子进程原生底层通信（Windows）**：通过 `ctypes` 直接调用 Win32 异步重叠命名管道与 `iphlpapi.GetExtendedTcpTable` 内核 TCP 表（[win32net.py](win32net.py)），告别 `powershell.exe` / `netstat.exe` 轮询开销，毫秒级刷新。
- **内置快捷切节点、环境体检与 DNS/IPv6 诊断**：支持分流组并发测速切换节点；自动审计并带 `.bak` 备份一键修复环境变量、`.codex/.env`、`.gitconfig`、`.npmrc` 中的失效旧代理端口；排查 DNS 污染 / Fake-IP 异常与公网 IPv6 泄漏，一键复制脱敏诊断报告。
- **现代化可视化界面与常驻体验**：浅色 / 暗黑双主题、健康度圆环、3×3 矢量应用卡片、分类筛选、系统托盘、单实例防多开唤醒、开机静默自启（`--minimized`）以及休眠唤醒 / 系统代理变更看门狗。

---

## 从源码运行与构建

```bash
# 运行（需要 Python 3.11+ 与内置 Tkinter）
python launcher.py

# 静默启动到系统托盘
python launcher.py --minimized

# 命令行探针检查（输出 JSON）
python launcher.py --check

# 运行全量单元测试（66 项）
python -B -m unittest -v
```

### 本地打包

- **Windows**：
  ```powershell
  .\build-windows.ps1              # 跑测试 + 生成 新版\AIProxyLauncher.exe + 刷新 macOS 源码包
  .\build-windows.ps1 -SourceOnly  # 仅跑测试并刷新 macOS 源码包
  ```
- **macOS**：
  ```bash
  bash build-macos.sh              # 生成当前架构 AIProxyLauncher.app 与 ZIP
  bash build-macos.sh universal2   # 使用 Universal2 Python 构建通用架构包
  ```

### 自动发布（GitHub Actions）

推送 `v*` 标签（如 `git tag v2.0.0 && git push origin v2.0.0`）或在 Actions 页面手动触发 **Build & Release** 工作流，即可自动在 Windows 与 macOS 云端构建并发布所有平台的可执行文件到 GitHub Releases。

