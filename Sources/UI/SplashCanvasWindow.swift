import Cocoa

/// Original BornoLipi Splash & About Canvas Window (`bornolipi_splash_canvas.png`).
///
/// Inspired by the classic beveled sage-grey Shaheed Minar splash screen, rendered with 100% original
/// vector artwork for **বর্ণলিপি বায়ান্নো ম্যাক (BornoLipi macOS Edition)**.
public final class SplashCanvasWindow: NSPanel {

    public init() {
        let width: CGFloat = 520
        let height: CGFloat = 520
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )

        super.init(
            contentRect: rect,
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )

        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isFloatingPanel = true
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.backgroundColor = NSColor(calibratedRed: 0.69, green: 0.72, blue: 0.70, alpha: 1.0)
        self.hasShadow = true

        setupCanvas()
    }

    private func setupCanvas() {
        guard let content = self.contentView else { return }
        content.wantsLayer = true

        let canvasImageView = NSImageView(frame: content.bounds)
        canvasImageView.autoresizingMask = [.width, .height]
        canvasImageView.imageScaling = .scaleAxesIndependently
        if let url = Bundle.main.url(forResource: "bornolipi_splash_canvas", withExtension: "png") {
            canvasImageView.image = NSImage(contentsOf: url)
        } else if let img = NSImage(contentsOfFile: "Resources/Assets/bornolipi_splash_canvas.png") {
            canvasImageView.image = img
        }
        content.addSubview(canvasImageView)
    }

    public func showSplashBriefly(duration: TimeInterval = 2.0) {
        self.center()
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.45
                self.animator().alphaValue = 0.0
            }, completionHandler: {
                self.orderOut(nil)
                self.alphaValue = 1.0
            })
        }
    }
}
