//
//  ContentView.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI

/// 菜单栏触发的唯一设置界面, 控制辅助功能授权与 Cmd+Q 监听状态。
struct ContentView: View {

    @ObservedObject var controller: CmdQController

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: controller.isMonitoring ? "keyboard" : "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("SlowQuitAppsSwift")
                .font(.title2)
            Text(statusMessage)
                .font(.callout)
                .foregroundColor(controller.hasAccessibilityPermission ? .green : .orange)

            if controller.hasAccessibilityPermission {
                monitoringControls
            } else {
                permissionInstructions
            }

            Divider()
            Button("退出 SlowQuitAppsSwift") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    /// 权限已授予时的操作区。
    private var monitoringControls: some View {
        VStack(spacing: 8) {
            if controller.isMonitoring {
                Button("停止监听") {
                    controller.stopMonitoring()
                }
            } else {
                Button("开始监听") {
                    controller.startMonitoring()
                }
            }
            Text("拥有辅助功能权限，Cmd+Q 事件将被拦截用于自定义延迟逻辑。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("长按时长: \(controller.holdDuration, specifier: "%.1f") 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $controller.holdDuration, in: 0.5...5, step: 0.5)
            }
        }
    }

    /// 权限缺失时的引导操作。
    private var permissionInstructions: some View {
        VStack(spacing: 8) {
            Text("需要在 系统设置 → 隐私与安全性 → 辅助功能 中勾选 SlowQuitAppsSwift。")
                .font(.footnote)
                .multilineTextAlignment(.center)

            Button("请求辅助功能权限") {
                controller.requestAccessibilityPermission()
            }

            Button("重新检测权限") {
                controller.checkAccessibilityPermission()
            }

            Button("打开辅助功能设置") {
                controller.openAccessibilitySettings()
            }
        }
    }

    private var statusMessage: String {
        if controller.hasAccessibilityPermission {
            return controller.isMonitoring ? "监听 Cmd+Q 中..." : "可以开始监听 Cmd+Q"
        }
        return "等待授权辅助功能权限"
    }
}
