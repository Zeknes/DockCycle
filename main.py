import Quartz
import ApplicationServices  # ← 修改：使用 ApplicationServices 框架
from AppKit import NSWorkspace, NSRunningApplication, NSApplication, NSApplicationActivationPolicyAccessory
from Foundation import NSObject, NSLog
import Cocoa
import sys
import os

# 配置
KEY_CODE_TILDE = 50  # 波浪号键 ~
KEY_CODE_CMD = 55    # Command 键

def simulate_cycle_shortcut():
    """模拟按下 Command + ~"""
    print(">>> 触发切换窗口 (Command + ~)")
    src = Quartz.CGEventSourceCreate(Quartz.kCGEventSourceStateHIDSystemState)
   
    cmd_down = Quartz.CGEventCreateKeyboardEvent(src, 0x37, True)
    Quartz.CGEventSetFlags(cmd_down, Quartz.kCGEventFlagMaskCommand)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, cmd_down)
   
    tilde_down = Quartz.CGEventCreateKeyboardEvent(src, KEY_CODE_TILDE, True)
    Quartz.CGEventSetFlags(tilde_down, Quartz.kCGEventFlagMaskCommand)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, tilde_down)
   
    tilde_up = Quartz.CGEventCreateKeyboardEvent(src, KEY_CODE_TILDE, False)
    Quartz.CGEventSetFlags(tilde_up, Quartz.kCGEventFlagMaskCommand)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, tilde_up)
   
    cmd_up = Quartz.CGEventCreateKeyboardEvent(src, 0x37, False)
    Quartz.CGEventPost(Quartz.kCGHIDEventTap, cmd_up)

def get_element_info(element):
    """获取元素的 Role, Title 和 所属 App PID"""
    try:
        err, role = ApplicationServices.AXUIElementCopyAttributeValue(
            element, ApplicationServices.kAXRoleAttribute, None
        )
        err, title = ApplicationServices.AXUIElementCopyAttributeValue(
            element, ApplicationServices.kAXTitleAttribute, None
        )
        err, pid = ApplicationServices.AXUIElementGetPid(element, None)
        return role, title, pid
    except:
        return None, None, None

def get_app_name_by_pid(pid):
    """通过 PID 获取应用名称"""
    app = NSRunningApplication.runningApplicationWithProcessIdentifier_(pid)
    if app:
        return app.localizedName()
    return "Unknown"

def event_callback(proxy, type, event, refcon):
    # 过滤掉非左键按下的事件
    if type != Quartz.kCGEventLeftMouseDown:
        return event
    
    location = Quartz.CGEventGetLocation(event)
   
    # 获取鼠标下的 UI 元素
    system_wide = ApplicationServices.AXUIElementCreateSystemWide()  # ← 修改这里
    error, element = ApplicationServices.AXUIElementCopyElementAtPosition(  # ← 修改这里
        system_wide, location.x, location.y, None
    )
    if error != ApplicationServices.kAXErrorSuccess or not element:  # ← 修改这里
        return event
    
    role, title, pid = get_element_info(element)
    clicked_app_name = get_app_name_by_pid(pid)
    
    # 调试打印（取消注释可查看点击详情）
    # print(f"点击检测: App=[{clicked_app_name}], Role=[{role}], Title=[{title}]")
    
    # 判断是否点击了 Dock
    if clicked_app_name == "Dock":
        if title:
            target_app_name = title
           
            # 获取当前前台运行的 App
            front_app = NSWorkspace.sharedWorkspace().frontmostApplication()
            front_app_name = front_app.localizedName() if front_app else ""
           
            print(f"检测: 点击了 Dock 图标 [{target_app_name}] | 当前前台是 [{front_app_name}]")
            
            # 核心判断：如果点击的图标 == 当前前台 App（模糊匹配）
            if (target_app_name == front_app_name) or \
               (target_app_name in front_app_name) or \
               (front_app_name in target_app_name):
               
                simulate_cycle_shortcut()
                return None  # 拦截事件
            else:
                print("--- 不是同一个 App，放行 ---")
    return event

def main():
    # 强制设置应用为“后台应用”（不显示 Dock 图标）
    try:
        NSApplication.sharedApplication().setActivationPolicy_(NSApplicationActivationPolicyAccessory)
    except Exception as e:
        print(f"Warning: Failed to set activation policy: {e}")

    print("-" * 30)
    print("程序已启动 (v2.2) - 已切换到 ApplicationServices 框架")
    print("重要：请不要使用 sudo 运行！")
    print("请确保在 '系统设置 → 隐私与安全性 → 辅助功能' 中授予了终端权限。")
    print("-" * 30)
    
    # 创建事件监听
    mask = (1 << Quartz.kCGEventLeftMouseDown)
    tap = Quartz.CGEventTapCreate(
        Quartz.kCGHIDEventTap,
        Quartz.kCGHeadInsertEventTap,
        Quartz.kCGEventTapOptionDefault,
        mask,
        event_callback,
        None
    )
    if not tap:
        print("错误：无法创建事件监听。")
        print("1. 请检查权限是否开启。")
        print("2. 尝试从列表中删除终端，然后重新添加。")
        print("3. 确保没有使用 sudo。")
        sys.exit(1)
    
    run_loop_source = Quartz.CFMachPortCreateRunLoopSource(None, tap, 0)
    Quartz.CFRunLoopAddSource(
        Quartz.CFRunLoopGetCurrent(),
        run_loop_source,
        Quartz.kCFRunLoopDefaultMode
    )
    Quartz.CGEventTapEnable(tap, True)
   
    try:
        Quartz.CFRunLoopRun()
    except KeyboardInterrupt:
        print("\n程序已停止。")

if __name__ == "__main__":
    main()