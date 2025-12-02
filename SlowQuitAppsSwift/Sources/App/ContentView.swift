//
//  ContentView.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI
import AppKit

/// 菜单栏菜单项，使用原生菜单样式。
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var controller: CmdQController

    private let projectURL = URL(string: "https://github.com/yaotutu/SlowQuitAppsSwift")!

    var body: some View {
        Group {
            Label(permissionStatusText, systemImage: controller.hasAccessibilityPermission ? "checkmark.shield.fill" : (controller.needsPermissionRestartAdvice ? "arrow.clockwise.circle" : "exclamationmark.triangle.fill")) // 根据控制器状态动态展示图标，蓝色圆箭头代表需要重启
                .foregroundColor(controller.hasAccessibilityPermission ? .green : (controller.needsPermissionRestartAdvice ? .blue : .orange)) // 权限正常为绿色，待重启为蓝色，其余情况为橙色

            Button {
                openWindow(id: "settings")
                NSApp?.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                handlePermissionCheck()
            } label: {
                Label("检查权限…", systemImage: "shield.lefthalf.filled")
            }

            if !controller.hasAccessibilityPermission { // 仅在尚未完全获得辅助功能权限时显示辅助操作
                Button {
                    controller.openAccessibilitySettings() // 引导用户打开系统设置页面勾选权限
                } label: {
                    Label("打开辅助功能设置…", systemImage: "gearshape.2") // 使用齿轮图标暗示系统设置入口
                }
                if controller.needsPermissionRestartAdvice { // 如果控制器判断用户已开始授权流程，则提示必须重启
                    Text("若已在系统中勾选 SlowQuitAppsSwift，需要重新启动本应用后权限才会生效。") // 解释 macOS 的限制，避免用户误解
                        .font(.footnote) // 使用注脚大小平衡视觉层级
                        .foregroundColor(.secondary) // 使用次要颜色强调这是提示文本
                        .padding(.horizontal, 4) // 略微增加两侧间距，避免文字紧贴按钮
                    Button {
                        controller.restartAfterManualPermissionConfirmation() // 用户确认已授权后，主动触发重启
                    } label: {
                        Label("我已完成授权，立即重启", systemImage: "arrow.clockwise") // 给出明确按钮说明与旋转箭头图标
                    }
                }
            }

            Button {
                openProjectPage()
            } label: {
                Label("检查更新…", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
                NSApp?.activate(ignoringOtherApps: true)
            } label: {
                Label("关于 SlowQuitAppsSwift", systemImage: "info.circle")
            }

            Button {
                openProjectPage()
            } label: {
                Label("发送反馈…", systemImage: "text.bubble")
            }

            Button {
                openProjectPage()
            } label: {
                Label("支持项目 ❤️", systemImage: "heart.fill")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出 SlowQuitAppsSwift", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func openProjectPage() {
        NSWorkspace.shared.open(projectURL)
    }

    private func handlePermissionCheck() {
        let status = controller.reportPermissionStatus()
        if status.granted {
            presentAlert(title: "权限已授予", detail: status.message)
        } else {
            presentAlert(title: "需要辅助功能权限", detail: status.message)
            controller.requestAccessibilityPermission()
        }
    }

    private func presentAlert(title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private var permissionStatusText: String {
        controller.hasAccessibilityPermission ? "辅助功能权限已授予" : "需要辅助功能权限"
    }
}

struct SettingsView: View {
    @ObservedObject var controller: CmdQController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox("辅助功能权限") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: controller.hasAccessibilityPermission ? "checkmark.shield.fill" : (controller.needsPermissionRestartAdvice ? "arrow.clockwise.circle" : "exclamationmark.triangle.fill")) // 设置视图顶部图标，与菜单一致展示当前权限状态
                                .foregroundColor(controller.hasAccessibilityPermission ? .green : (controller.needsPermissionRestartAdvice ? .blue : .orange)) // 根据不同状态渲染颜色，蓝色表示等待重启
                                .font(.system(size: 28)) // 使用较大的图标尺寸提升可读性
                            VStack(alignment: .leading, spacing: 4) {
                                Text(controller.hasAccessibilityPermission ? "已获得辅助功能权限" : (controller.needsPermissionRestartAdvice ? "已授权，需重启应用" : "尚未获得辅助功能权限")) // 文案根据状态切换，蓝色状态强调需重启
                                    .font(.headline) // 保持标题字体层级
                                Text(controller.needsPermissionRestartAdvice ? "macOS 会在应用重新启动后启用新的权限，点击下方按钮即可自动重启。" : "SlowQuitAppsSwift 需要辅助功能才能监听 Cmd+Q。") // 给出针对性的说明
                                    .font(.caption) // 说明文本使用 caption
                                    .foregroundColor(.secondary) // 说明文本使用次要色
                            }
                        }
                        HStack {
                            Button("重新检测") { controller.checkAccessibilityPermission() } // 允许用户手动刷新权限状态
                            Button("打开系统设置") { controller.openAccessibilitySettings() } // 跳转至系统隐私设置
                            Spacer() // 将按钮推到左侧，保持布局舒适
                        }
                        if controller.needsPermissionRestartAdvice { // 如果系统仍报告未授权但用户已经勾选，提供立即重启入口
                            Divider() // 添加分割线区分提示区域
                            VStack(alignment: .leading, spacing: 6) {
                                Text("若已在系统设置中允许 SlowQuitAppsSwift 控制你的 Mac，请点击下方按钮重新启动本应用。") // 提示说明
                                    .font(.caption) // 使用更小字号
                                    .foregroundColor(.secondary) // 使用次级颜色
                                Button {
                                    controller.restartAfterManualPermissionConfirmation() // 触发自动重启流程
                                } label: {
                                    Label("我已授权，立即重启应用", systemImage: "arrow.clockwise") // 按钮文案与图标呼应重启动作
                                }
                            }
                        }
                    }
                    .padding()
                }

                GroupBox("基础设置") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("长按时长")
                            Spacer()
                            Text("\(controller.holdDuration, specifier: "%.1f") 秒")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $controller.holdDuration, in: 0.5...5, step: 0.5)
                        Toggle("显示长按提示", isOn: $controller.displayOverlay)
                    }
                    .padding()
                }

                GroupBox("应用例外列表") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("添加应用 Bundle ID 来快速跳过或仅针对特定应用启用延迟。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        List {
                            ForEach(Array(controller.bundleIdentifiers.enumerated()), id: \.offset) { index, value in
                                HStack {
                                    TextField("com.example.App", text: Binding(
                                        get: { value },
                                        set: { controller.updateBundleIdentifier(at: index, with: $0) }
                                    ))
                                    Button(role: .destructive) {
                                        controller.removeBundleIdentifiers(at: IndexSet(integer: index))
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .frame(height: 220)

                        HStack {
                            Button("添加当前应用") { controller.addFrontmostApplication() }
                            Button("添加空白行") { controller.addEmptyBundleIdentifier() }
                            Spacer()
                        }

                        Toggle(controller.invertList ? "仅延迟上述应用" : "跳过上述应用", isOn: $controller.invertList)
                    }
                    .padding()
                }
            }
            .padding(24)
        }
        .frame(minWidth: 460)
    }
}
