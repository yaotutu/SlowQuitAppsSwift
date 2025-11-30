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
                .frame(width: 320)
        }
        .menuBarExtraStyle(.window)

        Settings {
            ContentView(controller: controller)
                .frame(width: 360)
        }
    }
}
