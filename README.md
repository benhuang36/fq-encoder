# FQEncoder

A reversible text codec for macOS that encodes **any** string into just 7 letters — `F U C K Y O u` — and back.

It ships as a menu-bar app: open the editor to encode/decode by hand, or let it watch your clipboard and transform copied text automatically.

> Note: `U` (uppercase) and `u` (lowercase) are two **distinct** symbols. The 7-symbol alphabet is `F U C K Y O u`.

---

## Features

- **Encode** — turn arbitrary text (including CJK and emoji) into the 7-symbol alphabet.
- **Decode** — turn a valid encoded string back into the original text.
- **Modern SwiftUI UI** — gradient + frosted-glass editor, input on top, output below, with one-click copy.
- **Menu-bar resident** — no Dock icon (`LSUIElement`), lives in the status bar.
- **Automatic clipboard mode** — copy plain text → it's encoded; copy an encoded string → it's decoded. With loop-safe guards so it never fights itself.

---

## How the encoding works

The codec is **per-byte, fixed-width base-7 conversion**.

The alphabet has 7 symbols, mapped to digits `0–6`:

| Symbol | `F` | `U` | `C` | `K` | `Y` | `O` | `u` |
|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Value  |  0  |  1  |  2  |  3  |  4  |  5  |  6  |

The input is taken as **UTF-8 bytes**. Each byte (`0–255`) is written as exactly **3 base-7 digits**, because `7³ = 343 ≥ 256` (2 digits would only cover `49` values — not enough).

For a byte value `v`:

```
d1 = (v / 49) % 7      # most significant
d2 = (v /  7) % 7
d3 =  v       % 7      # least significant
```

**Example** — the letter `a` (byte `97`):

```
97 = 1×49 + 6×7 + 6   →  digits (1, 6, 6)  →  U u u
```

Decoding reverses it, reading 3 symbols at a time:

```
byte = d1×49 + d2×7 + d3
```

Then the reconstructed byte sequence is decoded back as UTF-8.

### Why fixed 3-symbols-per-byte?

A "true" base conversion of the whole byte stream would be slightly shorter (`log₂256 / log₂7 ≈ 2.85×` vs the fixed `3×`), but it needs arbitrary-precision integer math and careful handling of leading zeros. The fixed-width scheme trades a little size for **unambiguous, dependency-free decoding** — every byte is exactly 3 symbols, full stop.

### Validating an encoded string

A valid encoded string must pass three checks (in order of cost):

1. **Length** is a multiple of 3 — *necessary, but not sufficient*.
2. Every character is one of `F U C K Y O u`.
3. The resulting bytes form valid UTF-8.

---

## Clipboard auto mode & loop protection

When enabled from the menu bar, FQEncoder polls the pasteboard and transforms new copies. Encoding the clipboard and writing the result back could easily cause an infinite loop, so three layers prevent it:

1. **Change detection** — only react when `NSPasteboard.changeCount` actually advances.
2. **Self-write guard** — after writing our own result, record the new change count and the exact string written, so our own output is never re-processed.
3. **No-op guard** — never write back an empty or unchanged result.

---

## Build

Requires macOS 14+, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

The Xcode project is generated from [`project.yml`](project.yml) (it is git-ignored):

```sh
xcodegen generate
xcodebuild -project FQEncoder.xcodeproj -scheme FQEncoder -configuration Debug build
```

Then open it in Xcode and run:

```sh
open FQEncoder.xcodeproj
```

---

## Project layout

```
FQEncoder/
├── Codec.swift            # base-7 encode/decode + validation
├── ContentView.swift      # SwiftUI editor UI
├── ClipboardMonitor.swift # loop-safe clipboard watcher
└── FQEncoderApp.swift      # @main app: window + MenuBarExtra
project.yml                # XcodeGen project definition
```

---

## License

See [LICENSE](LICENSE).
