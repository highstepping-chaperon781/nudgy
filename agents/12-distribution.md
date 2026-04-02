# Agent 12: Build & Distribution

## Objective
Package Nudge as a signed, notarized macOS .app bundle,
create a DMG for distribution, and prepare a Homebrew cask formula.

## Scope
- .app bundle creation with Info.plist
- Code signing with Developer ID
- Notarization with Apple
- DMG creation with drag-to-Applications
- Homebrew cask formula
- Sparkle auto-update integration
- GitHub Release workflow
- Makefile for common tasks

## Dependencies
- ALL agents 01-10 (the code to package)
- Agent 11 (tests must pass before packaging)

## Files to Create

### Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Nudge</string>
    <key>CFBundleDisplayName</key>
    <string>Nudge</string>
    <key>CFBundleIdentifier</key>
    <string>com.nudge.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>Nudge</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026. All rights reserved.</string>
</dict>
</plist>
```

Key: `LSUIElement = true` — app does not appear in Dock.

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### Makefile

```makefile
.PHONY: build test clean package sign notarize dmg release

SCHEME = Nudge
BUILD_DIR = .build/release
APP_NAME = Nudge
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
DMG_NAME = $(APP_NAME)-$(VERSION).dmg
VERSION = $(shell swift package describe --type json | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "0.1.0")

# Build release binary
build:
	swift build -c release

# Run all tests
test:
	swift test --sanitize=thread
	swift test --filter PerformanceTests

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)/*.app $(BUILD_DIR)/*.dmg

# Create .app bundle from Swift binary
package: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/Nudge $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	# Copy resources (icon, sounds) if they exist
	-cp -r Sources/Nudge/Resources/* $(APP_BUNDLE)/Contents/Resources/ 2>/dev/null

# Code sign (requires SIGNING_IDENTITY env var)
sign: package
	codesign --deep --force --options runtime \
		--sign "$(SIGNING_IDENTITY)" \
		--entitlements Entitlements.plist \
		$(APP_BUNDLE)
	codesign --verify --verbose $(APP_BUNDLE)

# Notarize with Apple (requires APPLE_ID, TEAM_ID, APP_PASSWORD env vars)
notarize: sign
	ditto -c -k --keepParent $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME).zip
	xcrun notarytool submit $(BUILD_DIR)/$(APP_NAME).zip \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait
	xcrun stapler staple $(APP_BUNDLE)

# Create DMG with drag-to-Applications
dmg: sign
	mkdir -p $(BUILD_DIR)/dmg-staging
	cp -r $(APP_BUNDLE) $(BUILD_DIR)/dmg-staging/
	ln -sf /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDBZ \
		$(BUILD_DIR)/$(DMG_NAME)
	rm -rf $(BUILD_DIR)/dmg-staging
	# Sign the DMG too
	codesign --sign "$(SIGNING_IDENTITY)" $(BUILD_DIR)/$(DMG_NAME)

# Full release pipeline
release: test notarize dmg
	@echo "Release $(VERSION) ready at $(BUILD_DIR)/$(DMG_NAME)"
```

### Homebrew Cask Formula

```ruby
# nudge.rb
cask "nudge" do
  version "0.1.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/OWNER/nudge/releases/download/" \
      "v#{version}/Nudge-#{version}.dmg"
  name "Nudge"
  desc "Floating notification companion for AI coding agents"
  homepage "https://github.com/OWNER/nudge"

  depends_on macos: ">= :ventura"

  app "Nudge.app"

  postflight do
    # Optionally install hooks on first install
    system_command "#{appdir}/Nudge.app/Contents/MacOS/Nudge",
                   args: ["--install-hooks"],
                   print_stderr: false
  end

  uninstall_preflight do
    # Uninstall hooks before removing app
    system_command "#{appdir}/Nudge.app/Contents/MacOS/Nudge",
                   args: ["--uninstall-hooks"],
                   print_stderr: false
  end

  zap trash: [
    "~/Library/Preferences/com.nudge.app.plist",
    "~/.claude/settings.json.backup.*",
  ]
end
```

### GitHub Actions Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: swift build -c release

      - name: Test
        run: swift test

      - name: Package
        run: make package

      - name: Sign
        env:
          SIGNING_IDENTITY: ${{ secrets.SIGNING_IDENTITY }}
        run: make sign

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
          APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
        run: make notarize

      - name: Create DMG
        run: make dmg

      - name: Upload Release
        uses: softprops/action-gh-release@v2
        with:
          files: .build/release/Nudge-*.dmg
```

### Sparkle Auto-Update (Future)

Add to Package.swift:
```swift
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
```

Host `appcast.xml` at a known URL:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Nudge Updates</title>
    <item>
      <title>Version 0.1.0</title>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>0.1.0</sparkle:shortVersionString>
      <enclosure url="https://...dmg"
          sparkle:edSignature="..."
          length="..."
          type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

## Tests to Write

```
testAppBundleHasCorrectPlistValues
    → Read Info.plist → verify bundle ID, LSUIElement, min OS version

testEntitlementsIncludeNetworkServer
    → Verify codesign --display shows network.server entitlement

testBinaryRunsWithoutCrash
    → Launch the binary, wait 2 seconds, verify it's running

testBinaryAcceptsInstallHooksFlag
    → Run with --install-hooks → hooks installed (temp dir)

testBinaryAcceptsUninstallHooksFlag
    → Run with --uninstall-hooks → hooks removed (temp dir)

testDMGMountsCorrectly
    → Mount DMG, verify Nudge.app and Applications symlink exist
```

## Self-Verification

1. `make build` succeeds
2. `make test` passes all tests
3. `make package` creates a valid .app bundle
4. .app bundle launches without crash
5. .app bundle has no Dock icon (LSUIElement)
6. `make sign` produces a valid signature (if signing identity available)
7. DMG mounts and contains the app + Applications symlink

## Size Targets
- Binary: < 5MB
- .app bundle: < 15MB (including resources)
- DMG: < 10MB (compressed)
