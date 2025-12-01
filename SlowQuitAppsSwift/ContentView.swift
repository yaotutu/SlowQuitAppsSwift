//
//  ContentView.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI
import AppKit

/// 菜单栏中的简洁控制面板。
struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var controller: CmdQController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("显示", systemImage: "eye")
                .font(.headline)
                .padding(.bottom, 4)

            Divider()

            Button("Settings…") {
                openWindow(id: "settings")
                NSApp?.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("检查权限…") {
                controller.requestAccessibilityPermission()
            }

            Button("检查更新…") {
                // TODO: 后续集成更新检查
            }

            Divider()

            Button("关于 SlowQuitAppsSwift") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
                NSApp?.activate(ignoringOtherApps: true)
            }

            Button("发送反馈…") {
                if let url = URL(string: "mailto:slowquitapps@example.com") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("支持项目 ❤️") {
                if let url = URL(string: "https://github.com/dteoh/SlowQuitApps") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("退出 SlowQuitAppsSwift") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(minWidth: 220)
    }

    private var statusMessage: String {
        if controller.hasAccessibilityPermission {
            return controller.isMonitoring ? "监听 Cmd+Q 中..." : "可以开始监听 Cmd+Q"
        }
        return "等待辅助功能授权"
    }
}

struct SettingsView: View {
    @ObservedObject var controller: CmdQController

    var body: some View {
        Form {
            Section("基础设置") {
                HStack {
                    Text("长按时长")
                    Spacer()
                    Text("\(controller.holdDuration, specifier: "%.1f") 秒")
                        .foregroundColor(.secondary)
                }
                Slider(value: $controller.holdDuration, in: 0.5...5, step: 0.5)

                Toggle("显示长按提示", isOn: $controller.displayOverlay)
            }

            Section("应用例外列表") {
                Text("每行输入一个 Bundle ID。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $controller.appListText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)

                Toggle(controller.invertList ? "仅对上述应用添加延迟" : "跳过上述应用",
                       isOn: $controller.invertList)
            }
        }
        .padding()
    }
}
