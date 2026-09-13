import AppKit
import SwiftUI

@MainActor
public final class WindowCloseHandler: NSObject, NSWindowDelegate {
    public static let shared = WindowCloseHandler()
    
    public weak var mainWindow: NSWindow?
    private var localKeyMonitor: Any?
    
    private override init() {
        super.init()
        installKeyMonitor()
    }
    
    public func register(window: NSWindow) {
        self.mainWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
    }
    
    private func installKeyMonitor() {
        // Intercept Cmd+Q and Cmd+W to minimize to menu bar instead of terminating background monitoring
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) {
                let char = event.charactersIgnoringModifiers?.lowercased()
                if char == "q" || char == "w" {
                    if AppState.shared.isWindowVisible {
                        self.hideToMenuBar()
                        return nil // Consume event, don't quit the app
                    }
                }
            }
            return event
        }
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideToMenuBar()
        return false // Do not destroy window
    }
    
    public func hideToMenuBar() {
        mainWindow?.orderOut(nil)
        AppState.shared.setWindowVisible(false)
        // Hide dock icon completely so it lives strictly in the menu bar
        NSApp.setActivationPolicy(.accessory)
    }
    
    public func showMainWindow() {
        // Show dock icon and restore window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
        AppState.shared.setWindowVisible(true)
    }
}

public struct WindowAccessor: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                WindowCloseHandler.shared.register(window: window)
            }
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {}
}
