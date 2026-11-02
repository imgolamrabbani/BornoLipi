import Cocoa
import ApplicationServices

/// Universal system-wide keyboard hook for macOS (`CGEventTap`), equivalent to `WH_KEYBOARD_LL` in Windows `BijoyBayanno.exe`.
///
/// Key architecture improvements:
/// 1. **Magic UserData Tag (`0x424F524E`)**: Every synthetic `CGEvent` emitted by `GlobalKeyboardHook` is stamped with
///    `.eventSourceUserData = 0x424F524E`. When the event tap receives an event with this stamp, it passes it through
///    immediately (`LLKHF_INJECTED` equivalent). This completely eliminates asynchronous self-interception race conditions.
/// 2. **Live Accessibility Permission Watchdog**: Polls `AXIsProcessTrusted()` every 1.0 second and automatically attaches
///    the `CGEventTap` the moment the user toggles Accessibility permission in System Settings—no app restart required.
/// 3. **Mouse Click Buffer Reset**: Resets `BijoyTypingEngine.shared.resetBuffer()` whenever the user clicks the mouse
///    to reposition the cursor in Microsoft Word or any other app (matching `modMouse` in `BijoyBayanno.exe`).
public final class GlobalKeyboardHook {

    public static let shared = GlobalKeyboardHook()

    /// Magic tag (`'BORN'`) stamped onto synthetic `CGEvent`s so the event tap never re-intercepts its own output.
    private static let syntheticEventMagicTag: Int64 = 0x424F524E

    public private(set) var isHookActive: Bool = false {
        didSet {
            if oldValue != isHookActive {
                NotificationCenter.default.post(name: .bornoLipiHookStateDidChange, object: isHookActive)
            }
        }
    }

    public var onToggleKeymapRequested: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionWatchdogTimer: Timer?
    private var localKeyMonitor: Any?

    private init() {}

    // MARK: - Lifecycle

    public func start(promptIfNeeded: Bool = true) {
        if promptIfNeeded && !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        _ = tryInstallEventTap()
        installLocalFallbackMonitor()

        // Start a 1.0s watchdog timer so as soon as Accessibility permission is granted in System Settings,
        // the global CGEventTap attaches automatically without restarting BornoLipi.
        permissionWatchdogTimer?.invalidate()
        permissionWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.isHookActive {
                _ = self.tryInstallEventTap()
            } else if !AXIsProcessTrusted() {
                self.teardownEventTap()
            }
        }
    }

    public func requestAccessibilityPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    public func tryInstallEventTap() -> Bool {
        if let tap = eventTap, CGEvent.tapIsEnabled(tap: tap) {
            isHookActive = true
            return true
        }

        teardownEventTap()

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let hook = Unmanaged<GlobalKeyboardHook>.fromOpaque(refcon).takeUnretainedValue()
            return hook.handleEventTap(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            isHookActive = false
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isHookActive = true
        return true
    }

    private func teardownEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        isHookActive = false
    }

    /// Installs an `NSEvent.addLocalMonitorForEvents` fallback so typing inside BornoLipi's own Studio window
    /// and pressing `F1` / `Option+K` / `F12` inside BornoLipi works even before Accessibility permission is granted.
    private func installLocalFallbackMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // If the global CGEventTap is already active, it handles all apps (including BornoLipi) uniformly.
            if self.isHookActive {
                return event
            }
            if self.handleLocalNSEvent(event) {
                return nil
            }
            return event
        }
    }

    // MARK: - Event Tap Handler

    private func handleEventTap(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS temporarily disabled it due to timeout or user input
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Ignore synthetic events generated by BornoLipi itself (`0x424F524E`)
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMagicTag {
            return Unmanaged.passUnretained(event)
        }

        // Reset sequence buffer on mouse click (`modMouse` behavior in Bijoy 52)
        if type == .leftMouseDown || type == .rightMouseDown {
            BijoyTypingEngine.shared.resetBuffer()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasOpt = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)

        // 1. Global Shortcut: Show/Hide Keymap Layout (`F1` [keyCode 122] or `Option + K` [keyCode 40])
        if keyCode == 122 || (hasOpt && !hasCmd && !hasCtrl && keyCode == 40) {
            DispatchQueue.main.async { [weak self] in
                self?.onToggleKeymapRequested?()
            }
            return nil
        }

        // 2. Global Shortcut: Cycle Mode (`Ctrl + Option + B` [keyCode 11], `Cmd + Option + B` [keyCode 11], or `F12` [keyCode 111])
        //    Also supports `Ctrl + Option + V` [keyCode 9] to jump directly to Unicode (just like Windows Bijoy 52 `Ctrl+Alt+V`!)
        if keyCode == 111 || ((hasCtrl || hasCmd) && hasOpt && keyCode == 11) {
            DispatchQueue.main.async {
                BijoyTypingEngine.shared.cycleMode()
                NSSound.Tink?.play()
            }
            return nil
        }
        if (hasCtrl || hasCmd) && hasOpt && keyCode == 9 {
            DispatchQueue.main.async {
                let engine = BijoyTypingEngine.shared
                engine.currentMode = (engine.currentMode == .bijoyUnicode) ? .english : .bijoyUnicode
                NSSound.Tink?.play()
            }
            return nil
        }

        // 3. Pass through system shortcuts (`Cmd + ...`, `Ctrl + ...`, `Option + ...`)
        if hasCmd || hasCtrl || hasOpt {
            BijoyTypingEngine.shared.resetBuffer()
            return Unmanaged.passUnretained(event)
        }

        // 4. Run BijoyTypingEngine for the active mode
        let action = BijoyTypingEngine.shared.processKeyDown(macKeyCode: keyCode, isShiftPressed: hasShift)
        switch action {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .replace(let backspaces, let insertText):
            postSyntheticReplacement(backspaces: backspaces, insertText: insertText)
            return nil
        }
    }

    // MARK: - Synthetic Key Emitter (`SendInput` / `KEYEVENTF_UNICODE` Equivalent)

    private func postSyntheticReplacement(backspaces: Int, insertText: String) {
        guard let source = CGEventSource(stateID: .privateState) else { return }

        // 1. Emit Backspace key events (`macKeyCode = 51`) if replacing previous characters in a `<Juk>` rule
        if backspaces > 0 {
            for _ in 0..<backspaces {
                if let bsDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
                   let bsUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
                    bsDown.flags = []
                    bsUp.flags = []
                    bsDown.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMagicTag)
                    bsUp.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMagicTag)
                    bsDown.post(tap: .cghidEventTap)
                    bsUp.post(tap: .cghidEventTap)
                }
            }
        }

        // 2. Emit UTF-16 characters one code unit (or surrogate pair) at a time with clean flags
        //    (clearing `.maskShift` so Microsoft Word / Chrome / Notes never treat shifted Bijoy keys as Shift+Click or uppercase override)
        guard !insertText.isEmpty else { return }
        let utf16Units = Array(insertText.utf16)

        for i in 0..<utf16Units.count {
            var unit = utf16Units[i]
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyDown.flags = []
                keyUp.flags = []
                keyDown.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMagicTag)
                keyUp.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMagicTag)
                keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
                keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Local In-App Fallback (When Accessibility Permission Is Not Yet Enabled)

    private func handleLocalNSEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasCtrl = flags.contains(.control)
        let hasOpt = flags.contains(.option)
        let hasShift = flags.contains(.shift)
        let keyCode = event.keyCode

        if keyCode == 122 || (hasOpt && !hasCmd && !hasCtrl && keyCode == 40) {
            onToggleKeymapRequested?()
            return true
        }
        if keyCode == 111 || ((hasCtrl || hasCmd) && hasOpt && keyCode == 11) {
            BijoyTypingEngine.shared.cycleMode()
            return true
        }
        if hasCmd || hasCtrl || hasOpt {
            return false
        }
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        let action = BijoyTypingEngine.shared.processKeyDown(macKeyCode: keyCode, isShiftPressed: hasShift)
        switch action {
        case .passThrough:
            return false
        case .replace(let backspaces, let insertText):
            let sel = textView.selectedRange()
            let deleteStart = max(0, sel.location - backspaces)
            let replaceRange = NSRange(location: deleteStart, length: sel.length + (sel.location - deleteStart))
            if textView.shouldChangeText(in: replaceRange, replacementString: insertText) {
                textView.replaceCharacters(in: replaceRange, with: insertText)
                textView.didChangeText()
            }
            return true
        }
    }
}

private extension NSSound {
    static var Tink: NSSound? {
        return NSSound(named: NSSound.Name("Tink"))
    }
}
