import Foundation

/// Parses official Bijoy Bayanno XML layout files (`BijoyClassic.xml` and `Unicode.xml`).
public final class BijoyLayoutParser: NSObject, XMLParserDelegate {

    public static func loadLayout(from url: URL, addClassicDigitMappings: Bool = false) -> KeyboardLayoutDefinition? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let parser = BijoyLayoutParser(addClassicDigitMappings: addClassicDigitMappings)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else {
            return nil
        }
        return parser.buildDefinition()
    }

    private let addClassicDigitMappings: Bool
    private var layoutName: String = ""
    private var iconName: String = ""
    private var currentElement: String = ""
    private var textBuffer: String = ""

    // Current <Key> state
    private var inKeyElement = false
    private var currentKeyCode: Int?
    private var currentNormalOption: KeyBehaviorOption = .none
    private var currentShiftOption: KeyBehaviorOption = .none
    private var currentNormalText: String = ""
    private var currentShiftText: String = ""

    // Current <Juk> state
    private var inJukElement = false
    private var currentSeqText: String = ""
    private var currentOutText: String = ""

    private var keysByMacCode: [UInt16: KeyMappingDefinition] = [:]
    private var jukRules: [String: String] = [:]

    private init(addClassicDigitMappings: Bool) {
        self.addClassicDigitMappings = addClassicDigitMappings
        super.init()
    }

    private func buildDefinition() -> KeyboardLayoutDefinition {
        if addClassicDigitMappings {
            // In BijoyClassic.xml, digits 0-9 (except Shift+7 = 'u' চন্দ্রবিন্দু and Shift+4 = 'taka')
            // pass through as ASCII digits '0'..'9', which SutonnyMJ renders as ০..৯.
            // Adding explicit mappings for 0-9 ensures they also work when converted to Unicode.
            let classicDigits: [(vk: Int, normal: String, shift: String)] = [
                (48, "0", ")"),
                (49, "1", "!"),
                (50, "2", "@"),
                (51, "3", "#"),
                (52, "4", "$"),
                (53, "5", "%"),
                (54, "6", "^"),
                (55, "7", "u"),
                (56, "8", "*"),
                (57, "9", "(")
            ]
            for item in classicDigits {
                if let macKey = WindowsToMacKeyCodeMapper.macKeyCode(forWindowsVK: item.vk),
                   keysByMacCode[macKey] == nil {
                    keysByMacCode[macKey] = KeyMappingDefinition(
                        windowsVirtualKeyCode: item.vk,
                        macKeyCode: macKey,
                        normalOutput: item.normal,
                        shiftOutput: item.shift,
                        normalOption: .none,
                        shiftOption: .none
                    )
                }
            }
        }
        return KeyboardLayoutDefinition(
            name: layoutName,
            iconName: iconName,
            keysByMacKeyCode: keysByMacCode,
            jukRules: jukRules
        )
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        textBuffer = ""

        if elementName == "Key" {
            inKeyElement = true
            currentKeyCode = attributeDict["KeyCode"].flatMap { Int($0) }
            currentNormalOption = KeyBehaviorOption.parse(attributeDict["Normal_Option"])
            currentShiftOption = KeyBehaviorOption.parse(attributeDict["Shift_Option"])
            currentNormalText = ""
            currentShiftText = ""
        } else if elementName == "Juk" {
            inJukElement = true
            currentSeqText = ""
            currentOutText = ""
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer.append(string)
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "Name":
            layoutName = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "IconName":
            iconName = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "Normal" where inKeyElement:
            currentNormalText = textBuffer
        case "Shift" where inKeyElement:
            currentShiftText = textBuffer
        case "Key":
            if let vk = currentKeyCode,
               let macCode = WindowsToMacKeyCodeMapper.macKeyCode(forWindowsVK: vk) {
                keysByMacCode[macCode] = KeyMappingDefinition(
                    windowsVirtualKeyCode: vk,
                    macKeyCode: macCode,
                    normalOutput: currentNormalText,
                    shiftOutput: currentShiftText,
                    normalOption: currentNormalOption,
                    shiftOption: currentShiftOption
                )
            }
            inKeyElement = false
        case "Seq" where inJukElement:
            currentSeqText = textBuffer
        case "Out" where inJukElement:
            currentOutText = textBuffer
        case "Juk":
            if !currentSeqText.isEmpty {
                jukRules[currentSeqText] = currentOutText
            }
            inJukElement = false
        default:
            break
        }
        currentElement = ""
    }
}
