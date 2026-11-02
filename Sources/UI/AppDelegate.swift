import Cocoa

/// Main application delegate coordinating the Menu Bar item (with official Ananda/Bijoy icons),
/// the Bijoy 52 TopBar, the Splash Canvas (`frmSplash`), the `F1`/`Option+K` Keymap overlay,
/// the Studio window, and the universal `GlobalKeyboardHook`.
public final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var floatingToolbar: FloatingToolbarWindow!
    private var splashCanvas: SplashCanvasWindow!
    private var keymapOverlay: KeymapOverlayWindow!
    private var studioController: StudioWindowController!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        floatingToolbar = FloatingToolbarWindow()
        splashCanvas = SplashCanvasWindow()
        keymapOverlay = KeymapOverlayWindow()
        studioController = StudioWindowController()

        floatingToolbar.onShowKeymap = { [weak self] in
            self?.keymapOverlay.toggleVisibility()
        }
        floatingToolbar.onShowStudio = { [weak self] in
            self?.studioController.showWindow()
        }
        studioController.onShowKeymap = { [weak self] in
            self?.keymapOverlay.toggleVisibility()
        }
        studioController.onShowSplash = { [weak self] in
            guard let self = self else { return }
            self.splashCanvas.center()
            self.splashCanvas.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        GlobalKeyboardHook.shared.onToggleKeymapRequested = { [weak self] in
            self?.keymapOverlay.toggleVisibility()
        }

        setupMenuBarExtra()
        registerNotifications()

        // Start universal keyboard hook (and Accessibility permission watchdog)
        GlobalKeyboardHook.shared.start(promptIfNeeded: true)

        // Show the authentic Bijoy 52 TopBar at the top of the screen
        floatingToolbar.orderFrontRegardless()

        // Show the Bijoy Bayanno Splash Canvas briefly on startup (just like Windows Bijoy 52 `frmSplash`)
        splashCanvas.showSplashBriefly(duration: 2.0)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        floatingToolbar.orderFrontRegardless()
        studioController.showWindow()
        return true
    }

    private func loadAsset(_ name: String, size: NSSize = NSSize(width: 16, height: 16)) -> NSImage? {
        let img: NSImage?
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            img = NSImage(contentsOf: url)
        } else {
            img = NSImage(contentsOfFile: "Resources/Assets/\(name).png")
        }
        img?.size = size
        return img
    }

    // MARK: - Menu Bar Extra (`NSStatusItem`)

    private func setupMenuBarExtra() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarBadge()

        let menu = NSMenu()

        let showTopBarItem = NSMenuItem(
            title: "Show / Hide BornoLipi TopBar",
            action: #selector(toggleFloatingTopBar),
            keyEquivalent: "t"
        )
        showTopBarItem.image = loadAsset("emblem_english")
        showTopBarItem.target = self
        menu.addItem(showTopBarItem)

        let showKeymapItem = NSMenuItem(
            title: "Show / Hide Keymap Layout (F1 / Option+K)",
            action: #selector(toggleKeymap),
            keyEquivalent: "k"
        )
        showKeymapItem.image = loadAsset("icon_keyboard")
        showKeymapItem.target = self
        menu.addItem(showKeymapItem)

        let openStudioItem = NSMenuItem(
            title: "Open BornoLipi Studio & Converter...",
            action: #selector(openStudio),
            keyEquivalent: "o"
        )
        openStudioItem.image = loadAsset("icon_tools")
        openStudioItem.target = self
        menu.addItem(openStudioItem)

        let showSplashItem = NSMenuItem(
            title: "About বর্ণলিপি বায়ান্নো Canvas...",
            action: #selector(showAboutCanvas),
            keyEquivalent: ""
        )
        showSplashItem.image = loadAsset("bornolipi_bayanno_logo")
        showSplashItem.target = self
        menu.addItem(showSplashItem)

        menu.addItem(.separator())

        for mode in TypingMode.allCases {
            let item = NSMenuItem(
                title: mode.title,
                action: #selector(selectModeFromMenu(_:)),
                keyEquivalent: ""
            )
            item.tag = mode.rawValue
            switch mode {
            case .english:
                item.image = loadAsset("emblem_english")
            case .bijoyClassic:
                item.image = loadAsset("emblem_classic")
            case .bijoyUnicode:
                item.image = loadAsset("emblem_unicode")
            }
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let permItem = NSMenuItem(
            title: "Verify / Grant macOS Accessibility Hook...",
            action: #selector(requestAccessibility),
            keyEquivalent: ""
        )
        permItem.image = loadAsset("icon_orb_active")
        permItem.target = self
        menu.addItem(permItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit বর্ণলিপি (BornoLipi)",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.image = loadAsset("icon_close")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarBadge),
            name: .bornoLipiModeDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarBadge),
            name: .bornoLipiHookStateDidChange,
            object: nil
        )
    }

    @objc private func updateMenuBarBadge() {
        let mode = BijoyTypingEngine.shared.currentMode
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageLeading

        switch mode {
        case .english:
            button.image = loadAsset("emblem_english")
        case .bijoyClassic:
            button.image = loadAsset("emblem_classic") ?? loadAsset("emblem_english")
        case .bijoyUnicode:
            button.image = loadAsset("emblem_unicode") ?? loadAsset("emblem_english")
        }
        button.title = " \(mode.shortBadge)"
    }

    // MARK: - Menu Actions

    @objc private func toggleFloatingTopBar() {
        if floatingToolbar.isVisible {
            floatingToolbar.orderOut(nil)
        } else {
            floatingToolbar.orderFrontRegardless()
        }
    }

    @objc private func toggleKeymap() {
        keymapOverlay.toggleVisibility()
    }

    @objc private func openStudio() {
        studioController.showWindow()
    }

    @objc private func showAboutCanvas() {
        splashCanvas.center()
        splashCanvas.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func selectModeFromMenu(_ sender: NSMenuItem) {
        if let mode = TypingMode(rawValue: sender.tag) {
            BijoyTypingEngine.shared.currentMode = mode
        }
    }

    @objc private func requestAccessibility() {
        GlobalKeyboardHook.shared.requestAccessibilityPermissionPrompt()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
