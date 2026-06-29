import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let eventTap = EventTapMonitor()
    private var isEnabled = true
    private var enableMenuItem: NSMenuItem!
    private var autostartMenuItem: NSMenuItem!

    private let plistLabel = "com.hewenpeng.dockcycle"
    private let launchAgentPath = NSHomeDirectory() + "/Library/LaunchAgents/com.hewenpeng.dockcycle.plist"

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()

        eventTap.onLeftMouseDown = { [weak self] location in
            self?.handleClick(at: location)
        }

        if !eventTap.start() {
            NSLog("[DockCycle] 辅助功能权限未开启，事件监听未启动")
            requestAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTap.stop()
    }

    // MARK: - Status bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()

        let menu = NSMenu()

        enableMenuItem = NSMenuItem(title: "✓ 已启用", action: #selector(toggleEnabled), keyEquivalent: "")
        enableMenuItem.target = self
        menu.addItem(enableMenuItem)

        menu.addItem(.separator())

        autostartMenuItem = NSMenuItem(title: "开机自启", action: #selector(toggleAutostart), keyEquivalent: "")
        autostartMenuItem.target = self
        refreshAutostartState()
        menu.addItem(autostartMenuItem)

        let authItem = NSMenuItem(title: "授权辅助功能…", action: #selector(requestAccessibility), keyEquivalent: "")
        authItem.target = self
        menu.addItem(authItem)

        let logItem = NSMenuItem(title: "查看日志", action: #selector(showLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 DockCycle", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出 DockCycle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        // 启用: 实心圆点；禁用: 空心圆。模板模式，系统自动适配深色/浅色
        let name = isEnabled ? "circle.fill" : "circle"
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "DockCycle")?
            .withSymbolConfiguration(cfg)
        image?.isTemplate = true  // 模板图片：深色模式自动变白，浅色自动变黑
        button.image = image
        button.contentTintColor = nil  // 不用 tint，让系统模板色生效
        button.toolTip = isEnabled ? "DockCycle 运行中" : "DockCycle 已暂停"
    }

    // MARK: - Dock click handling

    private func handleClick(at location: CGPoint) {
        // 获取鼠标下的 UI 元素
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &element)

        guard err == .success, let element else { return }

        var roleRef: CFTypeRef?
        var titleRef: CFTypeRef?
        var pid: pid_t = 0

        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementGetPid(element, &pid)

        let title = titleRef as? String
        guard let runningApp = NSRunningApplication(processIdentifier: pid) else { return }
        let clickedAppName = runningApp.localizedName ?? "Unknown"

        guard clickedAppName == "Dock", let targetAppName = title else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontAppName = frontApp?.localizedName ?? ""

        NSLog("[DockCycle] 点击 Dock [\(targetAppName)] | 前台 [\(frontAppName)]")

        // 核心判断：点击的图标 == 当前前台 App（模糊匹配）
        if targetAppName == frontAppName
            || frontAppName.contains(targetAppName)
            || targetAppName.contains(frontAppName) {
            cycleWindows(of: targetAppName)
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enableMenuItem.title = isEnabled ? "✓ 已启用" : "  已禁用"
        if isEnabled {
            if !eventTap.start() {
                requestAccessibility()
            }
        } else {
            eventTap.stop()
        }
        updateStatusIcon()
    }

    @objc private func toggleAutostart() {
        if isAutostartEnabled() {
            disableAutostart()
        } else {
            enableAutostart()
        }
        refreshAutostartState()
    }

    @objc private func requestAccessibility() {
        // 触发系统授权弹窗
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        // 打开系统设置
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func showLog() {
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "DockCycle"
        alert.informativeText = "点击 Dock 当前前台 App 图标时，触发 Command + ~ 切换窗口\n版本 3.0"
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - Autostart

    private func isAutostartEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPath)
    }

    private func appExecutablePath() -> String {
        Bundle.main.bundlePath + "/Contents/MacOS/DockCycle"
    }

    private func enableAutostart() {
        let exe = appExecutablePath()
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(exe)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        let dir = (launchAgentPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? plist.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
        NSLog("[DockCycle] 已启用开机自启")
    }

    private func disableAutostart() {
        if FileManager.default.fileExists(atPath: launchAgentPath) {
            try? FileManager.default.removeItem(atPath: launchAgentPath)
        }
        NSLog("[DockCycle] 已关闭开机自启")
    }

    private func refreshAutostartState() {
        autostartMenuItem.title = isAutostartEnabled() ? "✓ 开机自启" : "  开机自启"
    }
}
