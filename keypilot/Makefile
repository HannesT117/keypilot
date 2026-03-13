SOURCES = $(wildcard Sources/KeyPilot/*.swift)
APP_NAME = KeyPilot
APP_BUNDLE = $(APP_NAME).app
SDK = $(shell xcrun --show-sdk-path)
TARGET = $(shell uname -m)-apple-macosx13.0

.PHONY: build bundle sign run clean

build: $(APP_NAME)

$(APP_NAME): $(SOURCES)
	swiftc \
		-target $(TARGET) \
		-sdk $(SDK) \
		-framework Cocoa \
		-framework Carbon \
		-framework ApplicationServices \
		-framework SwiftUI \
		-o $(APP_NAME) \
		$(SOURCES)

# bundle: assemble the .app without signing (preserves Accessibility permissions across rebuilds)
bundle: build
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Info.plist $(APP_BUNDLE)/Contents/
	cp Resources/KeyPilot.icns $(APP_BUNDLE)/Contents/Resources/

# sign: apply ad-hoc signature + entitlements (run once after granting Accessibility permission,
#        or use a real Developer ID for distribution — re-signing invalidates the permission grant)
sign: bundle
	codesign --force --deep --sign - \
		--entitlements KeyPilot.entitlements \
		$(APP_BUNDLE)

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf $(APP_NAME) $(APP_BUNDLE)
