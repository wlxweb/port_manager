# Port Manager

一个轻量的跨平台桌面端口管理工具，用 Flutter 构建。它可以帮助你快速查看本机端口占用、定位进程、打开本地服务、复制地址，并在需要时终止占用端口的进程。

当前界面主要针对 macOS 做了桌面体验优化，同时保留 Windows 支持。

## 功能特性

- 查看本机 TCP / UDP 端口占用。
- 按端口、PID、进程名、本地地址、远程地址搜索。
- 按协议筛选端口列表。
- 查看端口和进程详情，包括 PID、父进程 PID、用户、运行时长、启动命令、本地/远程端点等。
- 一键在浏览器中打开监听中的本地 TCP 服务。
- 快速复制 `localhost:<port>` 地址。
- 终止占用端口的进程。
- 分页表格渲染，大量端口时也更流畅。
- 支持 macOS 和 Windows 桌面端。

## 下载安装

前往 [Releases](https://github.com/wlxweb/port_manager/releases) 下载最新版本。

当前 `v1.0.0` 提供：

- macOS: [`port_manager-macos-v1.0.0.zip`](https://github.com/wlxweb/port_manager/releases/download/v1.0.0/port_manager-macos-v1.0.0.zip)
- Windows: [`port_manager-windows-v1.0.0.zip`](https://github.com/wlxweb/port_manager/releases/download/v1.0.0/port_manager-windows-v1.0.0.zip)

GitHub Release 页面中的 `Source code (zip)` 和 `Source code (tar.gz)` 是 GitHub 自动生成的源码包，适合开发者查看或自行编译，不是应用安装包。

## 运行环境

- Flutter SDK，Dart 版本兼容 `^3.12.0`。
- macOS 或 Windows。
- macOS 依赖系统命令：`lsof`、`ps`。
- Windows 依赖系统命令：`netstat`、`tasklist`、`wmic`。

## 从源码运行

安装依赖：

```bash
flutter pub get
```

在 macOS 上运行：

```bash
flutter run -d macos
```

在 Windows 上运行：

```powershell
flutter run -d windows
```

## 构建

构建 macOS 版本：

```bash
flutter build macos --release
```

产物位置：

```text
build/macos/Build/Products/Release/port_manager.app
```

打包 macOS zip：

```bash
ditto -c -k --sequesterRsrc --keepParent \
  build/macos/Build/Products/Release/port_manager.app \
  port_manager-macos-v1.0.0.zip
```

构建 Windows 版本需要在 Windows 主机上执行：

```powershell
flutter build windows --release
```

产物位置：

```text
build\windows\x64\runner\Release\
```

> Flutter 不支持在 macOS 上交叉编译 Windows 应用。

## 自动构建 Windows Release

仓库内提供 GitHub Actions 工作流：

```text
.github/workflows/windows-release.yml
```

可以在 GitHub Actions 页面手动触发，输入 release tag 和版本号后，会在 Windows runner 上构建 release 包，并上传到对应 GitHub Release。

## 使用说明

1. 打开应用后会自动扫描当前端口占用。
2. 使用搜索框按端口、PID、进程名或地址过滤列表。
3. 使用协议按钮切换全部 / TCP / UDP。
4. 点击详情按钮查看完整端口和进程信息。
5. 对监听中的 TCP 端口，可以尝试用浏览器打开。
6. 如确认不再需要某个进程，可点击终止按钮。

## 注意事项

- 终止系统进程可能需要管理员权限。
- “浏览器打开”默认使用 `http://localhost:<port>`，仅适用于该端口提供 HTTP 服务的情况。
- Windows 上部分进程详情取决于系统命令可用性。
- 本工具面向本机开发和排障场景，请谨慎终止未知进程。

## 项目结构

```text
lib/
  main.dart                 # Flutter UI
  models/port_info.dart     # 端口和进程数据模型
  services/port_service.dart # macOS / Windows 端口扫描服务
macos/                      # macOS 桌面工程
windows/                    # Windows 桌面工程
```

## 参与贡献

欢迎提交 issue 和 pull request。贡献前建议先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

本地提交前建议执行：

```bash
dart format lib
flutter analyze
flutter build macos --debug
```

如果修改了 Windows 相关逻辑，请尽量在 Windows 主机上验证：

```powershell
flutter build windows --debug
```

## 安全反馈

如果你发现安全问题，请不要公开创建 issue。请参考 [SECURITY.md](SECURITY.md) 私下反馈。

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。
