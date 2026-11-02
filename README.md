<p align="center">
  <img src="Resources/Assets/bornolipi_bayanno_logo.png" width="190" alt="বর্ণলিপি বায়ান্নো — BornoLipi Logo" />
</p>

<h1 align="center">বর্ণলিপি বায়ান্নো (BornoLipi) — Universal Bangla Keyboard for macOS</h1>

<p align="center">
  <b>Native macOS Bijoy Classic (<code>SutonnyMJ</code>) & Unicode Bangla Keyboard Engine</b><br/>
  Featuring a custom-crafted Metallic TopBar, Original Shaheed Minar Splash Canvas, 431 <code>&lt;Juk&gt;</code> Conjunct Engine, <code>F1</code> Keymap Overlay, and Bidirectional Converter Studio.
</p>

<p align="center">
  <img src="Resources/Assets/bornolipi_splash_canvas.png" width="460" alt="BornoLipi Splash Canvas" />
</p>

---

## ✨ Key Features

- **Classic Metallic TopBar (`FloatingToolbarWindow`)**:
  - Inspired by the classic desktop Bangla keyboard bar—metallic dark-slate and emerald chassis with gold-bronze bevel trim, custom red-and-yellow **বর্ণলিপি বায়ান্নো** calligraphy wordmark (`topbar_wordmark.png`), custom mode emblems (`emblem_english.png`, `emblem_classic.png`, `emblem_unicode.png`), crisp white mode selector (`English` / `Bijoy Classic (SutonnyMJ)` / `Unicode (Bangla)`), tactile keyboard layout button, gear button, glossy status orb, and close button.
  - Built as a non-activating macOS `NSPanel` (`.nonactivatingPanel`) so switching modes or opening the keymap **never steals cursor focus from Microsoft Word**.
- **100% Authentic Bijoy Classic (`SutonnyMJ`) Engine**:
  - Driven by all **431 `<Juk>` conjunct & ligature rules** (`BijoyClassic.xml`), including contextual vowel sign positioning (`Ky -> Kz`, `K~ -> K‚`, `K„ -> K…`), word-initial `†`/`ˆ` variants (` ‡ -> †`), independent vowels via the link key `g` (`g+f -> Av`, `g+d -> B`, `g+c -> G`), and 2- and 3-consonant conjuncts (`ক্ষ`, `জ্ঞ`, `ন্ত্র`, `স্ত্র`, `দ্ধ`, `ঞ্চ`, etc.).
- **Native Bijoy Unicode Engine (`Unicode.xml`)**:
  - Full support for `Delay` pre-base vowel signs (`ি`, `ে`, `ৈ`), `DeInc1`/`DeInc2` conjunct cluster spanning (`্`, `্র`, `্য`), and `MoveL` রেফ (`র্`) reordering.
- **Instant Keymap & যুক্তবর্ণ Guide (`F1` or `Option + K`)**:
  - Press **`F1`** or **`Option + K`** anywhere on macOS to toggle the Bijoy Bangla Keyboard layout chart and searchable `যুক্তবর্ণ` cheat sheet.
- **BornoLipi Studio & Bidirectional Converter**:
  - Includes the custom **বর্ণলিপি বায়ান্নো** banner and sage-green canvas (`StudioWindowController` & `SplashCanvasWindow`) with live two-way conversion between **Unicode Bangla** and **SutonnyMJ (Bijoy Classic ANSI)**.

---

## ⌨️ Global Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| **`F1`** or **`Option + K`** | Show / Hide the **Bijoy Keyboard Layout & যুক্তবর্ণ Guide** from any app |
| **`Ctrl + Option + B`** or **`F12`** | Cycle typing mode: **English** → **Bijoy Classic (`SutonnyMJ`)** → **Unicode (Bangla)** |
| **`Ctrl + Option + V`** | Toggle directly between **English** and **Unicode (Bangla)** |

---

## 📂 Repository Architecture

```text
BornoLipi/
├── Makefile
├── build.sh
├── README.md
├── Resources/
│   ├── Info.plist
│   ├── AppIcon.icns                     # Custom-crafted BornoLipi calligraphy macOS icon
│   ├── BijoyClassic.xml                 # 431 Bijoy Classic (SutonnyMJ) Juk & Key rules
│   ├── Unicode.xml                      # Bijoy Unicode layout & Delay/DeInc/MoveL rules
│   ├── bijoy_keymap.png                 # Bijoy keyboard layout reference chart
│   └── Assets/                          # 100% Original Vector Artwork & Tactile Icons
│       ├── bornolipi_bayanno_logo.png
│       ├── bornolipi_header_banner.png
│       ├── bornolipi_splash_canvas.png
│       ├── emblem_classic.png
│       ├── emblem_english.png
│       ├── emblem_unicode.png
│       ├── icon_close.png
│       ├── icon_keyboard.png
│       ├── icon_orb_active.png
│       ├── icon_orb_inactive.png
│       ├── icon_tools.png
│       ├── topbar_grip.png
│       └── topbar_wordmark.png
└── Sources/
    ├── main.swift
    ├── Models/
    │   └── KeyboardLayoutModel.swift
    ├── Engine/
    │   ├── BijoyLayoutParser.swift
    │   ├── BijoyTypingEngine.swift
    │   ├── EncodingConverter.swift
    │   └── GlobalKeyboardHook.swift
    └── UI/
        ├── AppDelegate.swift
        ├── FloatingToolbarWindow.swift
        ├── SplashCanvasWindow.swift
        ├── KeymapOverlayWindow.swift
        └── StudioWindowController.swift
```

---

## 🚀 Build & Installation

```bash
git clone https://github.com/imgolamrabbani/BornoLipi.git
cd BornoLipi
make install
open /Applications/BornoLipi.app
```

### Granting macOS Accessibility Permission
To allow `BornoLipi.app` to intercept and type Bangla keystrokes universally across Microsoft Word, browsers, and Notes:
1. Open **System Settings → Privacy & Security → Accessibility**.
2. Toggle **ON** **`BornoLipi` (`/Applications/BornoLipi.app`)**.
3. The glossy orb on the TopBar automatically turns bright green (`🟢 Universal Hook Active`) within 1 second—no restart required.
