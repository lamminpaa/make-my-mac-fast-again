.PHONY: build run clean test bundle dmg inject-version

APP_NAME = MakeMyMacFastAgain
BUILD_DIR = .build
BUNDLE_DIR = $(BUILD_DIR)/$(APP_NAME).app
VERSION = $(shell cat VERSION)
BUILD_NUMBER = $(shell git rev-list --count HEAD 2>/dev/null || echo "0")
GIT_HASH = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION_FILE = Sources/MakeMyMacFastAgain/App/AppVersion.swift

inject-version:
	@echo "Injecting version $(VERSION) build $(BUILD_NUMBER) hash $(GIT_HASH)"
	@echo 'import Foundation' > $(VERSION_FILE)
	@echo '' >> $(VERSION_FILE)
	@echo 'enum AppVersion {' >> $(VERSION_FILE)
	@echo '    static let version = "$(VERSION)"' >> $(VERSION_FILE)
	@echo '    static let build = "$(BUILD_NUMBER)"' >> $(VERSION_FILE)
	@echo '    static let gitHash = "$(GIT_HASH)"' >> $(VERSION_FILE)
	@echo '' >> $(VERSION_FILE)
	@echo '    static var fullVersion: String {' >> $(VERSION_FILE)
	@echo '        if gitHash != "unknown" {' >> $(VERSION_FILE)
	@echo '            return "\(version) (\(build)) [\(gitHash)]"' >> $(VERSION_FILE)
	@echo '        }' >> $(VERSION_FILE)
	@echo '        return "\(version) (\(build))"' >> $(VERSION_FILE)
	@echo '    }' >> $(VERSION_FILE)
	@echo '' >> $(VERSION_FILE)
	@echo '    static var shortVersion: String {' >> $(VERSION_FILE)
	@echo '        "\(version) (\(build))"' >> $(VERSION_FILE)
	@echo '    }' >> $(VERSION_FILE)
	@echo '}' >> $(VERSION_FILE)

build:
	swift build

run: build
	$(BUILD_DIR)/debug/$(APP_NAME)

release: inject-version
	swift build -c release

test:
	swift test

clean:
	swift package clean
	rm -rf $(BUNDLE_DIR)
	rm -f *.dmg

bundle: release
	@echo "Creating app bundle..."
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	mkdir -p $(BUNDLE_DIR)/Contents/Resources
	cp $(BUILD_DIR)/release/$(APP_NAME) $(BUNDLE_DIR)/Contents/MacOS/
	sed 's/__VERSION__/$(VERSION)/g; s/__BUILD_NUMBER__/$(BUILD_NUMBER)/g' Resources/Info.plist > $(BUNDLE_DIR)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE_DIR)/Contents/Resources/
	@echo "Bundle created at $(BUNDLE_DIR) (v$(VERSION) build $(BUILD_NUMBER))"

dmg: bundle
	@echo "Creating DMG..."
	scripts/create-dmg.sh $(BUNDLE_DIR) $(VERSION)
