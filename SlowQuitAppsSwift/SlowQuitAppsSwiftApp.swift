//
//  SlowQuitAppsSwiftApp.swift
//  SlowQuitAppsSwift
//
//  Created by yaotutu on 2025/11/28.
//

import SwiftUI

/// 应用入口, 负责创建 SwiftUI 场景并加载根视图。

@main
struct SlowQuitAppsSwiftApp: App {
    /// macOS 应用只需要一个默认的 WindowGroup, 其中承载 ContentView。
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
