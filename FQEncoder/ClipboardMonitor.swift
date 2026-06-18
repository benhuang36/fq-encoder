import AppKit
import Combine

/// Watches the system pasteboard and, when enabled, automatically transforms
/// copied text: plain text is encoded, an encoded string is decoded.
///
/// Infinite-loop protection works on three layers:
///  1. We only react when `NSPasteboard.changeCount` advances (a genuine copy).
///  2. After we write our own result, we record the new change count and the
///     exact string we wrote, so our own write is never re-processed.
///  3. If the transform would produce the same string (or empty), we skip it.
final class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    @Published var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    /// Last text the monitor processed, shown in the menu for feedback.
    @Published private(set) var lastAction: String = "尚未處理任何內容"

    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastWrittenString: String?

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    /// Call this whenever the app itself writes to the pasteboard (e.g. the
    /// "Copy" button) so the monitor doesn't treat it as fresh user input.
    func noteAppWrote(_ string: String) {
        lastWrittenString = string
        lastChangeCount = pasteboard.changeCount
    }

    private func start() {
        lastChangeCount = pasteboard.changeCount
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        // Layer 1: only act on a genuine new copy.
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Layer 2: ignore content we wrote ourselves.
        if text == lastWrittenString { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: String
        let label: String
        if Codec.looksEncoded(trimmed) {
            guard let decoded = try? Codec.decode(trimmed) else { return }
            result = decoded
            label = "已解碼"
        } else {
            result = Codec.encode(text)
            label = "已編碼"
        }

        // Layer 3: never write an unchanged or empty result.
        guard !result.isEmpty, result != text else { return }

        pasteboard.clearContents()
        pasteboard.setString(result, forType: .string)
        noteAppWrote(result)

        let preview = text.prefix(24).replacingOccurrences(of: "\n", with: " ")
        lastAction = "\(label)：\(preview)\(text.count > 24 ? "…" : "")"
    }
}
