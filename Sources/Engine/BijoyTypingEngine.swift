import Foundation

/// Action returned by `BijoyTypingEngine` for a single hardware key press.
public enum KeyTransformationAction: Equatable {
    /// Let the operating system process the original key event untouched.
    case passThrough
    /// Consume the original key event, send `backspaces` Backspace key events,
    /// then emit `insertText` as Unicode/UTF-16 synthetic keyboard events.
    case replace(backspaces: Int, insertText: String)
}

/// Faithful macOS implementation of the Windows Bijoy Bayanno (`modKeyboard.IsHooked`) state machine.
///
/// Supports both:
/// - **Bijoy Classic (`SutonnyMJ` ANSI)** using all 414 `<Juk><Seq>...</Seq><Out>...</Out></Juk>` rules
///   and visual-order pre-base vowel signs (`w`, `‡`, `‰`).
/// - **Unicode Bangla (`Unicode.xml`)** using `Delay`, `DeInc1`, `DeInc2`, `MoveL`, `Xtra`, and `<Juk>` rules.
public final class BijoyTypingEngine {

    public static let shared = BijoyTypingEngine()

    public private(set) var classicLayout: KeyboardLayoutDefinition
    public private(set) var unicodeLayout: KeyboardLayoutDefinition

    public var currentMode: TypingMode = .bijoyClassic {
        didSet {
            resetBuffer()
            NotificationCenter.default.post(name: .bornoLipiModeDidChange, object: currentMode)
        }
    }

    /// Rolling 20-character sequence buffer (`Que` in `BijoyBayanno.exe`), initialized with a space `" "`
    /// so word-initial rules like `<Seq> ‡</Seq><Out> †</Out>` match at the start of typing.
    private var sequenceQueue: String = " "

    /// Tracks the character length of each emitted output segment so Backspace can unwind cleanly.
    private var emittedHistory: [String] = []

    // Unicode-mode state (`delayKey`, `delayTimer`, `delayOut`, `lastDelayOut`, `flagLeft` in `BijoyBayanno.exe`)
    private var delayKey: Bool = false
    private var delayTimer: Int = 0
    private var delayOut: String = ""
    private var lastDelayOut: String = ""

    private init() {
        let bundle = Bundle.main
        let classicURL = bundle.url(forResource: "BijoyClassic", withExtension: "xml")
            ?? URL(fileURLWithPath: "Resources/BijoyClassic.xml")
        let unicodeURL = bundle.url(forResource: "Unicode", withExtension: "xml")
            ?? URL(fileURLWithPath: "Resources/Unicode.xml")

        self.classicLayout = BijoyLayoutParser.loadLayout(from: classicURL, addClassicDigitMappings: true)
            ?? KeyboardLayoutDefinition(name: "Bijoy Classic", iconName: "Classic", keysByMacKeyCode: [:], jukRules: [:])
        self.unicodeLayout = BijoyLayoutParser.loadLayout(from: unicodeURL, addClassicDigitMappings: false)
            ?? KeyboardLayoutDefinition(name: "Unicode", iconName: "Unicode", keysByMacKeyCode: [:], jukRules: [:])
    }

    /// Resets the rolling sequence buffer (called on mode switch, mouse click, arrow keys, or Escape).
    public func resetBuffer() {
        sequenceQueue = " "
        emittedHistory.removeAll()
        delayKey = false
        delayTimer = 0
        delayOut = ""
        lastDelayOut = ""
    }

    public func cycleMode() {
        let all = TypingMode.allCases
        let nextIndex = (currentMode.rawValue + 1) % all.count
        currentMode = all[nextIndex]
    }

    // MARK: - Key Processing Entry Point

    public func processKeyDown(macKeyCode: UInt16, isShiftPressed: Bool) -> KeyTransformationAction {
        guard currentMode != .english else {
            return .passThrough
        }

        // Backspace (macOS keyCode 51)
        if macKeyCode == 51 {
            if !sequenceQueue.isEmpty {
                sequenceQueue.removeLast()
            }
            if sequenceQueue.isEmpty {
                sequenceQueue = " "
            }
            if !emittedHistory.isEmpty {
                emittedHistory.removeLast()
            }
            delayKey = false
            delayTimer = 0
            delayOut = ""
            lastDelayOut = ""
            return .passThrough
        }

        // Return / Enter (36, 76), Tab (48), Escape (53), Arrow keys (123, 124, 125, 126)
        if [36, 76, 48, 53, 123, 124, 125, 126].contains(macKeyCode) {
            resetBuffer()
            return .passThrough
        }

        switch currentMode {
        case .english:
            return .passThrough
        case .bijoyClassic:
            return processClassicKey(macKeyCode: macKeyCode, isShiftPressed: isShiftPressed)
        case .bijoyUnicode:
            return processUnicodeKey(macKeyCode: macKeyCode, isShiftPressed: isShiftPressed)
        }
    }

    // MARK: - Bijoy Classic (`SutonnyMJ`) Engine (`ReQue` + 414 `<Juk>` Rules)

    private func processClassicKey(macKeyCode: UInt16, isShiftPressed: Bool) -> KeyTransformationAction {
        guard let keyDef = classicLayout.keysByMacKeyCode[macKeyCode] else {
            // Unmapped key (e.g. punctuation not in XML): append space separator to queue and pass through
            appendToQueue(" ")
            return .passThrough
        }

        let rawOutput = isShiftPressed ? keyDef.shiftOutput : keyDef.normalOutput
        guard !rawOutput.isEmpty else {
            return .passThrough
        }

        // Append the newly typed key's raw output to `Que` (up to 20 chars, matching `ReQue` in BijoyBayanno.exe)
        appendToQueue(rawOutput)

        // Check `<Juks>` from longest possible suffix (`i = 10` down to `2`) matching `Que.suffix(i)`
        let maxLen = min(classicLayout.maxJukSequenceLength, sequenceQueue.count)
        if maxLen >= 2 {
            for length in stride(from: maxLen, through: 2, by: -1) {
                let candidateSeq = String(sequenceQueue.suffix(length))
                if let jukOut = classicLayout.jukRules[candidateSeq] {
                    // How many characters were ALREADY sent to the target app before this keystroke?
                    // Note: If `candidateSeq` begins with `" "` (the initial buffer sentinel before any Space key was pressed)
                    // and `emittedHistory` is empty, that leading `" "` was never typed onto the screen!
                    // In that case, strip the leading `" "` from `jukOut` and do not backspace for it.
                    var effectiveOut = jukOut
                    var previouslyTypedCount = max(0, candidateSeq.utf16.count - rawOutput.utf16.count)
                    if candidateSeq.hasPrefix(" ") && emittedHistory.isEmpty && effectiveOut.hasPrefix(" ") {
                        effectiveOut.removeFirst()
                        previouslyTypedCount = max(0, previouslyTypedCount - 1)
                    }
                    // Replace the matched suffix in `sequenceQueue` with `jukOut` (just like `SendKey` + `ReQue(jukOut)`)
                    sequenceQueue.removeLast(length)
                    appendToQueue(jukOut)
                    emittedHistory.append(effectiveOut)
                    return .replace(backspaces: previouslyTypedCount, insertText: effectiveOut)
                }
            }
        }

        emittedHistory.append(rawOutput)
        return .replace(backspaces: 0, insertText: rawOutput)
    }

    // MARK: - Bijoy Unicode Engine (`Delay`, `DeInc1`, `DeInc2`, `MoveL`, `Xtra`, and `<Juks>`)

    private func processUnicodeKey(macKeyCode: UInt16, isShiftPressed: Bool) -> KeyTransformationAction {
        guard let keyDef = unicodeLayout.keysByMacKeyCode[macKeyCode] else {
            flushPendingDelayIfNeeded()
            appendToQueue(" ")
            return .passThrough
        }

        let rawOutput = isShiftPressed ? keyDef.shiftOutput : keyDef.normalOutput
        let option = isShiftPressed ? keyDef.shiftOption : keyDef.normalOption
        guard !rawOutput.isEmpty else {
            return .passThrough
        }

        // 1. Check if `rawOutput` combines with the immediately preceding characters via `<Juk>` FIRST
        //    (e.g., `্` + `ি` -> `ই`, `্` + `ে` -> `এ`, `ে` + `া` -> `ো`, `ে` + `ৗ` -> `ৌ`, `অ` + `া` -> `আ`).
        //    Wait: In Bijoy Unicode, if the user types `g` (`্`) followed by `d` (`ি`, which has `Delay`),
        //    does `্ি -> ই` fire immediately? YES! Because in `IsHooked`, `Delay` puts `ি` into `Que` (or if `্` is at the end of `Que`, `<Seq>্ি</Seq><Out>ই</Out>` matches!).
        let testQueue = sequenceQueue + rawOutput
        let maxLen = min(unicodeLayout.maxJukSequenceLength, testQueue.count)
        if maxLen >= 2 {
            for length in stride(from: maxLen, through: 2, by: -1) {
                let candidateSeq = String(testQueue.suffix(length))
                if let jukOut = unicodeLayout.jukRules[candidateSeq] {
                    // Note: If the previous key was a `Delay` vowel (e.g. `ে` in `ো -> ো`) that was held and NOT yet emitted,
                    // or if it WAS emitted after a consonant, how many UTF-16 code units are on screen?
                    let prefixInQueue = String(candidateSeq.dropLast(rawOutput.count))
                    let backspaces: Int
                    if delayKey && delayOut == prefixInQueue {
                        // The delayed vowel `ে` was never sent to screen yet!
                        delayKey = false
                        delayTimer = 0
                        delayOut = ""
                        backspaces = 0
                    } else {
                        backspaces = prefixInQueue.utf16.count
                    }
                    sequenceQueue = String(testQueue.dropLast(length))
                    appendToQueue(jukOut)
                    emittedHistory.append(jukOut)
                    return .replace(backspaces: backspaces, insertText: jukOut)
                }
            }
        }

        // 2. Handle `Delay` option (pre-base vowels `ি`, `ে`, `ৈ` in `Unicode.xml`):
        //    In Bijoy 52, typing `d` (`ি`) or `c` (`ে`) or `Shift+C` (`ৈ`) BEFORE a consonant holds the vowel
        //    in `delayOut` (with `delayTimer = 1`) and outputs it AFTER the consonant (or conjunct cluster)!
        if option == .delay {
            var prefixToFlush = ""
            if delayKey && !delayOut.isEmpty {
                prefixToFlush = delayOut
            }
            delayKey = true
            delayTimer = 1
            delayOut = rawOutput
            appendToQueue(rawOutput)
            if !prefixToFlush.isEmpty {
                return .replace(backspaces: 0, insertText: prefixToFlush)
            }
            // Swallow the key press for now; it will be emitted after the next consonant!
            return .replace(backspaces: 0, insertText: "")
        }

        // 3. Handle `MoveL` option (`Shift+A` = `র্` রেফ in `Unicode.xml`):
        //    In Bijoy Classic / Bijoy 52 habit, users type `Shift+A` (`র্`) AFTER the consonant (e.g., `ক` + `র্` -> `র্ক`).
        //    Instead of sending LeftArrow + `র্` + RightArrow (which breaks in some web/rich-text editors),
        //    we can directly backspace the preceding consonant/cluster (and its vowel sign if any) and re-emit `র্` + cluster!
        if option == .moveLeft {
            if let lastCluster = extractTrailingUnicodeConsonantCluster(from: sequenceQueue), !lastCluster.isEmpty {
                let bsCount = lastCluster.utf16.count
                let reordered = rawOutput + lastCluster
                sequenceQueue.removeLast(lastCluster.count)
                appendToQueue(reordered)
                return .replace(backspaces: bsCount, insertText: reordered)
            } else {
                appendToQueue(rawOutput)
                return .replace(backspaces: 0, insertText: rawOutput)
            }
        }

        // 4. Handle `DeInc1` (`্র`, `্য`) and `DeInc2` (`্` হসন্ত) when a `Delay` vowel is pending:
        //    - `DeInc2` (`্`): extends `delayTimer` so the next consonant attaches to the conjunct BEFORE the delayed vowel is flushed!
        //    - `DeInc1` (`্র`, `্য`): attaches to the consonant and then flushes the delayed vowel right after `্র`/`্য`!
        if case .deInc(let n) = option {
            appendToQueue(rawOutput)
            if delayKey {
                if n == 2 {
                    // `্` (link/hasanta): keep holding `delayOut` for the next consonant in the conjunct
                    delayTimer = 1
                    return .replace(backspaces: 0, insertText: rawOutput)
                } else {
                    // `্র` or `্য`: emit `্র`/`্য` followed by the delayed vowel, and keep `lastDelayOut` in case another `্` follows
                    let flushed = rawOutput + delayOut
                    lastDelayOut = delayOut
                    delayKey = false
                    delayTimer = 0
                    delayOut = ""
                    return .replace(backspaces: 0, insertText: flushed)
                }
            }
            // If `্` is typed AFTER a delayed vowel was already flushed (`lastDelayOut`), pull the vowel back!
            if n == 2 && !lastDelayOut.isEmpty && sequenceQueue.dropLast(rawOutput.count).hasSuffix(lastDelayOut) {
                let vowelToPullBack = lastDelayOut
                let bsCount = vowelToPullBack.utf16.count
                // Remove `vowelToPullBack + rawOutput` from queue, put `rawOutput` (`্`), and re-arm `delayOut = vowelToPullBack`
                sequenceQueue.removeLast(rawOutput.count + vowelToPullBack.count)
                appendToQueue(rawOutput)
                delayKey = true
                delayTimer = 1
                delayOut = vowelToPullBack
                lastDelayOut = ""
                return .replace(backspaces: bsCount, insertText: rawOutput)
            }
            return .replace(backspaces: 0, insertText: rawOutput)
        }

        // 5. Normal consonant / vowel / symbol key (`option == .none` or `.extraZWNJ`)
        appendToQueue(rawOutput)
        if option == .extraZWNJ {
            // In `Unicode.xml`, `র` (`V`) has `Normal_Option="Xtra"` so `র` + `্য` can form `র‌্য`
            // We only need rawOutput (`র`) emitted; if followed by `্য`, the `<Juk>` rule handles `র‌্য`.
        }

        if delayKey && !delayOut.isEmpty {
            // Remove the delayed vowel from its old pre-base position in `sequenceQueue` and place it after `rawOutput`
            let vowel = delayOut
            delayKey = false
            delayTimer = 0
            delayOut = ""
            lastDelayOut = vowel
            appendToQueue(vowel)
            return .replace(backspaces: 0, insertText: rawOutput + vowel)
        } else {
            lastDelayOut = ""
            return .replace(backspaces: 0, insertText: rawOutput)
        }
    }

    // MARK: - Queue Helpers

    private func appendToQueue(_ text: String) {
        sequenceQueue.append(text)
        if sequenceQueue.count > 20 {
            sequenceQueue = String(sequenceQueue.suffix(20))
        }
    }

    private func flushPendingDelayIfNeeded() {
        delayKey = false
        delayTimer = 0
        delayOut = ""
        lastDelayOut = ""
    }

    /// Extracts the trailing Bangla Unicode consonant/conjunct cluster from `queue` so `MoveL` (`র্` রেফ)
    /// can be placed before the consonant cluster when typed after it.
    private func extractTrailingUnicodeConsonantCluster(from queue: String) -> String? {
        let scalars = Array(queue.unicodeScalars)
        guard !scalars.isEmpty else { return nil }

        func isBanglaConsonant(_ u: UnicodeScalar) -> Bool {
            return (0x0995...0x09B9).contains(u.value)
                || (0x09DC...0x09DF).contains(u.value)
                || u.value == 0x09CE
        }
        func isBanglaDependentVowelOrSign(_ u: UnicodeScalar) -> Bool {
            return (0x09BE...0x09CC).contains(u.value)
                || u.value == 0x0981 || u.value == 0x09D7
        }
        let hasanta: UInt32 = 0x09CD

        var idx = scalars.count - 1
        // Skip trailing dependent vowel sign(s) if the user typed consonant + vowel + রেফ
        while idx >= 0 && isBanglaDependentVowelOrSign(scalars[idx]) {
            idx -= 1
        }
        guard idx >= 0 && isBanglaConsonant(scalars[idx]) else {
            return nil
        }
        // Walk backwards across `্` (hasanta) + consonant links in a conjunct
        while idx >= 2 && scalars[idx - 1].value == hasanta && isBanglaConsonant(scalars[idx - 2]) {
            idx -= 2
        }
        let clusterScalars = scalars[idx..<scalars.count]
        var result = String.UnicodeScalarView()
        result.append(contentsOf: clusterScalars)
        return String(result)
    }
}

public extension Notification.Name {
    static let bornoLipiModeDidChange = Notification.Name("BornoLipiModeDidChangeNotification")
    static let bornoLipiHookStateDidChange = Notification.Name("BornoLipiHookStateDidChangeNotification")
}
