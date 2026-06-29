import Cocoa
import ApplicationServices

/// 切换指定应用的不同窗口（循环到下一个窗口）
func cycleWindows(of appName: String) {
    NSLog("[DockCycle] 切换窗口: \(appName)")

    // 找到目标应用
    guard let app = NSWorkspace.shared.runningApplications.first(where: {
        ($0.localizedName == appName) || ($0.localizedName?.contains(appName) ?? false) || (appName.contains($0.localizedName ?? ""))
    }) else {
        NSLog("[DockCycle] 未找到应用: \(appName)")
        return
    }

    let pid = app.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)

    // 拿到应用的所有窗口
    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
    guard result == .success, let windows = windowsRef as? [AXUIElement], windows.count > 1 else {
        NSLog("[DockCycle] 应用 \(appName) 窗口数 <= 1，无需切换")
        return
    }

    NSLog("[DockCycle] \(appName) 有 \(windows.count) 个窗口")

    // 找到当前焦点窗口
    var focusedRef: CFTypeRef?
    AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef)
    let focusedWindow = focusedRef != nil ? (focusedRef as! AXUIElement) : nil

    // 找到焦点窗口在列表中的位置，切换到下一个
    var nextIndex = 0
    if let focused = focusedWindow {
        for (i, win) in windows.enumerated() {
            if CFEqual(win, focused) {
                nextIndex = (i + 1) % windows.count
                break
            }
        }
    }

    let targetWindow = windows[nextIndex]

    // 提升目标窗口到前台
    app.activate(options: [.activateAllWindows])
    // kAXRaiseAttribute = "AXRaise"
    AXUIElementSetAttributeValue(targetWindow, "AXRaise" as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

    NSLog("[DockCycle] 已切换到窗口 #\(nextIndex + 1)")
}
