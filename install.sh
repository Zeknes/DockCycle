#!/bin/bash

# Define paths
APP_NAME="Click2Circle.app"
PLIST_NAME="com.hewenpeng.click2circle.plist"
INSTALL_DIR="$HOME/Applications"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

# Ensure ~/Applications exists
mkdir -p "$INSTALL_DIR"

# 1. Stop existing service
echo "Stopping existing service..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null
pkill -f "Click2Circle" 2>/dev/null
pkill -f "main" 2>/dev/null

# 2. Install App to ~/Applications
echo "Installing App to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$APP_NAME" "$INSTALL_DIR/"

# 3. Update plist with new path
echo "Updating configuration..."
# Create a temporary plist with the correct path
cat > "$PLIST_NAME.tmp" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hewenpeng.click2circle</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$APP_NAME/Contents/MacOS/main</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/click2circle.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/click2circle.err</string>
</dict>
</plist>
EOF

mv "$PLIST_NAME.tmp" "$PLIST_NAME"

# 4. Install Launch Agent
echo "Installing launch agent..."
cp "$PLIST_NAME" "$LAUNCH_AGENTS_DIR/"

# 5. Load the plist
echo "Starting service..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "----------------------------------------------------------------"
echo "Installation complete!"
echo "App location: $INSTALL_DIR/$APP_NAME"
echo ""
echo "IMPORTANT: You MUST grant Accessibility permissions for the NEW app location."
echo "1. Go to System Settings -> Privacy & Security -> Accessibility"
echo "2. If 'Click2Circle' or 'main' is already there, REMOVE it (-)."
echo "3. Click '+' and select: $INSTALL_DIR/$APP_NAME"
echo "----------------------------------------------------------------"
