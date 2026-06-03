import AppKit
import AVFoundation
import Speech

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private var statusItem: NSStatusItem!
    private var controller: DictationController!
    private var settingsWindowController: SettingsWindowController?
    private weak var microphoneMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = DictationController(settings: settings)
        setupStatusItem()
        requestRuntimePermissions()
        controller.startMonitoringHotkeys()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceInput")
            button.toolTip = "VoiceInput"
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let hintItem = NSMenuItem(title: "Double-tap and hold Option to dictate", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)
        menu.addItem(.separator())

        let languageMenu = NSMenu()
        for option in LanguageOption.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = settings.language == option ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let microphoneMenu = NSMenu()
        microphoneMenu.delegate = self
        self.microphoneMenu = microphoneMenu
        populateMicrophoneMenu(microphoneMenu)

        let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
        microphoneItem.submenu = microphoneMenu
        menu.addItem(microphoneItem)

        let llmMenu = NSMenu()
        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = settings.llmEnabled ? .on : .off
        llmMenu.addItem(enabledItem)
        llmMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(showLLMSettings), keyEquivalent: ","))
        llmMenu.items.last?.target = self

        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func populateMicrophoneMenu(_ microphoneMenu: NSMenu) {
        microphoneMenu.removeAllItems()

        let defaultMicrophoneItem = NSMenuItem(title: "System Default", action: #selector(selectInputDevice(_:)), keyEquivalent: "")
        defaultMicrophoneItem.target = self
        defaultMicrophoneItem.representedObject = ""
        defaultMicrophoneItem.state = settings.inputDeviceUID == nil ? .on : .off
        microphoneMenu.addItem(defaultMicrophoneItem)

        let devices = AudioInputDeviceManager.availableInputDevices()
        if devices.isEmpty {
            let emptyItem = NSMenuItem(title: "No input devices found", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            microphoneMenu.addItem(.separator())
            microphoneMenu.addItem(emptyItem)
        } else {
            microphoneMenu.addItem(.separator())
            for device in devices {
                let title = device.isDefault ? "\(device.name) (Default)" : device.name
                let item = NSMenuItem(title: title, action: #selector(selectInputDevice(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device.uid
                item.state = settings.inputDeviceUID == device.uid ? .on : .off
                microphoneMenu.addItem(item)
            }
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let option = LanguageOption(rawValue: rawValue)
        else { return }

        settings.language = option
        controller.languageDidChange()
        rebuildMenu()
    }

    @objc private func selectInputDevice(_ sender: NSMenuItem) {
        let uid = sender.representedObject as? String ?? ""
        settings.inputDeviceUID = uid.isEmpty ? nil : uid
        rebuildMenu()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        settings.llmEnabled.toggle()
        rebuildMenu()
    }

    @objc private func showLLMSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func requestRuntimePermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }

        let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === microphoneMenu else { return }
        populateMicrophoneMenu(menu)
    }
}
