import Foundation

/// Active typing mode for BornoLipi (matching Windows Bijoy Bayanno).
public enum TypingMode: Int, CaseIterable {
    case english = 0
    case bijoyClassic = 1
    case bijoyUnicode = 2

    public var title: String {
        switch self {
        case .english:
            return "English"
        case .bijoyClassic:
            return "Bijoy Classic (SutonnyMJ)"
        case .bijoyUnicode:
            return "Unicode (Bangla)"
        }
    }

    public var shortBadge: String {
        switch self {
        case .english:
            return "EN"
        case .bijoyClassic:
            return "বিজয়"
        case .bijoyUnicode:
            return "ইউনি"
        }
    }
}

/// Option flags attached to `<Key>` entries in Bijoy XML layout files (`Normal_Option` / `Shift_Option`).
public enum KeyBehaviorOption: Equatable {
    case none
    /// Holds a pre-base vowel sign (`ি`, `ে`, `ৈ`) until the next consonant/cluster is typed (`Delay` in `Unicode.xml`).
    case delay
    /// Extends the pending pre-base vowel delay across a 1-keycluster follower (`্র`, `্য`) (`DeInc1` in `Unicode.xml`).
    case deInc(Int)
    /// Moves cursor left or inserts before the previous consonant (`র্` রেফ) (`MoveL` in `Unicode.xml`).
    case moveLeft
    /// Appends a hidden Zero-Width Non-Joiner (`\u{200C}`) in the sequence queue for `র` (`Xtra` in `Unicode.xml`).
    case extraZWNJ

    public static func parse(_ raw: String?) -> KeyBehaviorOption {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .none
        }
        if raw.hasPrefix("DeInc"), let n = Int(raw.dropFirst("DeInc".count)) {
            return .deInc(n)
        }
        switch raw {
        case "Delay":
            return .delay
        case "MoveL":
            return .moveLeft
        case "Xtra":
            return .extraZWNJ
        default:
            return .none
        }
    }
}

/// Represents one `<Key KeyCode="...">` definition from a Bijoy XML layout file.
public struct KeyMappingDefinition {
    public let windowsVirtualKeyCode: Int
    public let macKeyCode: UInt16
    public let normalOutput: String
    public let shiftOutput: String
    public let normalOption: KeyBehaviorOption
    public let shiftOption: KeyBehaviorOption

    public init(
        windowsVirtualKeyCode: Int,
        macKeyCode: UInt16,
        normalOutput: String,
        shiftOutput: String,
        normalOption: KeyBehaviorOption,
        shiftOption: KeyBehaviorOption
    ) {
        self.windowsVirtualKeyCode = windowsVirtualKeyCode
        self.macKeyCode = macKeyCode
        self.normalOutput = normalOutput
        self.shiftOutput = shiftOutput
        self.normalOption = normalOption
        self.shiftOption = shiftOption
    }
}

/// Complete parsed representation of a Bijoy XML layout (`BijoyClassic.xml` or `Unicode.xml`).
public struct KeyboardLayoutDefinition {
    public let name: String
    public let iconName: String
    /// Lookup by macOS hardware `CGKeyCode`.
    public let keysByMacKeyCode: [UInt16: KeyMappingDefinition]
    /// Lookup of `<Juk><Seq>...</Seq><Out>...</Out></Juk>` sequence replacements.
    public let jukRules: [String: String]
    /// Maximum length (in `Character`s) of any `<Seq>` in `jukRules`.
    public let maxJukSequenceLength: Int

    public init(
        name: String,
        iconName: String,
        keysByMacKeyCode: [UInt16: KeyMappingDefinition],
        jukRules: [String: String]
    ) {
        self.name = name
        self.iconName = iconName
        self.keysByMacKeyCode = keysByMacKeyCode
        self.jukRules = jukRules
        self.maxJukSequenceLength = jukRules.keys.map { $0.count }.max() ?? 10
    }
}

/// Maps Windows `VK_*` key codes (used in Bijoy 52 XML layouts) to macOS `CGKeyCode` hardware key codes.
public enum WindowsToMacKeyCodeMapper {
    public static let mapping: [Int: UInt16] = [
        32:  49, // Space
        48:  29, // 0
        49:  18, // 1
        50:  19, // 2
        51:  20, // 3
        52:  21, // 4
        53:  23, // 5
        54:  22, // 6
        55:  26, // 7
        56:  28, // 8
        57:  25, // 9
        65:   0, // A
        66:  11, // B
        67:   8, // C
        68:   2, // D
        69:  14, // E
        70:   3, // F
        71:   5, // G
        72:   4, // H
        73:  34, // I
        74:  38, // J
        75:  40, // K
        76:  37, // L
        77:  46, // M
        78:  45, // N
        79:  31, // O
        80:  35, // P
        81:  12, // Q
        82:  15, // R
        83:   1, // S
        84:  17, // T
        85:  32, // U
        86:   9, // V
        87:  13, // W
        88:   7, // X
        89:  16, // Y
        90:   6, // Z
        188: 43, // , (Comma)
        189: 27, // - (Minus)
        190: 47, // . (Period)
        192: 50, // ` (Backtick)
        220: 42, // \ (Backslash)
        222: 39  // ' (Quote)
    ]

    public static func macKeyCode(forWindowsVK vk: Int) -> UInt16? {
        return mapping[vk]
    }
}
