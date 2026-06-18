# FQEncoder

**English** · [繁體中文](README.zh-Hant.md)

A reversible text codec for macOS that encodes **any** string into just 7 letters — `F U C K Y O u` — and back.

It ships as a menu-bar app: open the editor to encode/decode by hand, or let it watch your clipboard and transform copied text automatically.

> Note: `U` (uppercase) and `u` (lowercase) are two **distinct** symbols. The 7-symbol alphabet is `F U C K Y O u`.

---

## Features

- **Encode** — turn arbitrary text (including CJK and emoji) into the 7-symbol alphabet.
- **Decode** — turn a valid encoded string back into the original text.
- **Password-keyed** — an optional password (set in Settings, ⌘,) keys the encoding, so the same text produces a completely different result per password, and you can't read it off a fixed substitution table. Encoding and decoding must use the same password.
- **Modern SwiftUI UI** — gradient + frosted-glass editor, input on top, output below, with one-click copy.
- **Menu-bar resident** — no Dock icon (`LSUIElement`), lives in the status bar.
- **Automatic clipboard mode** — copy plain text → it's encoded; copy an encoded string → it's decoded. With loop-safe guards so it never fights itself.

---

## How the encoding works

Encoding runs the UTF-8 bytes through **three stages**; decoding reverses them.

```
encode:  text → UTF-8 bytes → ① keystream XOR → ② diffusion → ③ base-7 pack → symbols
decode:  symbols → ③ unpack → ② un-diffuse → ① keystream XOR → bytes → text
```

### ① Keystream XOR (keyed)

Each byte is XOR'd with a keystream derived from the password via **SHA-256 in counter mode** (`block = SHA256(seed ‖ counter)`, `seed = SHA256("FQEncoder.v1:" + password)`). This removes any stable per-character mapping — the same byte encodes differently depending on the password.

### ② Bidirectional diffusion (`O(n)`)

A forward then backward additive chain (mod 256) makes **every output byte depend on every input byte**:

```
forward:   B[i] = A[i] + B[i-1]
backward:  C[i] = B[i] + C[i+1]
```

So a one-character change avalanches across most of the output (~80% of symbols flip in practice), and similar inputs no longer share an output prefix. Addition mod 256 is exactly reversible, so decoding undoes it with subtraction.

### ③ Base-7 packing

The alphabet's 7 symbols map to digits `0–6`:

| Symbol | `F` | `U` | `C` | `K` | `Y` | `O` | `u` |
|:------:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Value  |  0  |  1  |  2  |  3  |  4  |  5  |  6  |

Each byte (`0–255`) becomes exactly **3 base-7 digits**, because `7³ = 343 ≥ 256` (2 digits would only cover `49` values). For a byte value `v`:

```
d1 = (v / 49) % 7   # most significant
d2 = (v /  7) % 7
d3 =  v       % 7   # least significant     →  byte = d1×49 + d2×7 + d3
```

Fixed 3-symbols-per-byte keeps decoding **unambiguous and dependency-free** — no big-number math, every byte is exactly 3 symbols.

> **This is obfuscation, not encryption.** The scheme is keyed but unauthenticated, and an embedded/default key can be recovered from the binary. Its job is to stop casual readers from guessing the method, not to withstand a determined analyst.

### Validating an encoded string

A valid encoded string must pass, in order of cost:

1. **Length** is a multiple of 3 — *necessary, but not sufficient*.
2. Every character is one of `F U C K Y O u`.
3. After un-diffusing and the keystream XOR (with the correct password), the bytes form valid UTF-8.

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

## Packaging a distributable app

[`scripts/package.sh`](scripts/package.sh) produces a signed, transferable `.app` zipped into `dist/`:

```sh
./scripts/package.sh                                    # → dist/FQEncoder.zip
OUTPUT=~/Desktop/FQEncoder.zip ./scripts/package.sh     # custom output path
SIGN_IDENTITY="Apple Development: ..." ./scripts/package.sh   # pick a signing identity
```

It regenerates the project, builds **Release** (a Debug build is tied to DerivedData and won't run elsewhere), code-signs with your Apple Development identity (ad-hoc fallback if none is found), and zips it with `ditto`.

On another Mac, unzip and clear the Gatekeeper quarantine once:

```sh
xattr -dr com.apple.quarantine /path/to/FQEncoder.app
```

Then launch it and look for the icon in the menu bar (FQEncoder is a menu-bar resident app with no Dock icon). Clipboard monitoring uses `NSPasteboard` and needs no special permission.

---

## Project layout

```
FQEncoder/
├── Codec.swift            # keyed 3-stage encode/decode + validation
├── ContentView.swift      # SwiftUI editor UI
├── SettingsView.swift     # password settings (⌘,)
├── ClipboardMonitor.swift # loop-safe clipboard watcher
└── FQEncoderApp.swift      # @main app: window + MenuBarExtra + Settings
project.yml                # XcodeGen project definition
scripts/package.sh         # build + sign + zip a distributable app
```

---

## License

See [LICENSE](LICENSE).
