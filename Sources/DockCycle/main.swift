import AppKit

// MARK: - Single instance guard
//
// DockCycle 是菜单栏应用，同时只能运行一个实例。
// 多实例会导致：顶栏出现多个图标、LaunchAgent 重复拉起、事件监听冲突。
// 检测到已有同名进程运行时，激活旧实例并退出新进程。

private func isAnotherInstanceRunning() -> Bool {
    let selfPID = ProcessInfo.processInfo.processIdentifier
    let selfPath = Bundle.main.bundlePath

    // NSWorkspace.runningApplications 按 bundle id 匹配，能覆盖所有实例
    let apps = NSWorkspace.shared.runningApplications.filter {
        $0.bundleIdentifier == Bundle.main.bundleIdentifier
    }
    for app in apps where app.processIdentifier != selfPID {
        // 路径不同也视为重复（防止项目目录的构建产物被误启动）
        return true
    }

    // 兜底：检测同名可执行进程（LaunchAgent 可能用不同路径拉起）
    // 仅当可执行名匹配且 PID 不同时判定为重复
    let execName = ProcessInfo.processInfo.processName
    if execName.isEmpty == false {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-axco", "pid,comm"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let count =
                    output
                    .split(separator: "\n")
                    .filter { $0.hasSuffix(execName) }
                    .count
                if count > 1 {
                    return true
                }
            }
        } catch {
            // ps 调用失败时不阻断启动，避免误杀
        }
    }

    _ = selfPath
    return false
}

if isAnotherInstanceRunning() {
    NSLog("[DockCycle] 检测到已有实例运行，退出当前进程")
    exit(0)
}

// MARK: - App launch

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
