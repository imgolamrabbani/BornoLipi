import Cocoa

/// Authentic Bijoy Bayanno (`Bijoy 52`) TopBar floating controller for macOS.
///
/// Modeled directly on the original Windows Bijoy 52 TopBar reference:
/// - Metallic dark-slate & deep-emerald beveled bar with gold/bronze outer trim (`#C4A464`)
/// - Left drag grip (`topbar_grip.png`)
/// - Original red-and-yellow **বিজয় বায়ান্নো** calligraphy wordmark (`topbar_wordmark.png`)
/// - Dynamic mode emblem (`ananda_emblem_24.png` / `mode_classic.png` / `mode_unicode.png`)
/// - Crisp white inset ComboBox (`English` / `Bijoy Classic` / `Unicode`)
/// - Original Bijoy 52 Keyboard Layout icon button (`icon_keyboard.png` — `F1`)
/// - Original Bijoy 52 Settings/Studio gear button (`icon_tools.png`)
/// - Original Bijoy 52 glossy Green Orb status/minimize button (`icon_dropdown_orb.png` / `icon_minimize_orb.png`)
/// - Original Bijoy 52 glossy Red `X` button (`icon_close.png`)
public final class FloatingToolbarWindow: NSPanel {

    public var onShowKeymap: (() -> Void)?
    public var onShowStudio: (() -> Void)?

    private let modeEmblemView = NSImageView(frame: .zero)
    private let modePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hookOrbButton = NSButton(frame: .zero)

    public init() {
        let width: CGFloat = 382
        let height: CGFloat = 34
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let originX = screenFrame.midX - (width / 2)
        let originY = screenFrame.maxY - height - 4

        let rect = NSRect(x: originX, y: originY, width: width, height: height)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        setupAuthenticBijoyTopBar()
        registerNotifications()
        refreshState()
    }

    private func loadAsset(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return NSImage(contentsOfFile: "Resources/Assets/\(name).png")
    }

    private func setupAuthenticBijoyTopBar() {
        let chassis = TopBarChassisView(frame: NSRect(x: 0, y: 0, width: 382, height: 34))
        chassis.autoresizingMask = [.width, .height]
        self.contentView = chassis

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // 1. Left Drag Grip (`topbar_grip.png`)
        let gripView = NSImageView(frame: NSRect(x: 6, y: 4, width: 10, height: 26))
        gripView.imageScaling = .scaleAxesIndependently
        gripView.image = loadAsset("topbar_grip")
        chassis.addSubview(gripView)

        // 2. Original BornoLipi Red & Yellow Wordmark (`topbar_wordmark.png`)
        let wordmarkView = NSImageView(frame: NSRect(x: 18, y: 5, width: 92, height: 24))
        wordmarkView.imageScaling = .scaleProportionallyUpOrDown
        wordmarkView.image = loadAsset("topbar_wordmark")
        wordmarkView.toolTip = "বর্ণলিপি বায়ান্নো — Universal macOS Keyboard (Drag bar to reposition)"
        chassis.addSubview(wordmarkView)

        // 3. Mode Emblem Icon (`emblem_english.png` / `emblem_classic.png` / `emblem_unicode.png`)
        modeEmblemView.frame = NSRect(x: 112, y: 5, width: 24, height: 24)
        modeEmblemView.imageScaling = .scaleProportionallyUpOrDown
        modeEmblemView.image = loadAsset("emblem_english")
        chassis.addSubview(modeEmblemView)

        // 4. White Inset ComboBox (`English` / `Bijoy Classic` / `Unicode`)
        let comboBg = NSView(frame: NSRect(x: 140, y: 5, width: 142, height: 24))
        comboBg.wantsLayer = true
        comboBg.layer?.backgroundColor = NSColor.white.cgColor
        comboBg.layer?.cornerRadius = 2.0
        comboBg.layer?.borderWidth = 1.0
        comboBg.layer?.borderColor = NSColor(calibratedWhite: 0.25, alpha: 1.0).cgColor

        modePopUp.frame = NSRect(x: 2, y: -1, width: 138, height: 25)
        modePopUp.isBordered = false
        modePopUp.font = NSFont(name: "Tahoma", size: 12) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        for mode in TypingMode.allCases {
            modePopUp.addItem(withTitle: mode.title)
        }
        if let cell = modePopUp.cell as? NSPopUpButtonCell {
            cell.arrowPosition = .arrowAtBottom
        }
        modePopUp.appearance = NSAppearance(named: .aqua)
        modePopUp.target = self
        modePopUp.action = #selector(modeSelectionChanged(_:))
        comboBg.addSubview(modePopUp)
        chassis.addSubview(comboBg)

        // 5. Keyboard Keymap Button (`icon_keyboard.png` — F1 / Option+K)
        let kbButton = makeIconButton(
            frame: NSRect(x: 286, y: 6, width: 22, height: 22),
            imageName: "icon_keyboard",
            tooltip: "Show/Hide Bijoy Keyboard Layout & যুক্তবর্ণ Chart (F1 or Option+K)",
            action: #selector(keymapClicked)
        )
        chassis.addSubview(kbButton)

        // 6. Studio & Converter Gear Button (`icon_tools.png`)
        let toolsButton = makeIconButton(
            frame: NSRect(x: 311, y: 6, width: 22, height: 22),
            imageName: "icon_tools",
            tooltip: "Open BornoLipi Studio, SutonnyMJ Converter & Splash Canvas",
            action: #selector(studioClicked)
        )
        chassis.addSubview(toolsButton)

        // 7. Glossy Green Orb Button (`icon_dropdown_orb.png` / Hook Status & Mode Cycle)
        hookOrbButton.frame = NSRect(x: 335, y: 6, width: 22, height: 22)
        hookOrbButton.isBordered = false
        hookOrbButton.bezelStyle = .regularSquare
        hookOrbButton.imagePosition = .imageOnly
        hookOrbButton.imageScaling = .scaleProportionallyUpOrDown
        hookOrbButton.target = self
        hookOrbButton.action = #selector(orbButtonClicked)
        chassis.addSubview(hookOrbButton)

        // 8. Glossy Red Close `X` Button (`icon_close.png`)
        let closeBtn = makeIconButton(
            frame: NSRect(x: 358, y: 7, width: 18, height: 20),
            imageName: "icon_close",
            tooltip: "Minimize TopBar to macOS Menu Bar (Click menu bar icon to restore)",
            action: #selector(closeTopBarClicked)
        )
        chassis.addSubview(closeBtn)
    }

    private func makeIconButton(frame: NSRect, imageName: String, tooltip: String, action: Selector) -> NSButton {
        let btn = NSButton(frame: frame)
        btn.isBordered = false
        btn.bezelStyle = .regularSquare
        btn.imagePosition = .imageOnly
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.image = loadAsset(imageName)
        btn.toolTip = tooltip
        btn.target = self
        btn.action = action
        return btn
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshState),
            name: .bornoLipiModeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshState),
            name: .bornoLipiHookStateDidChange,
            object: nil
        )
    }

    @objc public func refreshState() {
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
            hookOrbButton.image = loadAsset("icon_orb_active")
            hookOrbButton.alphaValue = 1.0
            hookOrbButton.toolTip = "🟢 Universal Hook Active! Click to cycle mode (Ctrl+Option+B / F12)"
        } else {
            hookOrbButton.image = loadAsset("icon_orb_inactive")
            hookOrbButton.alphaValue = 0.90
            hookOrbButton.toolTip = "⚠️ Click to Enable macOS Accessibility Permission for Universal Typing"
        }
    }

    @objc private func modeSelectionChanged(_ sender: NSPopUpButton) {
        if let mode = TypingMode(rawValue: sender.indexOfSelectedItem) {
            BijoyTypingEngine.shared.currentMode = mode
        }
    }

    @objc private func orbButtonClicked() {
        if !GlobalKeyboardHook.shared.isHookActive {
            GlobalKeyboardHook.shared.requestAccessibilityPermissionPrompt()
        } else {
            BijoyTypingEngine.shared.cycleMode()
        }
    }

    @objc private func keymapClicked() {
        onShowKeymap?()
    }

    @objc private func studioClicked() {
        onShowStudio?()
    }

    @objc private func closeTopBarClicked() {
        self.orderOut(nil)
    }
}

/// Custom-drawn metallic dark-slate and deep-emerald Bijoy Bayanno TopBar chassis with gold/bronze trim.
private final class TopBarChassisView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let outerRect = bounds
        // Outer dark-navy / gold-bronze border matching reference 2 (`media_1793599643141_ea431535.png`)
        NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.20, alpha: 0.98).setFill()
        outerRect.fill()

        let goldBorder = NSBezierPath(rect: outerRect.insetBy(dx: 0.5, dy: 0.5))
        NSColor(calibratedRed: 0.76, green: 0.65, blue: 0.40, alpha: 0.95).setStroke()
        goldBorder.lineWidth = 1.0
        goldBorder.stroke()

        // Inner metallic glossy slate/emerald gradient bar
        let innerRect = outerRect.insetBy(dx: 3.0, dy: 2.0)
        let topHalf = NSRect(x: innerRect.minX, y: innerRect.midY, width: innerRect.width, height: innerRect.height / 2.0)
        let bottomHalf = NSRect(x: innerRect.minX, y: innerRect.minY, width: innerRect.width, height: innerRect.height / 2.0)

        let topGrad = NSGradient(
            starting: NSColor(calibratedRed: 0.34, green: 0.43, blue: 0.40, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.16, green: 0.27, blue: 0.24, alpha: 1.0)
        )
        topGrad?.draw(in: topHalf, angle: -90)

        let botGrad = NSGradient(
            starting: NSColor(calibratedRed: 0.09, green: 0.18, blue: 0.16, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.11, alpha: 1.0)
        )
        botGrad?.draw(in: bottomHalf, angle: -90)

        // Subtle inner bevel line
        let innerStroke = NSBezierPath(rect: innerRect.insetBy(dx: 0.5, dy: 0.5))
        NSColor(calibratedRed: 0.28, green: 0.45, blue: 0.40, alpha: 0.7).setStroke()
        innerStroke.lineWidth = 1.0
        innerStroke.stroke()
    }
}
