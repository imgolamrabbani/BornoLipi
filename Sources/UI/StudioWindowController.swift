import Cocoa

/// Industry-grade Bijoy Bayanno Studio & SutonnyMJ Converter window for macOS.
///
/// Features the original Bijoy Bayanno header banner (`bijoy_header_banner.png`), classic sage-green / bevel canvas
/// aesthetics inspired by the official Bijoy 52 desktop app, custom icon controls, and live bidirectional
/// `Unicode Bangla <-> SutonnyMJ (Bijoy Classic)` conversion.
public final class StudioWindowController: NSObject, NSTextViewDelegate {

    public let window: NSWindow
    public var onShowKeymap: (() -> Void)?
    public var onShowSplash: (() -> Void)?

    private let modePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let modeEmblemView = NSImageView(frame: .zero)
    private let hookStatusButton = NSButton(title: "", target: nil, action: nil)
    private let unicodeTextView = NSTextView()
    private let sutonnyTextView = NSTextView()
    private var isSyncingText = false

    public override init() {
        let rect = NSRect(x: 160, y: 120, width: 980, height: 640)
        self.window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "বিজয় বায়ান্নো — বর্ণলিপি (BornoLipi Studio & SutonnyMJ Converter)"
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 0.76, green: 0.79, blue: 0.77, alpha: 1.0)
        setupUI()
        registerNotifications()
        refreshUIState()
    }

    public func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadAsset(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "Resources/Assets/\(name).png")
    }

    private func setupUI() {
        guard let content = window.contentView else { return }

        // 1. Top Authentic Bijoy Bayanno Banner Header (White/Ivory Bevel Card with `bijoy_header_banner.png`)
        let headerView = NSView(frame: NSRect(x: 0, y: 552, width: 980, height: 88))
        headerView.autoresizingMask = [.width, .minYMargin]
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.white.cgColor
        headerView.layer?.borderWidth = 1.0
        headerView.layer?.borderColor = NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.18, alpha: 0.4).cgColor

        let bannerImageView = NSImageView(frame: NSRect(x: 18, y: 6, width: 350, height: 76))
        bannerImageView.imageScaling = .scaleProportionallyUpOrDown
        bannerImageView.image = loadAsset("bornolipi_header_banner")
        headerView.addSubview(bannerImageView)

        let editionTitle = NSTextField(labelWithString: "বর্ণলিপি • macOS Universal Engine")
        editionTitle.font = NSFont.boldSystemFont(ofSize: 16)
        editionTitle.textColor = NSColor(calibratedRed: 0.05, green: 0.34, blue: 0.18, alpha: 1.0)
        editionTitle.frame = NSRect(x: 380, y: 46, width: 320, height: 24)
        headerView.addSubview(editionTitle)

        let shortcutSubtitle = NSTextField(
            labelWithString: "F1 / Option+K: লেআউট চার্ট  •  Ctrl+Option+B (অথবা F12): মোড পরিবর্তন"
        )
        shortcutSubtitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        shortcutSubtitle.textColor = NSColor(calibratedWhite: 0.25, alpha: 1.0)
        shortcutSubtitle.frame = NSRect(x: 380, y: 20, width: 420, height: 20)
        headerView.addSubview(shortcutSubtitle)

        let splashBtn = NSButton(title: "🎨 About Canvas", target: self, action: #selector(splashClicked))
        splashBtn.bezelStyle = .rounded
        splashBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        splashBtn.frame = NSRect(x: 690, y: 28, width: 125, height: 32)
        splashBtn.autoresizingMask = [.minXMargin]
        headerView.addSubview(splashBtn)

        let keymapBtn = NSButton(title: "⌨️ Keymap (F1)", target: self, action: #selector(keymapClicked))
        keymapBtn.bezelStyle = .rounded
        keymapBtn.font = NSFont.boldSystemFont(ofSize: 12)
        keymapBtn.frame = NSRect(x: 822, y: 28, width: 140, height: 32)
        keymapBtn.autoresizingMask = [.minXMargin]
        headerView.addSubview(keymapBtn)

        content.addSubview(headerView)

        // 2. Dark Emerald / Metallic Control Strip (matching the Bijoy 52 TopBar)
        let controlStrip = NSView(frame: NSRect(x: 16, y: 496, width: 948, height: 44))
        controlStrip.autoresizingMask = [.width, .minYMargin]
        controlStrip.wantsLayer = true
        controlStrip.layer?.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.17, alpha: 1.0).cgColor
        controlStrip.layer?.cornerRadius = 6
        controlStrip.layer?.borderWidth = 1.2
        controlStrip.layer?.borderColor = NSColor(calibratedRed: 0.76, green: 0.65, blue: 0.40, alpha: 0.9).cgColor

        modeEmblemView.frame = NSRect(x: 14, y: 10, width: 24, height: 24)
        modeEmblemView.imageScaling = .scaleProportionallyUpOrDown
        modeEmblemView.image = loadAsset("emblem_english")
        controlStrip.addSubview(modeEmblemView)

        let modeLabel = NSTextField(labelWithString: "Active Keyboard Layout:")
        modeLabel.font = NSFont.boldSystemFont(ofSize: 12.5)
        modeLabel.textColor = NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.45, alpha: 1.0)
        modeLabel.frame = NSRect(x: 46, y: 12, width: 165, height: 20)
        controlStrip.addSubview(modeLabel)

        for mode in TypingMode.allCases {
            modePopUp.addItem(withTitle: mode.title)
        }
        modePopUp.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        modePopUp.target = self
        modePopUp.action = #selector(modePopUpChanged(_:))
        modePopUp.frame = NSRect(x: 214, y: 8, width: 225, height: 28)
        controlStrip.addSubview(modePopUp)

        hookStatusButton.bezelStyle = .rounded
        hookStatusButton.font = NSFont.boldSystemFont(ofSize: 12)
        hookStatusButton.target = self
        hookStatusButton.action = #selector(hookStatusClicked)
        hookStatusButton.frame = NSRect(x: 650, y: 8, width: 284, height: 28)
        hookStatusButton.autoresizingMask = [.minXMargin]
        controlStrip.addSubview(hookStatusButton)

        content.addSubview(controlStrip)

        // 3. Split Converter & Scratchpad Canvas (Left = Unicode Bangla, Right = SutonnyMJ Classic ANSI)
        let splitView = NSSplitView(frame: NSRect(x: 16, y: 56, width: 948, height: 428))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]

        let leftPane = buildEditorCard(
            badgeImage: loadAsset("emblem_unicode"),
            title: "ইউনিকোড বাংলা (Unicode Bangla Scratchpad)",
            textView: unicodeTextView,
            font: NSFont(name: "KohinoorBangla-Regular", size: 18) ?? NSFont.systemFont(ofSize: 18),
            copyAction: #selector(copyUnicodeClicked)
        )
        let rightPane = buildEditorCard(
            badgeImage: loadAsset("emblem_classic"),
            title: "বিজয় ক্লাসিক (SutonnyMJ ANSI — Ready for Microsoft Word)",
            textView: sutonnyTextView,
            font: NSFont(name: "SutonnyMJ", size: 21) ?? NSFont.systemFont(ofSize: 18),
            copyAction: #selector(copySutonnyClicked)
        )

        splitView.addSubview(leftPane)
        splitView.addSubview(rightPane)
        splitView.adjustSubviews()
        content.addSubview(splitView)

        // 4. Footer Bar
        let footerView = NSView(frame: NSRect(x: 16, y: 12, width: 948, height: 34))
        footerView.autoresizingMask = [.width, .maxYMargin]

        let clearBtn = NSButton(title: "🗑️ Clear Canvas", target: self, action: #selector(clearClicked))
        clearBtn.bezelStyle = .rounded
        clearBtn.frame = NSRect(x: 0, y: 2, width: 135, height: 28)
        footerView.addSubview(clearBtn)

        let footerNote = NSTextField(
            labelWithString: "✅ Microsoft Word-এ SutonnyMJ ফন্ট সিলেক্ট করে উপরে ভাসমান বিজয় বার থেকে 'Bijoy Classic' মোড নিন এবং সরাসরি টাইপ করুন।"
        )
        footerNote.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        footerNote.textColor = NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.12, alpha: 1.0)
        footerNote.frame = NSRect(x: 148, y: 6, width: 790, height: 20)
        footerNote.autoresizingMask = [.width]
        footerView.addSubview(footerNote)

        content.addSubview(footerView)

        let sample = "আমি বাংলায় গান গাই — দুররা এগ্রো ফার্ম (Durra Agro Farm)"
        unicodeTextView.string = sample
        sutonnyTextView.string = EncodingConverter.shared.convertUnicodeToSutonnyMJ(sample)
    }

    private func buildEditorCard(
        badgeImage: NSImage?,
        title: String,
        textView: NSTextView,
        font: NSFont,
        copyAction: Selector
    ) -> NSView {
        let card = NSView(frame: NSRect(x: 0, y: 0, width: 468, height: 428))
        card.autoresizingMask = [.width, .height]
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.93, alpha: 1.0).cgColor
        card.layer?.cornerRadius = 6
        card.layer?.borderWidth = 1.0
        card.layer?.borderColor = NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.22, alpha: 0.45).cgColor

        let badgeView = NSImageView(frame: NSRect(x: 10, y: 394, width: 20, height: 20))
        badgeView.imageScaling = .scaleProportionallyUpOrDown
        badgeView.image = badgeImage
        badgeView.autoresizingMask = [.minYMargin]
        card.addSubview(badgeView)

        let label = NSTextField(labelWithString: title)
        label.font = NSFont.boldSystemFont(ofSize: 12.5)
        label.textColor = NSColor(calibratedRed: 0.06, green: 0.24, blue: 0.16, alpha: 1.0)
        label.frame = NSRect(x: 34, y: 393, width: 325, height: 22)
        label.autoresizingMask = [.width, .minYMargin]
        card.addSubview(label)

        let copyBtn = NSButton(title: "📋 Copy", target: self, action: copyAction)
        copyBtn.bezelStyle = .rounded
        copyBtn.frame = NSRect(x: 368, y: 390, width: 90, height: 28)
        copyBtn.autoresizingMask = [.minXMargin, .minYMargin]
        card.addSubview(copyBtn)

        let scroll = NSScrollView(frame: NSRect(x: 8, y: 8, width: 452, height: 376))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        textView.frame = scroll.bounds
        textView.autoresizingMask = [.width, .height]
        textView.isRichText = false
        textView.font = font
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.delegate = self
        scroll.documentView = textView

        card.addSubview(scroll)
        return card
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshUIState),
            name: .bornoLipiModeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshUIState),
            name: .bornoLipiHookStateDidChange,
            object: nil
        )
    }

    @objc public func refreshUIState() {
        let mode = BijoyTypingEngine.shared.currentMode
        modePopUp.selectItem(at: mode.rawValue)

        switch mode {
        case .english:
            modeEmblemView.image = loadAsset("emblem_english")
        case .bijoyClassic:
            modeEmblemView.image = loadAsset("emblem_classic") ?? loadAsset("emblem_english")
        case .bijoyUnicode:
            modeEmblemView.image = loadAsset("emblem_unicode") ?? loadAsset("emblem_english")
        }

        if GlobalKeyboardHook.shared.isHookActive {
            hookStatusButton.title = "🟢 Universal Hook Active (Word & All Apps)"
        } else {
            hookStatusButton.title = "🔴 Click to Enable macOS Accessibility Hook"
        }
    }

    // MARK: - NSTextViewDelegate

    public func textDidChange(_ notification: Notification) {
        guard !isSyncingText, let edited = notification.object as? NSTextView else { return }
        isSyncingText = true
        defer { isSyncingText = false }

        if edited === unicodeTextView {
            sutonnyTextView.string = EncodingConverter.shared.convertUnicodeToSutonnyMJ(unicodeTextView.string)
        } else if edited === sutonnyTextView {
            unicodeTextView.string = EncodingConverter.shared.convertSutonnyMJToUnicode(sutonnyTextView.string)
        }
    }

    // MARK: - Actions

    @objc private func modePopUpChanged(_ sender: NSPopUpButton) {
        if let mode = TypingMode(rawValue: sender.indexOfSelectedItem) {
            BijoyTypingEngine.shared.currentMode = mode
        }
    }

    @objc private func hookStatusClicked() {
        if !GlobalKeyboardHook.shared.isHookActive {
            GlobalKeyboardHook.shared.requestAccessibilityPermissionPrompt()
        } else {
            _ = GlobalKeyboardHook.shared.tryInstallEventTap()
            refreshUIState()
        }
    }

    @objc private func keymapClicked() {
        onShowKeymap?()
    }

    @objc private func splashClicked() {
        onShowSplash?()
    }

    @objc private func copyUnicodeClicked() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(unicodeTextView.string, forType: .string)
    }

    @objc private func copySutonnyClicked() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sutonnyTextView.string, forType: .string)
    }

    @objc private func clearClicked() {
        unicodeTextView.string = ""
        sutonnyTextView.string = ""
        BijoyTypingEngine.shared.resetBuffer()
    }
}
