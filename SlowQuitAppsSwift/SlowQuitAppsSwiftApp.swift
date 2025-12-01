//
//  SlowQuitAppsSwiftApp.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI

/// 应用入口, 通过菜单栏图标提供唯一的设置界面并默认启动 Cmd+Q 监听。
@main
struct SlowQuitAppsSwiftApp: App {
    @StateObject private var controller = CmdQController()

    var body: some Scene {
        MenuBarExtra("SlowQuitAppsSwift", systemImage: "keyboard") {
            ContentView(controller: controller)
                .frame(width: 260)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "settings") {
            SettingsView(controller: controller)
                .frame(width: 380, height: 420)
        }
    }

    var commands: some Commands {
        AppCommands()
    }
}
