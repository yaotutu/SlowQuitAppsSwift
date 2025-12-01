import SwiftUI
import Combine
import AppKit

@MainActor
final class HoldOverlayState: ObservableObject {
    @Published var progressRatio: Double = 0
    @Published var durationText: String = ""
}

private struct HoldOverlayView: View {
    @ObservedObject var state: HoldOverlayState

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 148, height: 148)
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(state.progressRatio, 1))))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.orange, .red, .pink]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)

            VStack(spacing: 4) {
                Text("按住 Cmd+Q")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Text(state.durationText)
                    .font(.title2.monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(12)
    }
}

@MainActor
final class HoldOverlayWindowController: ObservableObject {

    private let state = HoldOverlayState()
    private lazy var hostingController = NSHostingController(rootView: HoldOverlayView(state: state))
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 144, height: 144),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 144, height: 144)
        panel.contentViewController = hostingController
        return panel
    }()

    private var progressTimer: Timer?
    private var holdStartDate: Date?
    private var holdDuration: TimeInterval = 1.0

    func startHold(duration: TimeInterval) {
        holdDuration = duration
        holdStartDate = Date()
        state.progressRatio = 0
        state.durationText = String(format: "%.1f 秒", duration)
        showPanelIfNeeded()
        startTimer()
    }

    func cancelHold() {
        hidePanel()
    }

    func completeHold() {
        state.progressRatio = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.hidePanel()
        }
    }

    func forceHide() {
        hidePanel()
    }

    private func showPanelIfNeeded() {
        updatePanelFrame()
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        progressTimer?.invalidate()
        progressTimer = nil
        holdStartDate = nil
        state.progressRatio = 0
        panel.orderOut(nil)
    }

    private func startTimer() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleTick()
            }
        }
        progressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTick() {
        guard let start = holdStartDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        if holdDuration > 0 {
            state.progressRatio = min(1, elapsed / holdDuration)
            let remaining = max(0, holdDuration - elapsed)
            state.durationText = String(format: "%.1f 秒", remaining)
        } else {
            state.progressRatio = 1
            state.durationText = "0.0 秒"
        }
        updatePanelFrame()
    }

    private func updatePanelFrame() {
        let cursor = NSEvent.mouseLocation
        let size = panel.frame.size
        let targetScreen = NSScreen.screens.first { NSMouseInRect(cursor, $0.frame, false) } ?? NSScreen.main

        guard let screen = targetScreen else { return }
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2
        )

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
