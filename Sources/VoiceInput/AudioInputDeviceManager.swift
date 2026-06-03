import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

struct AudioInputDevice: Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let isDefault: Bool
}

enum AudioInputDeviceManager {
    enum DeviceError: Error {
        case unavailable
        case audioUnitUnavailable
        case selectionFailed(OSStatus)
    }

    static func availableInputDevices() -> [AudioInputDevice] {
        let defaultID = defaultInputDeviceID()

        return allDeviceIDs()
            .filter(hasInputStreams)
            .compactMap { id in
                guard
                    let uid = stringProperty(id, selector: kAudioDevicePropertyDeviceUID),
                    let name = stringProperty(id, selector: kAudioObjectPropertyName)
                else { return nil }

                return AudioInputDevice(
                    id: id,
                    uid: uid,
                    name: name,
                    isDefault: id == defaultID
                )
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    static func selectInputDevice(uid: String?, for inputNode: AVAudioInputNode) throws {
        guard let uid, !uid.isEmpty else { return }
        guard let deviceID = availableInputDevices().first(where: { $0.uid == uid })?.id else {
            throw DeviceError.unavailable
        }
        guard let audioUnit = inputNode.audioUnit else {
            throw DeviceError.audioUnitUnavailable
        }

        var selectedDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw DeviceError.selectionFailed(status)
        }
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
            return []
        }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceIDs
        )

        return status == noErr ? deviceIDs : []
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return false
        }

        return size >= UInt32(MemoryLayout<AudioStreamID>.size)
    }

    private static func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)

        return status == noErr ? value?.takeUnretainedValue() as String? : nil
    }
}
