import Foundation
import Carbon.HIToolbox
import CoreGraphics

enum RecordingMode: String {
    case transcribe
    case translate
    case qa
}

@Observable
final class KeyListener {
    private(set) var isRecording = false
    private(set) var currentMode: RecordingMode = .transcribe

    var onRecordingStart: ((RecordingMode) -> Void)?
    var onRecordingStop: (() -> Void)?
    var onModeChange: ((RecordingMode) -> Void)?
    var onCancel: (() -> Void)?
    var onAltPressed: (() -> Void)?
    var onAltReleasedWithoutRecording: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var altPressed = false
    private var shiftPressed = false
    private var spacePressed = false
    private var altTimer: DispatchWorkItem?
    private let comboDelay: TimeInterval = 0.25

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let listener = Unmanaged<KeyListener>.fromOpaque(refcon).takeUnretainedValue()
                return listener.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("[KeyListener] Failed to create event tap. Check Accessibility permissions.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[KeyListener] Event tap started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        altTimer?.cancel()
        altTimer = nil
    }

    func pause() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    func resume() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    // MARK: - Event Handling

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle tap disabled (system can disable it under load)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if type == .flagsChanged {
            handleFlagsChanged(keyCode: keyCode, flags: flags, event: event)
        } else if type == .keyDown {
            handleKeyDown(keyCode: keyCode, event: event)
        } else if type == .keyUp {
            handleKeyUp(keyCode: keyCode, event: event)
        }

        // Only suppress Space when Option is held AND we're recording or about to record
        if altPressed && (isRecording || altTimer != nil) && keyCode == kVK_Space {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleFlagsChanged(keyCode: Int64, flags: CGEventFlags, event: CGEvent) {
        let isOptionDown = flags.contains(.maskAlternate)
        let isShiftDown = flags.contains(.maskShift)

        if isOptionDown && !altPressed {
            // Option pressed — detect selected text immediately (before 250ms timer)
            altPressed = true
            DispatchQueue.main.async { [weak self] in
                self?.onAltPressed?()
            }
            startAltTimer()
        } else if !isOptionDown && altPressed {
            // Option released
            altPressed = false
            altTimer?.cancel()
            altTimer = nil

            if isRecording {
                stopRecording()
            } else {
                // Alt released before combo delay fired — notify to clean up early recording
                DispatchQueue.main.async { [weak self] in
                    self?.onAltReleasedWithoutRecording?()
                }
            }
        }

        // Track shift for mode changes
        if isShiftDown && !shiftPressed {
            shiftPressed = true
            if altPressed {
                handleComboDetected(.translate)
            }
        } else if !isShiftDown && shiftPressed {
            shiftPressed = false
        }
    }

    private func handleKeyDown(keyCode: Int64, event: CGEvent) {
        if keyCode == kVK_Space && altPressed {
            if !spacePressed {
                spacePressed = true
                handleComboDetected(.qa)
            }
        } else if keyCode == kVK_Escape {
            if isRecording {
                isRecording = false
                altTimer?.cancel()
                altTimer = nil
                DispatchQueue.main.async { [weak self] in
                    self?.onCancel?()
                }
            }
        }
    }

    private func handleKeyUp(keyCode: Int64, event: CGEvent) {
        if keyCode == kVK_Space {
            spacePressed = false
        }
    }

    // MARK: - Timer & Mode

    private func startAltTimer() {
        altTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.altPressed, !self.isRecording else { return }
            self.startRecording(mode: .transcribe)
        }
        altTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + comboDelay, execute: item)
    }

    private func handleComboDetected(_ mode: RecordingMode) {
        altTimer?.cancel()
        altTimer = nil

        if isRecording {
            // Upgrade mode
            if currentMode != mode {
                currentMode = mode
                DispatchQueue.main.async { [weak self] in
                    self?.onModeChange?(mode)
                }
            }
        } else {
            startRecording(mode: mode)
        }
    }

    private func startRecording(mode: RecordingMode) {
        guard !isRecording else { return }
        isRecording = true
        currentMode = mode
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingStart?(mode)
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingStop?()
        }
    }
}
