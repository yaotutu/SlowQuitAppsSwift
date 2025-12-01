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
            Label(permissionStatusText, systemImage: controller.hasAccessibilityPermission ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(controller.hasAccessibilityPermission ? .green : .orange)

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

            if !controller.hasAccessibilityPermission {
                Button {
                    controller.openAccessibilitySettings()
                } label: {
                    Label("打开辅助功能设置…", systemImage: "gearshape.2")
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
                            Image(systemName: controller.hasAccessibilityPermission ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(controller.hasAccessibilityPermission ? .green : .orange)
                                .font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(controller.hasAccessibilityPermission ? "已获得辅助功能权限" : "尚未获得辅助功能权限")
                                    .font(.headline)
                                Text("SlowQuitAppsSwift 需要辅助功能才能监听 Cmd+Q。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Button("重新检测") { controller.checkAccessibilityPermission() }
                            Button("打开系统设置") { controller.openAccessibilitySettings() }
                            Spacer()
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
