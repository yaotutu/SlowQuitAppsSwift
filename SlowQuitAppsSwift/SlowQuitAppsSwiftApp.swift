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
    @StateObject private var controller = CmdQController(preferences: PreferencesManager.shared)

    var body: some Scene {
        MenuBarExtra("SlowQuitAppsSwift", systemImage: "keyboard") {
            ContentView(controller: controller)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: "settings") {
            SettingsView(controller: controller)
                .frame(width: 420, height: 460)
        }
    }

    var commands: some Commands {
        AppCommands()
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
