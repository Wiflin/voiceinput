import AppKit
import Carbon.HIToolbox
import QuartzCore

enum TriggerKey: Equatable {
    case option
}

final class GlobalHotkeyMonitor {
    private let onDown: (TriggerKey) -> Void
    private let onUp: (TriggerKey) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var optionDown = false
    private var activeTrigger: TriggerKey?
    private var optionPressTime: CFTimeInterval?
    private var lastShortOptionTapReleaseTime: CFTimeInterval?
    private let optionDoubleTapInterval: CFTimeInterval = 0.36
    private let optionSingleTapMaxDuration: CFTimeInterval = 0.24

    init(onDown: @escaping (TriggerKey) -> Void, onUp: @escaping (TriggerKey) -> Void) {
        self.onDown = onDown
        self.onUp = onUp
    }

    func start() -> Bool {
        let mask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == kVK_Option || keyCode == kVK_RightOption else {
                return Unmanaged.passUnretained(event)
            }

            let flags = event.flags
            let isOption = flags.contains(.maskAlternate)

            if isOption != optionDown {
                optionDown = isOption
                updateOptionTrigger(isDown: isOption)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func updateOptionTrigger(isDown: Bool) {
        let now = CACurrentMediaTime()

        if isDown {
            guard activeTrigger == nil else { return }
            optionPressTime = now

            if let lastShortOptionTapReleaseTime, now - lastShortOptionTapReleaseTime <= optionDoubleTapInterval {
                activeTrigger = .option
                self.lastShortOptionTapReleaseTime = nil
                onDown(.option)
            }
        } else {
            if activeTrigger == .option {
                activeTrigger = nil
                optionPressTime = nil
                lastShortOptionTapReleaseTime = nil
                onUp(.option)
            } else {
                if let optionPressTime, now - optionPressTime <= optionSingleTapMaxDuration {
                    lastShortOptionTapReleaseTime = now
                } else {
                    lastShortOptionTapReleaseTime = nil
                }
                optionPressTime = nil
            }
        }
    }
}
