mac-click2circle

功能
- 点击 Dock 当前前台 App 图标时，触发 Command + ~ 切换窗口
- 仅在 Dock 图标与当前前台 App 匹配时生效

运行环境
- macOS 12.1+ (arm64)

Release 安装（推荐）
1. 下载 Release 中的安装包
2. 解压后进入目录
3. 运行安装脚本
   - chmod +x install.sh
   - ./install.sh
4. 授权辅助功能
   - 系统设置 → 隐私与安全性 → 辅助功能
   - 删除旧条目后，重新添加 ~/Applications/Click2Circle.app

权限要求
- 系统设置 → 隐私与安全性 → 辅助功能
- 添加并勾选终端或应用本体 Click2Circle.app

开发者构建
1. 安装依赖
   - uv add pyobjc nuitka zstandard
2. 启动脚本
   - uv run python main.py
3. 构建可执行应用
   - uv run python build.py
4. 产物
   - Click2Circle.app

安装开机自启（用户登录后）
- Release 安装已包含此步骤

状态与日志
- 标准输出: /tmp/click2circle.log
- 错误输出: /tmp/click2circle.err
- 状态检查: ./check_status.sh

卸载
1. 停止服务
   - launchctl unload ~/Library/LaunchAgents/com.hewenpeng.click2circle.plist
2. 删除文件
   - rm -rf ~/Applications/Click2Circle.app
   - rm -f ~/Library/LaunchAgents/com.hewenpeng.click2circle.plist

发布说明
- 由于需全局事件监听，本项目不适合 Mac App Store 沙箱
- 推荐独立分发并完成开发者公证
