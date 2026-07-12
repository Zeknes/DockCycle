APP_NAME := DockCycle
APP_BUNDLE := $(APP_NAME).app
BUILD_DIR := $(shell swift build -c release --show-bin-path 2>/dev/null || echo .build/release)
INSTALL_DIR := $(HOME)/Applications
LAUNCH_AGENT_LABEL := com.hewenpeng.dockcycle
LAUNCH_AGENT_PATH := $(HOME)/Library/LaunchAgents/$(LAUNCH_AGENT_LABEL).plist

.PHONY: build clean install uninstall run icon pre-install
icon:
	@echo "Generating app icon..."
	swift gen_icon.swift

build: icon
	swift build -c release
	$(eval BUILD_DIR := $(shell swift build -c release --show-bin-path))
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign - $(APP_BUNDLE)
	@echo "\n✅ Built $(APP_BUNDLE)"

run: build
	open $(APP_BUNDLE)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

# 安装：先停旧实例 → 清理项目目录残留 → 构建 → 装到 ~/Applications
# 关键：清理项目目录的 DockCycle.app，避免启动台/Spotlight 索引到两个 bundle
install: pre-install build
	@echo "==> 安装到 $(INSTALL_DIR)/$(APP_BUNDLE)..."
	-@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	ditto $(APP_BUNDLE) $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "==> 就地重新签名（cp/ditto 后须重签，否则 TCC 认不出身份，反复弹授权框）..."
	codesign --force --deep --sign - $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "==> 清理项目目录构建产物（避免启动台索引到两个 bundle）..."
	-@rm -rf ./$(APP_BUNDLE)
	@echo "✅ Installed to $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "   启动: open $(INSTALL_DIR)/$(APP_BUNDLE)"

# 安装前置：停旧实例 + 清理项目目录残留 bundle（在 build 之前执行）
# 关键：清理项目目录的 DockCycle.app，避免启动台/Spotlight 索引到两个 bundle
pre-install:
	@echo "==> 停止运行中的实例..."
	-@pkill -x $(APP_NAME) 2>/dev/null || true
	-@launchctl bootout gui/$(shell id -u)/$(LAUNCH_AGENT_LABEL) 2>/dev/null || true
	@sleep 1
	@echo "==> 清理项目目录残留 bundle..."
	-@rm -rf ./$(APP_BUNDLE)

# 卸载：杀进程 → 删 LaunchAgent → 删 app → 重置启动台索引
uninstall:
	@echo "==> 停止进程..."
	-@pkill -x $(APP_NAME) 2>/dev/null || true
	-@launchctl bootout gui/$(shell id -u)/$(LAUNCH_AGENT_LABEL) 2>/dev/null || true
	-@rm -f $(LAUNCH_AGENT_PATH)
	@sleep 1
	@echo "==> 删除 app..."
	-@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	-@rm -rf ./$(APP_BUNDLE)
	@echo "==> 重置启动台索引（清除残留图标）..."
	@defaults write com.apple.dock ResetLaunchPad -bool true
	@killall Dock 2>/dev/null || true
	@echo "✅ Uninstalled"

# 重置 TCC 权限记录（重编译后 cdhash 变化，旧权限记录失效）
# macOS 按 bundle ID + cdhash 鉴权；源码改动、重新编译后 cdhash 变化，
# 导致 System Settings 显示已授权但实际鉴权失败。运行此命令清除旧记录，
# 然后重新启动 app 即可弹出授权框。
reset-tcc:
	@echo "==> 清除旧的 TCC 权限记录..."
	-@tccutil reset Accessibility $(LAUNCH_AGENT_LABEL) 2>/dev/null || true
	-@tccutil reset ListenEvent $(LAUNCH_AGENT_LABEL) 2>/dev/null || true
	@echo "✅ 已清除。重新启动 DockCycle，系统会重新弹出授权框。"
