import Cocoa

/// Floating Keymap & Conjunct (`যুক্তবর্ণ`) reference window toggled from anywhere via `F1` or `Option + K`.
public final class KeymapOverlayWindow: NSPanel {

    public init() {
        let rect = NSRect(x: 160, y: 140, width: 920, height: 610)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.title = "বর্ণলিপি — Bijoy Bangla Keyboard Layout & যুক্তবর্ণ Guide (Press F1 or Option+K to Hide)"
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = NSColor(calibratedRed: 0.09, green: 0.13, blue: 0.18, alpha: 0.98)

        setupTabs()
    }

    public func toggleVisibility() {
        if isVisible {
            orderOut(nil)
        } else {
            center()
            orderFrontRegardless()
        }
    }

    private func setupTabs() {
        let tabView = NSTabView(frame: contentView!.bounds)
        tabView.autoresizingMask = [.width, .height]
        tabView.font = NSFont.boldSystemFont(ofSize: 13)

        // Tab 1: Official Bijoy Keyboard Chart Image (`bijoy_keymap.png`)
        let chartTab = NSTabViewItem(identifier: "chart")
        chartTab.label = "🖼️ বিজয় কীবোর্ড চার্ট (Official Layout)"
        let chartContainer = NSView(frame: tabView.bounds)
        chartContainer.autoresizingMask = [.width, .height]

        let imageView = NSImageView(frame: NSRect(x: 16, y: 52, width: 888, height: 495))
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        if let imgURL = Bundle.main.url(forResource: "bijoy_keymap", withExtension: "png"),
           let img = NSImage(contentsOf: imgURL) {
            imageView.image = img
        }
        chartContainer.addSubview(imageView)

        let footerNote = NSTextField(
            labelWithString: "💡 Shortcuts:  F1 or Option+K = Show/Hide Keymap   |   Ctrl+Option+B (or F12) = Switch Mode (English / Bijoy Classic / Unicode)   |   g = হসন্ত / Link Key"
        )
        footerNote.font = NSFont.boldSystemFont(ofSize: 12.5)
        footerNote.textColor = NSColor(calibratedRed: 0.55, green: 0.86, blue: 1.0, alpha: 1.0)
        footerNote.alignment = .center
        footerNote.frame = NSRect(x: 16, y: 12, width: 888, height: 26)
        footerNote.autoresizingMask = [.width, .maxYMargin]
        chartContainer.addSubview(footerNote)

        chartTab.view = chartContainer
        tabView.addTabViewItem(chartTab)

        // Tab 2: Common Conjuncts (`যুক্তবর্ণ` Cheat Sheet)
        let jukTab = NSTabViewItem(identifier: "juk")
        jukTab.label = "🔗 যুক্তবর্ণ ও স্বরবর্ণ গাইড (Conjuncts Cheat Sheet)"
        jukTab.view = buildConjunctGuideView(frame: tabView.bounds)
        tabView.addTabViewItem(jukTab)

        contentView?.addSubview(tabView)
    }

    private func buildConjunctGuideView(frame: NSRect) -> NSView {
        let scroll = NSScrollView(frame: frame)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let textView = NSTextView(frame: frame)
        textView.isEditable = false
        textView.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.15, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 22, height: 18)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        textView.textColor = .white

        let guideText = """
        ══════════════════════════════════════════════════════════════════════════════════════
          ১. স্বরবর্ণ (Independent Vowels — Type directly in BOTH Bijoy Classic & Unicode!)
        ══════════════════════════════════════════════════════════════════════════════════════
          অ = Shift + F        আ = Shift + F, f (অথবা g + f)     ই = g + d          ঈ = g + Shift + D
          উ = g + s            ঊ = g + Shift + S                 ঋ = g + a          এ = g + c
          ঐ = g + Shift + C    ও = x                             ঔ = g + Shift + X

        ══════════════════════════════════════════════════════════════════════════════════════
          ২. কার ও ফলা (Vowel Signs & Fola)
        ══════════════════════════════════════════════════════════════════════════════════════
          া (আ-কার) = f        ি (ই-কার) = d         ী (ঈ-কার) = Shift + D    ু (উ-কার) = s
          ূ (ঊ-কার) = Shift+S  ৃ (ঋ-কার) = a         ে (এ-কার) = c            ৈ (ঐ-কার) = Shift + C
          ো (ও-কার) = c + f    ৌ (ঔ-কার) = c+Shift+X ্র (র-ফলা) = z           ্য (য-ফলা) = Shift + Z
          র্ (রেফ)  = Shift+A  ঁ (চন্দ্রবিন্দু) = Shift+7 ং (অনুস্বার) = Shift+Q    ঃ (বিসর্গ) = Shift + \\
          ্ (হসন্ত) = g        । (দাঁড়ি)   = Shift + G  ৎ (খণ্ড-ত) = \\            ৳ (টাকা)  = Shift + 4

          📌 Bijoy Classic (SutonnyMJ) লেখার নিয়ম (Microsoft Word):
             • ই-কার (d), এ-কার (c), এবং ঐ-কার (Shift+C) ব্যঞ্জনবর্ণের **আগে** চাপুন (যেমন: 'কে' = c তারপরে j)।
             • আ-কার (f), ঈ-কার (Shift+D), উ-কার (s), ঊ-কার (Shift+S), ঋ-কার (a), রেফ (Shift+A) ব্যঞ্জনবর্ণের **পরে** চাপুন।
             • ও-কার ('কো') লিখতে: প্রথমে c (‡), তারপরে ব্যঞ্জনবর্ণ j (K), তারপরে f (v) -> †Kv।

        ══════════════════════════════════════════════════════════════════════════════════════
          ৩. সবচেয়ে বেশি ব্যবহৃত যুক্তবর্ণ (g = Link / হসন্ত Key) — Total 414 Juk Rules Built-In!
        ══════════════════════════════════════════════════════════════════════════════════════
          ক্ষ (ক+ষ)  = j + g + Shift+N      জ্ঞ (জ+ঞ)  = u + g + Shift+I      ঞ্চ (ঞ+চ)  = Shift+I + g + y
          ঞ্ছ (ঞ+ছ)  = Shift+I + g + Shift+Y ঞ্জ (ঞ+জ)  = Shift+I + g + u      ণ্ট (ণ+ট)  = Shift+B + g + t
          ণ্ঠ (ণ+ঠ)  = Shift+B + g + Shift+T ণ্ড (ণ+ড)  = Shift+B + g + e      ত্ত (ত+ত)  = k + g + k
          ত্থ (ত+থ)  = k + g + Shift+K      ত্ন (ত+ন)  = k + g + b            ত্ম (ত+ম)  = k + g + m
          ত্র (ত+র)  = k + z                দ্দ (দ+দ)  = l + g + l            দ্ধ (দ+ধ)  = l + g + Shift+L
          দ্ব (দ+ব)  = l + g + h            দ্ম (দ+ম)  = l + g + m            দ্র (দ+র)  = l + z
          ধ্রু (ধ+র+ু)= Shift+L + z + s     ন্ত (ন+ত)  = b + g + k            ন্ত্র (ন+ত+র)= b + g + k + z
          ন্থ (ন+থ)  = b + g + Shift+K      ন্দ (ন+দ)  = b + g + l            ন্ধ (ন+ধ)  = b + g + Shift+L
          ন্ন (ন+ন)  = b + g + b            ন্ব (ন+ব)  = b + g + h            ন্ম (ন+ম)  = b + g + m
          প্ট (প+ট)  = r + g + t            প্ত (প+ত)  = r + g + k            প্ন (প+ন)  = r + g + b
          প্প (প+প)  = r + g + r            প্র (প+র)  = r + z                প্ল (প+ল)  = r + g + Shift+V
          ব্জ (ব+জ)  = h + g + u            ব্দ (ব+দ)  = h + g + l            ব্ধ (ব+ধ)  = h + g + Shift+L
          ব্ব (ব+ব)  = h + g + h            ব্র (ব+র)  = h + z                ভ্র (ভ+র)  = Shift+H + z
          ম্ন (ম+ন)  = m + g + b            ম্প (ম+প)  = m + g + r            ম্ফ (ম+ফ)  = m + g + Shift+R
          ম্ব (ম+ব)  = m + g + h            ম্ভ (ম+ভ)  = m + g + Shift+H      ম্ম (ম+ম)  = m + g + m
          ল্ক (ল+ক)  = Shift+V + g + j      ল্গ (ল+গ)  = Shift+V + g + o      ল্ট (ল+ট)  = Shift+V + g + t
          ল্ড (ল+ড)  = Shift+V + g + e      ল্প (ল+প)  = Shift+V + g + r      ল্ল (ল+ল)  = Shift+V + g + Shift+V
          শ্চ (শ+চ)  = Shift+M + g + y      শ্ন (শ+ন)  = Shift+M + g + b      শ্ব (শ+ব)  = Shift+M + g + h
          শ্ম (শ+ম)  = Shift+M + g + m      শ্র (শ+র)  = Shift+M + z          শ্ল (শ+ল)  = Shift+M + g + Shift+V
          ষ্ক (ষ+ক)  = Shift+N + g + j      ষ্ট (ষ+ট)  = Shift+N + g + t      ষ্ঠ (ষ+ঠ)  = Shift+N + g + Shift+T
          ষ্ণ (ষ+ণ)  = Shift+N + g + Shift+B ষ্প (ষ+প)  = Shift+N + g + r      ষ্ফ (ষ+ফ)  = Shift+N + g + Shift+R
          স্ক (স+ক)  = n + g + j            স্ট (স+ট)  = n + g + t            স্ত (স+ত)  = n + g + k
          স্ত্র (স+ত+র)= n + g + k + z       স্থ (স+থ)  = n + g + Shift+K      স্ন (স+ন)  = n + g + b
          স্প (স+প)  = n + g + r            স্ফ (স+ফ)  = n + g + Shift+R      স্ব (স+ব)  = n + g + h
          স্ম (স+ম)  = n + g + m            স্র (স+র)  = n + z                হ্ম (হ+ম)  = i + g + m
          হ্ন (হ+ন)  = i + g + b            হ্ব (হ+ব)  = i + g + h            হৃ (হ+ঋ)  = i + a
          ঙ্ক (ঙ+ক)  = q + g + j            ঙ্গ (ঙ+গ)  = q + g + o            চ্ছ (চ+ছ)  = y + g + Shift+Y
        """
        textView.string = guideText
        scroll.documentView = textView
        return scroll
    }
}
