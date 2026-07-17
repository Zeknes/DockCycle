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

    // AXWindows 按 z-order 排列（最前 → 最后），窗口被提升后会移到下标 0。
    // 所以不能按「焦点窗口的下标 + 1」切换——那样下标 1 永远是上一个前台窗口，
    // 3+ 个窗口时只会在最近两个之间来回弹。
    // 正确做法：每次把最底层（列表末尾）的窗口提到最前，
    // [A,B,C] → 提 C → [C,A,B] → 提 B → [B,C,A] → 提 A，天然遍历所有窗口。
    let targetWindow = windows[windows.count - 1]

    // 提升目标窗口到前台
    app.activate(options: [.activateAllWindows])
    // kAXRaiseAttribute = "AXRaise"
    AXUIElementSetAttributeValue(targetWindow, "AXRaise" as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

    NSLog("[DockCycle] 已把最底层窗口提到最前")
}
