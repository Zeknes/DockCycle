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
	cp -r $(APP_BUNDLE) $(INSTALL_DIR)/
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
