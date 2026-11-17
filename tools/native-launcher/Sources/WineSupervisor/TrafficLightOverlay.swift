import AppKit
import ApplicationServices
import CoreGraphics

final class TrafficLightOverlayController {
    private var window: NSWindow?
    private var timer: Timer?
    private var targetPID: pid_t?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        window?.orderOut(nil)
        window = nil
    }

    private func refresh() {
        guard let target = targetWindow() else {
            window?.orderOut(nil)
            return
        }
        targetPID = target.pid
        let frame = target.frame
        let overlayFrame = CGRect(x: frame.minX, y: frame.maxY - 34, width: 86, height: 34)
        let cocoaFrame = NSScreen.screens.first.map { screen in
            CGRect(x: overlayFrame.minX, y: screen.frame.maxY - overlayFrame.maxY, width: overlayFrame.width, height: overlayFrame.height)
        } ?? overlayFrame

        if window == nil {
            let overlay = NSWindow(contentRect: cocoaFrame, styleMask: [.borderless], backing: .buffered, defer: false)
            overlay.isOpaque = false
            overlay.backgroundColor = .clear
            overlay.level = .floating
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            overlay.ignoresMouseEvents = false
            overlay.hasShadow = false
            overlay.contentView = TrafficLightView(controller: self)
            window = overlay
        }
        window?.setFrame(cocoaFrame, display: true)
        window?.orderFrontRegardless()
    }

    private func targetWindow() -> (pid: pid_t, frame: CGRect)? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for item in list {
            guard let owner = item[kCGWindowOwnerName as String] as? String,
                  let bounds = item[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"],
                  width > 600, height > 300,
                  let x = bounds["X"], let y = bounds["Y"],
                  let pidValue = item[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let ownerLower = owner.lowercased()
            guard ownerLower.contains("wine") || ownerLower.contains("steam") else { continue }
            return (pidValue.int32Value, CGRect(x: x, y: y, width: width, height: height))
        }
        return nil
    }

    fileprivate func closeTarget() {
        guard let targetPID else { return }
        let app = AXUIElementCreateApplication(targetPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], let first = windows.first else { return }
        var button: CFTypeRef?
        if AXUIElementCopyAttributeValue(first, kAXCloseButtonAttribute as CFString, &button) == .success,
           let closeButton = button {
            AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        }
    }

    fileprivate func minimizeTarget() { performWindowAction(kAXMinimizeButtonAttribute as String) }
    fileprivate func zoomTarget() { performWindowAction(kAXZoomButtonAttribute as String) }

    private func performWindowAction(_ attribute: String) {
        guard let targetPID else { return }
        let app = AXUIElementCreateApplication(targetPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], let first = windows.first else { return }
        var button: CFTypeRef?
        guard AXUIElementCopyAttributeValue(first, attribute as CFString, &button) == .success,
              let actionButton = button else { return }
        AXUIElementPerformAction(actionButton as! AXUIElement, kAXPressAction as CFString)
    }
}

private final class TrafficLightView: NSView {
    weak var controller: TrafficLightOverlayController?

    init(controller: TrafficLightOverlayController) {
        self.controller = controller
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addButton(color: .systemRed, x: 8, action: #selector(closePressed))
        addButton(color: .systemYellow, x: 31, action: #selector(minimizePressed))
        addButton(color: .systemGreen, x: 54, action: #selector(zoomPressed))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func addButton(color: NSColor, x: CGFloat, action: Selector) {
        let button = NSButton(frame: CGRect(x: x, y: 8, width: 16, height: 16))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.title = ""
        button.wantsLayer = true
        button.layer?.backgroundColor = color.cgColor
        button.layer?.cornerRadius = 8
        button.target = self
        button.action = action
        addSubview(button)
    }

    @objc private func closePressed() { controller?.closeTarget() }
    @objc private func minimizePressed() { controller?.minimizeTarget() }
    @objc private func zoomPressed() { controller?.zoomTarget() }
}
