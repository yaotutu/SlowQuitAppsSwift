# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

SlowQuitAppsSwift 是一个 macOS 菜单栏应用，通过拦截并延迟 Cmd+Q 快捷键来防止用户误退出应用。应用使用 CGEventTap 监听全局键盘事件，并在用户长按 Cmd+Q 达到设定时长后才真正触发退出，期间会显示一个可自定义的圆环 Overlay 提示。

### 系统兼容性

- **CPU 架构**: Universal Binary（通用二进制）
  - ✅ Apple Silicon（M1/M2/M3/M4）- arm64 原生支持
  - ✅ Intel 处理器 - x86_64 原生支持
  - 无需 Rosetta 2 转译，两种架构均为原生运行

- **系统版本**: macOS 11.0 Big Sur 及以上
  - 最低支持: macOS 11.0（2020 年发布）
  - 推荐版本: macOS 12.0 Monterey 及以上
  - 已测试兼容: macOS 11.x - 15.x

## 核心架构

### 数据流与职责分离

```
SlowQuitAppsSwiftApp (入口)
    └─ CmdQController (协调层)
        ├─ EventMonitor (CGEventTap 封装)
        ├─ HoldOverlayWindowController (UI Overlay)
        └─ PreferencesManager (持久化)
```

- **CmdQController**: 作为中心控制器，管理辅助功能权限检查、EventMonitor 生命周期、以及将 Cmd+Q 事件回调连接到 UI Overlay
- **EventMonitor**: 封装 CGEventTap 的底层 C API，处理 Cmd+Q 按下/释放/超时逻辑，通过闭包回调通知外界
- **HoldOverlayWindowController**: 管理全屏透明 NSPanel，在按住 Cmd+Q 时显示圆环进度
- **PreferencesManager**: 单例模式管理 UserDefaults，提供 holdDuration、displayOverlay、bundleIdentifiers、invertList 四个设置项

### 关键技术点

1. **CGEventTap 回调**: `eventTapCallback` 是全局 C 函数，通过 `UnsafeMutableRawPointer` 将 EventMonitor 实例传入，在回调中调用 `handleEvent` 方法
2. **长按检测**: EventMonitor 在 keyDown 时启动 DispatchSourceTimer，如果 holdDuration 秒内收到 keyUp 或 flagsChanged（Cmd 松开）则取消，否则通过 `sendSyntheticCmdQ` 重新发送 Cmd+Q 事件
3. **模拟事件防护**: `isSimulatingCmdQ` 标志位防止模拟的 Cmd+Q 被再次拦截；`waitForPhysicalKeyUp` 确保长按完成后等待用户真正松开按键
4. **应用过滤**: `shouldHandleCmdQ` 通过 NSWorkspace 获取前台应用的 bundleID，根据 invertList 决定是白名单（跳过列表内应用）还是黑名单（仅延迟列表内应用）

### 文件组织

- `Sources/App/`: 应用入口（SlowQuitAppsSwiftApp.swift）和菜单/设置视图（ContentView.swift）
- `Sources/Controllers/`: CmdQController.swift 负责业务逻辑协调
- `Sources/Services/`: EventMonitor.swift（事件监听）、PreferencesManager.swift（偏好设置）
- `Sources/UI/`: HoldOverlayWindowController.swift（圆环 Overlay）

## 构建与测试

### Xcode 构建

```bash
# 在 Xcode 中打开项目（推荐）
open SlowQuitAppsSwift.xcodeproj

# 命令行构建（Debug）
xcodebuild -scheme SlowQuitAppsSwift -configuration Debug build

# 命令行构建（Release）
xcodebuild -scheme SlowQuitAppsSwift -configuration Release build
```

### 运行测试

```bash
# 执行所有测试（需要创建 SlowQuitAppsSwiftTests/ 目录后添加测试）
xcodebuild test -scheme SlowQuitAppsSwift -destination 'platform=macOS'
```

### CI/CD

项目使用 GitHub Actions 进行自动构建、签名和发布，配置文件位于 `.github/workflows/build.yml`。

#### 触发条件

- 推送到 `release-main` 分支：构建并发布正式版本（如 `v1.0.1`）
- 推送到 `release-dev` 分支：构建并发布开发版本（如 `v0.1.1-dev`，标记为 pre-release）
- 手动触发（workflow_dispatch）

#### 发布流程

1. 使用 `macos-latest` 运行器
2. 导入代码签名证书（如果配置了 Secrets）
3. 构建 Release 配置
   - **有证书**：使用 Developer ID 签名
   - **无证书**：构建未签名版本
4. Apple 公证（Notarization）
   - 上传到 Apple 服务器进行安全检查
   - 装订公证票据到应用
5. 打包为 DMG 和 ZIP 两种格式
6. 自动生成版本号：
   - `release-main`: `v1.0.{RUN_NUMBER}`
   - `release-dev`: `v0.1.{RUN_NUMBER}-dev`
7. 创建 GitHub Release 并上传文件
8. 自动生成 Release Notes

#### 代码签名配置（可选但强烈推荐）

如果不配置签名，用户需要右键打开应用。配置签名后，用户可以直接双击使用。

**需要的 GitHub Secrets（在仓库设置中配置）：**

1. **MACOS_CERTIFICATE** - Developer ID Application 证书（.p12 格式，base64 编码）
2. **MACOS_CERTIFICATE_PASSWORD** - 证书密码
3. **MACOS_CERTIFICATE_NAME** - 证书名称（如 "Developer ID Application: Your Name (TEAM_ID)"）
4. **MACOS_TEAM_ID** - Apple Developer Team ID
5. **APPLE_ID** - Apple ID 邮箱
6. **APPLE_APP_SPECIFIC_PASSWORD** - App 专用密码
7. **KEYCHAIN_PASSWORD** - 临时 keychain 密码（随机字符串即可）

**如何获取证书：**

```bash
# 1. 从 Keychain Access 导出 Developer ID Application 证书为 .p12
# 2. 转换为 base64
base64 -i Certificates.p12 | pbcopy
# 3. 粘贴到 GitHub Secrets 的 MACOS_CERTIFICATE

# 获取证书名称
security find-identity -v -p codesigning

# 获取 Team ID
# 访问 https://developer.apple.com/account/ 查看

# 创建 App 专用密码
# 访问 https://appleid.apple.com/account/manage
# 在"安全"部分生成 App 专用密码
```

#### 发布工作流

推荐的分支策略：

```bash
# 开发新功能在 main 或 feature 分支
git checkout main
git add .
git commit -m "Add new feature"

# 准备发布开发版本
git checkout release-dev
git merge main
git push  # 自动触发构建和发布 pre-release

# 准备发布正式版本
git checkout release-main
git merge main
git push  # 自动触发构建和发布正式版本
```

#### 查看发布

- 构建状态：访问仓库的 Actions 标签页
- 下载应用：访问仓库的 Releases 页面，下载 `SlowQuitAppsSwift.zip`

### 权限配置

应用依赖 macOS 辅助功能权限才能监听全局键盘事件。开发和测试时需要手动授权：

1. 打开"系统设置 → 隐私与安全性 → 辅助功能"
2. 勾选 SlowQuitAppsSwift
3. 如果重新构建或签名变化，需要移除后重新添加

相关文件：
- `Info.plist`: 包含 `NSAccessibilityUsageDescription` 和 `NSAppleEventsUsageDescription`
- `SlowQuitAppsSwift.entitlements`: 禁用沙箱（`com.apple.security.app-sandbox = false`）以便使用 CGEventTap

## 编码规范

- Swift 5.9+，四空格缩进
- 类型/协议使用 PascalCase，函数/变量使用 lowerCamelCase，静态常量使用 UpperCamelCase
- 使用 `@MainActor` 标记 UI 相关类型（CmdQController、HoldOverlayWindowController、PreferencesManager）
- 使用 NSLog 而非 print 记录调试信息，便于在 Console.app 中查看
- 每个类型和关键方法添加中文注释，说明职责和实现细节

## 常见开发任务

### 修改长按时长范围

在 `SettingsView.swift` 中修改 Slider 的 `in:` 参数（当前为 0.5...5 秒，步长 0.5）。

### 调整 Overlay 样式

修改 `HoldOverlayWindowController.swift` 中的 `HoldOverlayView`，包括圆环大小、颜色渐变、字体等。

### 添加新的过滤规则

在 `CmdQController.shouldHandleCmdQ()` 中扩展逻辑，例如根据应用名称、窗口标题等条件判断。

### 调试 CGEventTap

如果 EventMonitor 无法启动，检查：
1. 辅助功能权限是否授予（`AXIsProcessTrustedWithOptions` 返回 false）
2. 是否有其他应用占用 CGEventTap（查看 Console.app 日志）
3. 签名和 entitlements 是否正确（Debug 和 Release 配置需一致）

## 注意事项

- CGEventTap 在系统级别拦截事件，调试时避免死循环或长时间阻塞，否则可能导致键盘无响应
- `sendSyntheticCmdQ` 使用 `.cgAnnotatedSessionEventTap` 而非 `.cgSessionEventTap`，避免事件被本应用再次拦截
- HoldOverlayWindowController 的 panel.level 设置为 `.screenSaver`，确保在全屏应用中也能显示
- 修改 PreferencesManager 的 Keys 时，需要同时更新 `defaults.register(defaults:)` 中的默认值
