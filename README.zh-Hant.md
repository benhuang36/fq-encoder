# FQEncoder

[English](README.md) · **繁體中文**

一款 macOS App,能把**任意**文字編碼成只由 7 個字母組成的字串 —— `F U C K Y O u` —— 並可還原。

它是常駐選單列的 App:可以打開編輯視窗手動編解碼,也可以讓它監看剪貼簿、自動轉換你複製的文字。

> 💻 想要 **Windows / Linux** 版?請見跨平台的 Tauri 版本:[**fq-encoder-tauri**](https://github.com/benhuang36/fq-encoder-tauri)(編碼格式相同 —— 同一組密碼在兩邊都能互相解碼)。

> 注意:`U`(大寫)和 `u`(小寫)是兩個**不同**的符號。完整的 7 符號字母表為 `F U C K Y O u`。

---

## 功能

- **Encode** — 把任意文字(含中日韓文字與 emoji)編成 7 符號字串。
- **Decode** — 把合法的編碼字串還原成原始文字。
- **密碼加持** — 在「設定」(⌘,)裡設定一組密碼後,相同文字在不同密碼下會產生完全不同的結果,也無法靠固定對照表讀出來。編碼與解碼必須使用相同密碼。
- **現代化 SwiftUI 介面** — 漸層 + 毛玻璃編輯器,輸入在上、輸出在下,一鍵複製。
- **常駐選單列** — 沒有 Dock 圖示(`LSUIElement`),常駐於右上角狀態列。
- **剪貼簿自動模式** — 複製純文字 → 自動編碼;複製編碼字串 → 自動解碼。內建防迴圈保護,不會跟自己打架。

---

## 編碼原理

編碼會把 UTF-8 位元組依序通過**三個階段**;解碼則反向還原。

```
編碼:  文字 → UTF-8 位元組 → ① keystream XOR → ② 擴散 → ③ base-7 打包 → 符號
解碼:  符號 → ③ 反打包 → ② 反擴散 → ① keystream XOR → 位元組 → 文字
```

### ① Keystream XOR(帶密碼)

每個位元組會跟一條由密碼推導出的 keystream 做 XOR,keystream 用 **SHA-256 counter 模式**產生(`block = SHA256(seed ‖ counter)`,`seed = SHA256("FQEncoder.v1:" + 密碼)`)。這會消除任何固定的逐字對照關係 —— 同一個位元組在不同密碼下編出來都不一樣。

### ② 雙向擴散(`O(n)`)

一遍前向、一遍後向的加法鏈接(mod 256),讓**每個輸出位元組都依賴每個輸入位元組**:

```
前向:  B[i] = A[i] + B[i-1]
後向:  C[i] = B[i] + C[i+1]
```

所以改動一個字元,輸出會大範圍跟著變(實測約 80% 的符號會翻動),相似的輸入也不會再共用輸出前綴。加法 mod 256 完全可逆,解碼時用減法還原即可。

### ③ Base-7 打包

字母表的 7 個符號對應數字 `0–6`:

| 符號 | `F` | `U` | `C` | `K` | `Y` | `O` | `u` |
|:----:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 數值 |  0  |  1  |  2  |  3  |  4  |  5  |  6  |

每個位元組(`0–255`)會寫成**剛好 3 位 base-7 數字**,因為 `7³ = 343 ≥ 256`(2 位只能涵蓋 `49` 種,不夠)。對位元組值 `v`:

```
d1 = (v / 49) % 7   # 最高位
d2 = (v /  7) % 7
d3 =  v       % 7   # 最低位     →  byte = d1×49 + d2×7 + d3
```

固定「每位元組 3 符號」讓解碼**無歧義、不需大數運算** —— 不必任意精度整數,每個位元組永遠是 3 個符號。

> **這是混淆,不是加密。** 此方案有密碼但未做認證(unauthenticated),而且內建或預設的密碼可從執行檔中還原。它的目的是讓一般人猜不透做法,不足以對抗有心的分析者。

### 如何驗證一個編碼字串

合法的編碼字串需依序通過(由便宜到昂貴):

1. **長度**是 3 的倍數 —— *必要但不充分*。
2. 每個字元都屬於 `F U C K Y O u`。
3. 反擴散、再用(正確密碼的)keystream XOR 後,位元組能組成合法的 UTF-8。

---

## 剪貼簿自動模式與防迴圈

從選單列啟用後,FQEncoder 會輪詢剪貼簿並轉換新複製的內容。若把結果寫回剪貼簿,很容易造成無限迴圈,因此有三層防護:

1. **變動偵測** — 只在 `NSPasteboard.changeCount` 真正前進時才反應。
2. **自寫防護** — 寫入自己的結果後,記下新的 change count 與寫入的字串,確保自己的輸出不會被重新處理。
3. **無變化防護** — 結果為空或與原內容相同時,絕不寫回。

---

## 建置

需要 macOS 14+、Xcode,以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)(`brew install xcodegen`)。

Xcode 專案由 [`project.yml`](project.yml) 產生(專案檔本身已被 git 忽略):

```sh
xcodegen generate
xcodebuild -project FQEncoder.xcodeproj -scheme FQEncoder -configuration Debug build
```

接著用 Xcode 開啟並執行:

```sh
open FQEncoder.xcodeproj
```

---

## 打包成可分發的 App

[`scripts/package.sh`](scripts/package.sh) 會產出一個已簽章、可傳輸的 `.app`,並壓縮進 `dist/`:

```sh
./scripts/package.sh                                    # → dist/FQEncoder.zip
OUTPUT=~/Desktop/FQEncoder.zip ./scripts/package.sh     # 自訂輸出位置
SIGN_IDENTITY="Apple Development: ..." ./scripts/package.sh   # 指定簽章身分
```

它會重新產生專案、以 **Release** 建置(Debug 建置綁定 DerivedData,無法搬到別台執行)、用你的 Apple Development 憑證簽章(找不到則退回 ad-hoc),再用 `ditto` 壓縮。

傳到另一台 Mac 後,解壓並執行一次以解除 Gatekeeper 隔離:

```sh
xattr -dr com.apple.quarantine /路徑/FQEncoder.app
```

接著就能開啟,並到選單列尋找圖示(FQEncoder 是常駐選單列 App,沒有 Dock 圖示)。剪貼簿監看使用 `NSPasteboard`,不需任何特殊權限。

---

## 圖示

App 圖示與選單列圖示都由 [`scripts/make_icons.swift`](scripts/make_icons.swift) 以 AppKit 直接繪製產生:

```sh
swift scripts/make_icons.swift
```

會輸出漸層「FQ」方形圖示(含 sparkle 點綴)與一個對應的 sparkle 選單列 template 圖示到 Asset Catalog。

---

## 專案結構

```
FQEncoder/
├── Codec.swift            # 帶密碼的三段式編解碼 + 驗證
├── ContentView.swift      # SwiftUI 編輯器介面
├── SettingsView.swift     # 密碼設定(⌘,)
├── ClipboardMonitor.swift # 防迴圈的剪貼簿監看
├── FQEncoderApp.swift      # @main:視窗 + MenuBarExtra + Settings
└── Assets.xcassets        # App 圖示與選單列圖示
project.yml                # XcodeGen 專案定義
scripts/
├── make_icons.swift       # 產生 App / 選單列圖示
└── package.sh             # 建置 + 簽章 + 打包可分發 App
```

---

## 授權

見 [LICENSE](LICENSE)。
