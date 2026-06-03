APP_NAME := VoiceInput
BUNDLE_ID := com.local.voiceinput
CONFIG := release
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
EXECUTABLE := .build/$(CONFIG)/$(APP_NAME)

.PHONY: build run install clean

build:
	swift build -c $(CONFIG)
	swift Scripts/GenerateIcon.swift
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp "AppBundle/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	cp "AppBundle/VoiceInput.icns" "$(APP_BUNDLE)/Contents/Resources/VoiceInput.icns"
	codesign --force --deep --sign - "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

install: build
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	codesign --force --deep --sign - "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)"
