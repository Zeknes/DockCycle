import Cocoa

final class EventTapMonitor {
    var onLeftMouseDown: ((CGPoint) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// 权限缺失类型
    enum PermissionError {
        case accessibility  // 辅助功能未授权
        case inputMonitoring  // 输入监听未授权（CGEventTap 创建失败）
    }

    /// 启动事件监听。
    /// - Returns: nil 表示成功；否则返回缺失的权限类型。
    func start() -> PermissionError? {
        guard AXIsProcessTrusted() else { return .accessibility }
        stop()

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                    guard let refcon else { return Unmanaged.passRetained(event) }
                    let monitor = Unmanaged<EventTapMonitor>.fromOpaque(refcon)
                        .takeUnretainedValue()
                    return monitor.handle(type: type, event: event)
                },
                userInfo: refcon
            )
        else {
            // tapCreate 返回 nil：macOS 12+ 需要单独的"输入监听"权限
            return .inputMonitoring
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[DockCycle] 事件监听已启动")
        return nil
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    // MARK: - Private

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 系统禁用了 tap 时重新启用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .leftMouseDown else {
            return Unmanaged.passRetained(event)
        }

        let location = event.location
        DispatchQueue.main.async { [weak self] in
            self?.onLeftMouseDown?(location)
        }
        return Unmanaged.passRetained(event)
    }
}
