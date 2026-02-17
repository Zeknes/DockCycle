import os
import shutil
import subprocess

def run(cmd):
    print(f"Running: {cmd}")
    subprocess.check_call(cmd, shell=True)

def patch_plist(app_path):
    plist_path = os.path.join(app_path, "Contents", "Info.plist")
    with open(plist_path, "r") as f:
        content = f.read()
    
    if "LSUIElement" in content:
        print("Info.plist already patched.")
        return

    # Simple insertion before </dict>
    patch = """    <key>LSUIElement</key>
    <true/>
    <key>CFBundleDisplayName</key>
    <string>Click2Circle</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewenpeng.click2circle</string>
    <key>CFBundleName</key>
    <string>Click2Circle</string>
"""
    # Remove existing keys if we want to replace them, but let's just append for simplicity or replace entire block if needed.
    # Actually, let's just rewrite it completely to be safe and clean.
    new_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Click2Circle</string>
    <key>CFBundleExecutable</key>
    <string>main</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewenpeng.click2circle</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Click2Circle</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
"""
    with open(plist_path, "w") as f:
        f.write(new_content)
    print("Info.plist patched.")

def main():
    # 1. Build
    print("Building with Nuitka...")
    # Clean previous build
    if os.path.exists("dist"):
        shutil.rmtree("dist")
    
    run("uv run nuitka --mode=app --output-dir=dist main.py")
    
    # 2. Rename and Move
    if os.path.exists("Click2Circle.app"):
        shutil.rmtree("Click2Circle.app")
    
    shutil.move("dist/main.app", "Click2Circle.app")
    
    # 3. Patch Info.plist
    patch_plist("Click2Circle.app")
    
    # 4. Touch to refresh cache
    run("touch Click2Circle.app")
    
    print("\nBuild complete: Click2Circle.app")
    print("Please replace your existing application with this new one.")

if __name__ == "__main__":
    main()
