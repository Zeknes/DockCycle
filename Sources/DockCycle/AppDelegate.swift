import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let eventTap = EventTapMonitor()
    private var isEnabled = true
    private var enableMenuItem: NSMenuItem!
    private var autostartMenuItem: NSMenuItem!

    private let plistLabel = "com.hewenpeng.dockcycle"
    private let launchAgentPath =
        NSHomeDirectory() + "/Library/LaunchAgents/com.hewenpeng.dockcycle.plist"

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()

        eventTap.onLeftMouseDown = { [weak self] location in
            self?.handleClick(at: location)
        }

        // 启动时同时检查两项权限，避免输入监听被藏在辅助功能之后而漏掉
        requestMissingPermissions()
        if !eventTap.start() {
            NSLog("[DockCycle] 事件监听未启动：权限缺失")
        }
    }

    /// 启动时检查所需权限，缺哪项就弹哪项的系统授权框（两项独立，互不遮挡）
    private func requestMissingPermissions() {
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ]
            _ = AXIsProcessTrustedWithOptions(options)
        }
        // CGRequestListenEventAccess 会弹出系统原生「输入监听」授权框
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
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

        enableMenuItem = NSMenuItem(
            title: "✓ 已启用", action: #selector(toggleEnabled), keyEquivalent: "")
        enableMenuItem.target = self
        menu.addItem(enableMenuItem)

        menu.addItem(.separator())

        autostartMenuItem = NSMenuItem(
            title: "开机自启", action: #selector(toggleAutostart), keyEquivalent: "")
        autostartMenuItem.target = self
        refreshAutostartState()
        menu.addItem(autostartMenuItem)

        let authItem = NSMenuItem(
            title: "授权权限…", action: #selector(requestAccessibility), keyEquivalent: "")
        authItem.target = self
        menu.addItem(authItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "关于 DockCycle", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "退出 DockCycle", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        // 启用: 循环箭头；禁用: 禁止符号。模板模式，系统自动适配深色/浅色
        let name = isEnabled ? "arrow.triangle.2.circlepath" : "circle.slash"
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
        let err = AXUIElementCopyElementAtPosition(
            systemWide, Float(location.x), Float(location.y), &element)

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
            || targetAppName.contains(frontAppName)
        {
            cycleWindows(of: targetAppName)
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enableMenuItem.title = isEnabled ? "✓ 已启用" : "  已禁用"
        if isEnabled {
            requestMissingPermissions()
            _ = eventTap.start()
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

    /// 菜单「授权权限…」：检查两项权限，缺哪项显示对应按钮
    @objc private func requestAccessibility() {
        let axOK = AXIsProcessTrusted()
        let listenOK = CGPreflightListenEventAccess()

        if axOK && listenOK {
            let alert = NSAlert()
            alert.messageText = "权限已就绪"
            alert.informativeText = "辅助功能、输入监听均已授权，DockCycle 可正常工作。"
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "需要授权以下权限"
        alert.informativeText = """
            DockCycle 需要以下权限才能监听 Dock 点击：

            \(axOK ? "✅" : "❌") 辅助功能（Accessibility）
            \(listenOK ? "✅" : "❌") 输入监听（Input Monitoring）

            ⚠️ 若设置里已勾选但仍无效：先关掉再重新打开对应开关，
            或终端执行 make reset-tcc 后重启 app。
            """
        alert.alertStyle = .warning

        // 缺哪个权限就显示对应按钮，缺两个就两个都显示
        if !axOK { alert.addButton(withTitle: "去授权辅助功能") }
        if !listenOK { alert.addButton(withTitle: "去授权输入监听") }
        alert.addButton(withTitle: "取消")

        let bothMissing = !axOK && !listenOK

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            // 按钮0：缺辅助功能 → 辅助功能；否则 → 输入监听
            let anchor = !axOK ? "Privacy_Accessibility" : "Privacy_ListenEvent"
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
        case .alertSecondButtonReturn where bothMissing:
            // 按钮1（仅两项都缺时才是「去授权输入监听」，否则是取消）
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        default:
            break
        }
    }

    @objc private func showAbout() {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
        let alert = NSAlert()
        alert.messageText = "DockCycle"
        alert.informativeText =
            "点击 Dock 当前前台 App 图标时，在该应用的多个窗口之间循环切换\n（Accessibility API 直接切换，不依赖模拟系统快捷键）\n版本 \(version)"
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
        // 先从 launchd 注销，防止残留注册再次拉起进程
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["bootout", "gui/\(getuid())/\(plistLabel)"]
        try? task.run()
        task.waitUntilExit()

        if FileManager.default.fileExists(atPath: launchAgentPath) {
            try? FileManager.default.removeItem(atPath: launchAgentPath)
        }
        NSLog("[DockCycle] 已关闭开机自启")
    }

    private func refreshAutostartState() {
        autostartMenuItem.title = isAutostartEnabled() ? "✓ 开机自启" : "  开机自启"
    }
}
