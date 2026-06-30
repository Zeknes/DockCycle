# DockCycle 安装与卸载指南

## 前置要求

- macOS 12.0+ (arm64)
- Xcode Command Line Tools（`xcode-select --install`）
- Swift 5.7+（随 Command Line Tools 附带）

## 安装

```bash
cd ~/Projects/DockCycle
make install
```

`make install` 会依次执行：

1. **停止旧实例** — `pkill` 终止运行中的 DockCycle，`launchctl bootout` 注销旧 LaunchAgent
2. **清理项目目录残留** — 删除 `./DockCycle.app`（构建产物），避免启动台/Spotlight 索引到两个 bundle
3. **构建** — `swift build -c release` + 打包 `.app` + codesign
4. **安装** — 复制到 `~/Applications/DockCycle.app`
5. **再次清理** — 删除项目目录的构建产物，确保磁盘上只有 `~/Applications/` 一个 bundle

安装后启动：

```bash
open ~/Applications/DockCycle.app
```

> 首次启动需授权两道权限（缺一不可，否则点击 Dock 无反应）：
> 1. **系统设置 → 隐私与安全性 → 辅助功能** → 开启 DockCycle
> 2. **系统设置 → 隐私与安全性 → 输入监听** → 开启 DockCycle
>
> 菜单栏 ● 图标 →「授权辅助功能…」可跳转辅助功能页。
> 若 EventTap 创建失败，app 会弹窗提示并引导到「输入监听」设置页。

## 验证安装成功

```bash
# 应输出 1（单进程）
ps aux | grep -i dockcycle | grep -v grep | wc -l

# 应只有 ~/Applications/DockCycle.app
mdfind "kMDItemCFBundleIdentifier == 'com.hewenpeng.dockcycle'"
```

菜单栏应出现一个 ● 图标，点击可看到菜单。

## 开机自启

菜单栏 ● 图标 →「开机自启」勾选即可。原理：写入 `~/Library/LaunchAgents/com.hewenpeng.dockcycle.plist`，`RunAtLoad=true` 在登录时自动启动。

取消勾选则注销 LaunchAgent 并删除 plist。

> **不会产生双实例**：app 启动时检测同名进程，已有实例运行则立即退出。

## 卸载

```bash
cd ~/Projects/DockCycle
make uninstall
```

`make uninstall` 会：

1. `pkill` 终止进程 + `launchctl bootout` 注销 LaunchAgent
2. 删除 LaunchAgent plist
3. 删除 `~/Applications/DockCycle.app` 和项目目录的构建产物
4. 重置启动台索引（`ResetLaunchPad`），清除残留图标

验证卸载干净：

```bash
# 均应无输出
ps aux | grep -i dockcycle | grep -v grep
ls ~/Applications/DockCycle.app 2>/dev/null
ls ~/Library/LaunchAgents/com.hewenpeng.dockcycle.plist 2>/dev/null
launchctl list | grep dockcycle
```

## 故障排查

### 启动台出现两个 DockCycle 图标

**原因**：磁盘上存在两个 `DockCycle.app`（通常是项目目录的构建产物 + 安装版）。

**解决**：

```bash
make uninstall
make install
```

### 顶栏出现两个图标

**原因**：两个实例同时运行（旧版本或项目目录 app 被误启动）。

**解决**：升级到新版（含单例检测）后不会发生。若已发生：

```bash
pkill -x DockCycle
open ~/Applications/DockCycle.app
```

### 辅助功能授权失效

**原因**：重新编译后二进制 cdhash 变化，需重新授权。

**解决**：菜单栏 ● →「授权辅助功能…」，或系统设置里重新打开开关。

### 点击 Dock 无反应（事件监听未启动）

**原因**：macOS 12+ 的 `CGEventTap` 需要两道权限，缺一不可：
1. **辅助功能**（Accessibility）— 用于 AXUIElement 查询
2. **输入监听**（Input Monitoring）— 用于 CGEventTap 创建

**诊断**：菜单栏 ● →「查看日志」，搜索"事件监听已启动"。若无此日志，说明 EventTap 创建失败。

**解决**：
1. 系统设置 → 隐私与安全性 → **辅助功能** → 开启 DockCycle
2. 系统设置 → 隐私与安全性 → **输入监听** → 开启 DockCycle
3. 重启 DockCycle：`pkill -x DockCycle && open ~/Applications/DockCycle.app`

> 新版会在 EventTap 创建失败时弹出提示框，引导前往「输入监听」设置页。

## 开发命令

```bash
make build      # 仅构建，不安装
make run        # 构建并运行（项目目录，开发用）
make clean      # 清理构建产物
make icon       # 重新生成 app 图标
```

> 开发时用 `make run` 启动的是项目目录的 bundle，与安装版（`~/Applications/`）是两个不同路径。
> 测试完毕后用 `make install` 安装，会自动清理项目目录的构建产物。
