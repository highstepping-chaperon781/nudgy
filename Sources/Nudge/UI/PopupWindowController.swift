import Cocoa
import SwiftUI

/// Manages floating toast-style notification panels.
@MainActor
final class PopupWindowController {
    private var activePanels: [(panel: NSPanel, item: NotificationItem, id: UUID)] = []
    private var dismissTimers: [UUID: Task<Void, Never>] = [:]
    private let maxVisible: Int = 3
    private let stackGap: CGFloat = 4
    private let edgePadding: CGFloat = 12
    private let panelWidth: CGFloat = 240
    private let panelHeight: CGFloat = 46

    var onDismiss: ((UUID) -> Void)?
    var onAction: ((NotificationAction) -> Void)?
    var preset: PopupPreset = {
        PopupPreset(rawValue: UserDefaults.standard.string(forKey: "nudge.popupPreset") ?? "") ?? .minimal
    }()

    func show(_ item: NotificationItem) {
        // Cap visible popups
        if activePanels.count >= maxVisible {
            if let oldest = activePanels.last {
                dismiss(id: oldest.id)
            }
        }

        let panel = createPanel(for: item)
        activePanels.insert((panel: panel, item: item, id: item.id), at: 0)
        repositionPanels(animated: true)

        // Slide in from right
        let target = calculatePosition(at: 0)
        panel.setFrameOrigin(NSPoint(x: target.x + 40, y: target.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.08 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(target)
            panel.animator().alphaValue = 1.0
        }

        // Auto-dismiss
        if let delay = item.autoDismissAfter {
            dismissTimers[item.id] = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                dismiss(id: item.id)
            }
        }
    }

    func dismiss(id: UUID) {
        dismissTimers[id]?.cancel()
        dismissTimers.removeValue(forKey: id)

        guard let index = activePanels.firstIndex(where: { $0.id == id }) else { return }
        let panel = activePanels[index].panel

        let origin = panel.frame.origin
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = reduceMotion ? 0.06 : 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: origin.x + 40, y: origin.y))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            Task { @MainActor [weak self] in
                self?.activePanels.removeAll { $0.id == id }
                self?.repositionPanels(animated: true)
            }
        })

        onDismiss?(id)
    }

    func dismissAll() {
        for entry in activePanels {
            dismiss(id: entry.id)
        }
    }

    var visibleCount: Int { activePanels.count }

    // MARK: - Private

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func createPanel(for item: NotificationItem) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // Shadow handled by SwiftUI
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        panel.animationBehavior = .none

        let view = PopupContentView(
            item: item,
            onDismiss: { [weak self] in self?.dismiss(id: item.id) },
            onAction: { [weak self] action in self?.onAction?(action) },
            preset: preset
        )
        panel.contentView = NSHostingView(rootView: view)
        return panel
    }

    private func calculatePosition(at index: Int) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let visible = screen.visibleFrame
        let offset = CGFloat(index) * (panelHeight + stackGap)
        return NSPoint(
            x: visible.maxX - panelWidth - edgePadding,
            y: visible.maxY - panelHeight - edgePadding - offset
        )
    }

    private func repositionPanels(animated: Bool) {
        for (i, entry) in activePanels.enumerated() {
            let pos = calculatePosition(at: i)
            if animated && !reduceMotion {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.22
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    entry.panel.animator().setFrameOrigin(pos)
                }
            } else {
                entry.panel.setFrameOrigin(pos)
            }
        }
    }
}
