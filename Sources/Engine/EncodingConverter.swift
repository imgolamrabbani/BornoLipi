import Foundation

/// Bidirectional converter between **Unicode Bangla** and **Bijoy Classic (`SutonnyMJ`)** encoding,
/// built directly from the 414 `<Juk>` and `<Key>` mappings of `BijoyClassic.xml` and `Unicode.xml`.
public final class EncodingConverter {

    public static let shared = EncodingConverter()

    private let unicodeToSutonnyTable: [(unicode: String, sutonny: String)]
    private let sutonnyToUnicodeTable: [(sutonny: String, unicode: String)]

    private init() {
        let engine = BijoyTypingEngine.shared
        var uniToSut: [String: String] = [:]

        // 1. Map single keys that share the same Windows VK code + Shift state between Unicode.xml and BijoyClassic.xml
        for (macKey, uniKey) in engine.unicodeLayout.keysByMacKeyCode {
            if let classicKey = engine.classicLayout.keysByMacKeyCode[macKey] {
                if !uniKey.normalOutput.isEmpty && !classicKey.normalOutput.isEmpty {
                    uniToSut[uniKey.normalOutput] = classicKey.normalOutput
                }
                if !uniKey.shiftOutput.isEmpty && !classicKey.shiftOutput.isEmpty {
                    uniToSut[uniKey.shiftOutput] = classicKey.shiftOutput
                }
            }
        }

        // 2. Map independent vowels and common sequences
        let explicitVowels: [(String, String)] = [
            ("অ", "A"), ("আ", "Av"), ("ই", "B"), ("ঈ", "C"),
            ("উ", "D"), ("ঊ", "E"), ("ঋ", "F"), ("এ", "G"),
            ("ঐ", "H"), ("ও", "I"), ("ঔ", "J"),
            ("া", "v"), ("ি", "w"), ("ী", "x"), ("ু", "y"),
            ("ূ", "~"), ("ৃ", "„"), ("ে", "‡"), ("ৈ", "‰"),
            ("ো", "‡v"), ("ৌ", "‡Š"), ("্", "&"), ("ৎ", "r"),
            ("ং", "s"), ("ঃ", "t"), ("ঁ", "u"), ("।", "|"),
            ("০", "0"), ("১", "1"), ("২", "2"), ("৩", "3"), ("৪", "4"),
            ("৫", "5"), ("৬", "6"), ("৭", "7"), ("৮", "8"), ("৯", "9")
        ]
        for (u, s) in explicitVowels {
            uniToSut[u] = s
        }

        // 3. Invert every `<Juk><Seq>...</Seq><Out>...</Out></Juk>` from `BijoyClassic.xml`
        //    by translating the `<Seq>` (which is written in Bijoy Classic base characters) into its Unicode equivalent!
        var sutBaseToUni: [Character: String] = [:]
        for (u, s) in uniToSut where s.count == 1 {
            if let ch = s.first {
                sutBaseToUni[ch] = u
            }
        }
        // Also map contextual variants back to Unicode
        sutBaseToUni["z"] = "ু"
        sutBaseToUni["‚"] = "ূ"
        sutBaseToUni["…"] = "ৃ"
        sutBaseToUni["†"] = "ে"
        sutBaseToUni["ˆ"] = "ৈ"
        sutBaseToUni["ª"] = "্র"
        sutBaseToUni["¨"] = "্য"
        sutBaseToUni["©"] = "র্"

        var sutToUni: [String: String] = [:]
        for (u, s) in uniToSut {
            sutToUni[s] = u
        }
        sutToUni["z"] = "ু"
        sutToUni["‚"] = "ূ"
        sutToUni["…"] = "ৃ"
        sutToUni["†"] = "ে"
        sutToUni["ˆ"] = "ৈ"

        for (seq, out) in engine.classicLayout.jukRules {
            // Translate `seq` (e.g. "K&K") into Unicode ("ক্ক")
            var uniSeq = ""
            var valid = true
            for ch in seq {
                if let u = sutBaseToUni[ch] {
                    uniSeq.append(u)
                } else {
                    valid = false
                    break
                }
            }
            if valid && !uniSeq.isEmpty && !out.isEmpty {
                uniToSut[uniSeq] = out
                sutToUni[out] = uniSeq
            }
        }

        self.unicodeToSutonnyTable = uniToSut
            .map { (unicode: $0.key, sutonny: $0.value) }
            .sorted { $0.unicode.count > $1.unicode.count }

        self.sutonnyToUnicodeTable = sutToUni
            .map { (sutonny: $0.key, unicode: $0.value) }
            .sorted { $0.sutonny.count > $1.sutonny.count }
    }

    /// Converts Unicode Bangla text into Bijoy Classic (`SutonnyMJ`) encoding,
    /// including visual reordering of pre-base vowels (`ি`, `ে`, `ৈ`, `ো`, `ৌ`) and রেফ (`র্`).
    public func convertUnicodeToSutonnyMJ(_ input: String) -> String {
        // Step 1: Decompose two-part vowels (`ো` -> `ে` + `া`, `ৌ` -> `ে` + `ৗ`)
        let decomposed = input
            .replacingOccurrences(of: "\u{09CB}", with: "\u{09C7}\u{09BE}")
            .replacingOccurrences(of: "\u{09CC}", with: "\u{09C7}\u{09D7}")

        // Step 2: Reorder pre-base vowel signs (`ি`, `ে`, `ৈ`) before the consonant/conjunct cluster
        let reordered = Self.reorderUnicodePreBaseVowelsAndReph(decomposed)

        // Step 3: Greedy longest-match replacement using `unicodeToSutonnyTable`
        var result = ""
        var index = reordered.startIndex
        while index < reordered.endIndex {
            var matched = false
            let remaining = reordered[index...]
            for entry in unicodeToSutonnyTable {
                if remaining.hasPrefix(entry.unicode) {
                    result.append(entry.sutonny)
                    index = reordered.index(index, offsetBy: entry.unicode.count)
                    matched = true
                    break
                }
            }
            if !matched {
                result.append(reordered[index])
                index = reordered.index(after: index)
            }
        }
        return result
    }

    /// Converts Bijoy Classic (`SutonnyMJ`) text back into standard Unicode Bangla.
    public func convertSutonnyMJToUnicode(_ input: String) -> String {
        var rawUnicode = ""
        var index = input.startIndex
        while index < input.endIndex {
            var matched = false
            let remaining = input[index...]
            for entry in sutonnyToUnicodeTable {
                if remaining.hasPrefix(entry.sutonny) {
                    rawUnicode.append(entry.unicode)
                    index = input.index(index, offsetBy: entry.sutonny.count)
                    matched = true
                    break
                }
            }
            if !matched {
                rawUnicode.append(input[index])
                index = input.index(after: index)
            }
        }
        return Self.reorderVisualPreBaseVowelsToLogicalUnicode(rawUnicode)
    }

    // MARK: - Reordering Helpers

    private static func reorderUnicodePreBaseVowelsAndReph(_ text: String) -> String {
        var scalars = Array(text.unicodeScalars)
        func isConsonant(_ u: UnicodeScalar) -> Bool {
            return (0x0995...0x09B9).contains(u.value)
                || (0x09DC...0x09DF).contains(u.value)
                || u.value == 0x09CE
        }
        func isPreKar(_ u: UnicodeScalar) -> Bool {
            return u.value == 0x09BF || u.value == 0x09C7 || u.value == 0x09C8
        }
        let hasanta: UInt32 = 0x09CD

        var i = 0
        while i < scalars.count {
            if isPreKar(scalars[i]) && i > 0 {
                // Walk backwards over the preceding consonant or conjunct cluster
                var start = i - 1
                if isConsonant(scalars[start]) {
                    while start >= 2 && scalars[start - 1].value == hasanta && isConsonant(scalars[start - 2]) {
                        start -= 2
                    }
                    let kar = scalars.remove(at: i)
                    scalars.insert(kar, at: start)
                }
            }
            i += 1
        }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: scalars)
        return String(out)
    }

    private static func reorderVisualPreBaseVowelsToLogicalUnicode(_ text: String) -> String {
        var scalars = Array(text.unicodeScalars)
        func isConsonant(_ u: UnicodeScalar) -> Bool {
            return (0x0995...0x09B9).contains(u.value)
                || (0x09DC...0x09DF).contains(u.value)
                || u.value == 0x09CE
        }
        func isPreKar(_ u: UnicodeScalar) -> Bool {
            return u.value == 0x09BF || u.value == 0x09C7 || u.value == 0x09C8
        }
        let hasanta: UInt32 = 0x09CD

        var i = 0
        while i < scalars.count - 1 {
            if isPreKar(scalars[i]) && isConsonant(scalars[i + 1]) {
                let kar = scalars.remove(at: i)
                var end = i
                while end + 2 < scalars.count && scalars[end + 1].value == hasanta && isConsonant(scalars[end + 2]) {
                    end += 2
                }
                scalars.insert(kar, at: end + 1)
                i = end + 2
            } else {
                i += 1
            }
        }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: scalars)
        return String(out)
            .replacingOccurrences(of: "\u{09C7}\u{09BE}", with: "\u{09CB}")
            .replacingOccurrences(of: "\u{09C7}\u{09D7}", with: "\u{09CC}")
    }
}
