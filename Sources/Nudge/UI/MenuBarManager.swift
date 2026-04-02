import Cocoa
import SwiftUI
import Combine

/// Manages the menubar status item and its dropdown popover.
@MainActor
final class MenuBarManager {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover?
    private let appState: AppState
    private var observation: Any?

    init(appState: AppState) {
        self.appState = appState
        setupStatusItem()
        startObserving()
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName = appState.statusIcon
        let hasAttention = appState.pendingPermissionCount > 0
            || appState.highestPriorityState == .error
            || appState.highestPriorityState == .waitingInput
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Nudge") {
            let configured = image.withSymbolConfiguration(config) ?? image
            // Use template mode for normal state (adapts to light/dark menu bar)
            // Use tinted color only when attention is needed
            if hasAttention {
                configured.isTemplate = false
                button.image = configured
                button.contentTintColor = NSColor(appState.iconColor)
            } else {
                configured.isTemplate = true
                button.image = configured
                button.contentTintColor = nil
            }
        }

        // Badge count
        let pending = appState.pendingPermissionCount
        button.title = pending > 0 ? " \(pending)" : ""
    }

    // MARK: - Private

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        button.target = self

        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Nudge") {
            image.isTemplate = true
            button.image = image.withSymbolConfiguration(config) ?? image
        }
    }

    private func startObserving() {
        // Use withObservationTracking to watch AppState changes
        observation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                withObservationTracking {
                    _ = self.appState.statusIcon
                    _ = self.appState.iconColor
                    _ = self.appState.pendingPermissionCount
                } onChange: {
                    Task { @MainActor [weak self] in
                        self?.updateIcon()
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.performClose(nil)
            self.popover = nil
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 300)
        popover.behavior = .transient

        let hostingController = NSHostingController(
            rootView: MenuBarView(appState: appState, onFocusSession: { session in
                _ = WindowFocuser().focusSession(session)
            })
        )
        // Let SwiftUI determine the actual height
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        if let button = statusItem.button {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        }

        self.popover = popover
    }
}
