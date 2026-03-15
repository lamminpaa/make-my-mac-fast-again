.PHONY: build run clean test bundle

APP_NAME = MakeMyMacFastAgain
BUILD_DIR = .build
BUNDLE_DIR = $(BUILD_DIR)/$(APP_NAME).app

build:
	swift build

run: build
	$(BUILD_DIR)/debug/$(APP_NAME)

release:
	swift build -c release

test:
	swift test

clean:
	swift package clean
	rm -rf $(BUNDLE_DIR)

bundle: release
	@echo "Creating app bundle..."
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	mkdir -p $(BUNDLE_DIR)/Contents/Resources
	cp $(BUILD_DIR)/release/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/
	cp Resources/Info.plist $(BUNDLE_DIR)/Contents/
	cp Resources/AppIcon.icns $(BUNDLE_DIR)/Contents/Resources/
	@echo "Bundle created at $(BUNDLE_DIR)"
