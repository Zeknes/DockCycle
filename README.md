# mac-dockcycle

点击 Dock 当前前台 App 图标时，在该应用的多个窗口之间循环切换。

**Swift 原生菜单栏应用** —— 用 Accessibility API 直接切换窗口，不依赖模拟系统快捷键。

## 功能

- 点击 Dock 当前前台 App 图标 → 在该应用的多个窗口间循环切换
- 菜单栏图标实时显示运行状态（● 绿色=启用，○ 灰色=暂停）
- 菜单栏菜单：
  - 启用 / 暂停
  - 开机自启（一键开关，自动写入 LaunchAgent）
  - 授权辅助功能（触发系统授权弹窗）
  - 查看日志（打开 Console.app）
  - 关于
  - 退出（Cmd+Q）

## 运行环境

- macOS 12.0+ (arm64)
- Xcode Command Line Tools（开发用，需 `swift build`）

## 安装

```bash
cd swift
make install
```

安装到 `~/Applications/DockCycle.app` 并启动。

## 授权辅助功能（首次必做）

1. 双击 `~/Applications/DockCycle.app`，或 `make run`
2. 系统设置 → 隐私与安全性 → 辅助功能
3. 找到 **DockCycle**，打开开关
4. 或点菜单栏 ● 图标 →「授权辅助功能…」

> Swift 编译确定性：相同源码编译出的二进制 cdhash 一致，授权一次后只要不改源码重新编译，永久有效。

## 开发者构建

```bash
cd swift
make build    # 构建 DockCycle.app
make run      # 构建并启动
make install  # 构建并安装到 ~/Applications
make clean    # 清理构建产物
```

源码在 `swift/Sources/DockCycle/`：
- `main.swift` — 应用入口
- `AppDelegate.swift` — 菜单栏 UI + Dock 点击判断
- `EventTapMonitor.swift` — CGEventTap 事件监听
- `ShortcutSimulator.swift` — Accessibility API 切换窗口

## 原理

点击 Dock 图标时，通过 CGEventTap 拦截鼠标事件，用 Accessibility API 判断点击的是否为当前前台应用的 Dock 图标。若是，则获取该应用的所有窗口，循环激活下一个窗口（不依赖模拟 Cmd+~，兼容任何系统快捷键设置）。

## 日志

日志通过 `NSLog` 写入 macOS 统一日志系统。查看方式：

- 菜单栏 →「查看日志」（打开 Console.app，搜索 DockCycle）
- 命令行：`log show --predicate 'processImagePath contains "DockCycle"' --last 1h`

## 卸载

1. 菜单栏点击 ● → 退出 DockCycle（Cmd+Q）
2. 若开启过开机自启，先在菜单里取消勾选
3. 删除文件：
   ```bash
   rm -rf ~/Applications/DockCycle.app
   rm -f ~/Library/LaunchAgents/com.hewenpeng.dockcycle.plist
   ```

## 发布说明

- 由于需全局事件监听，本项目不适合 Mac App Store 沙箱
- 推荐独立分发并完成开发者公证
