import SwiftUI

struct ContentView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var errorMessage: String?
    @State private var didCopy = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.30, blue: 0.86),
                         Color(red: 0.78, green: 0.34, blue: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header

                editorCard(
                    title: "輸入",
                    systemImage: "square.and.pencil",
                    text: $input,
                    editable: true,
                    placeholder: "輸入任何文字，或貼上編碼字串…"
                )

                actionButtons

                editorCard(
                    title: "輸出",
                    systemImage: "sparkles",
                    text: $output,
                    editable: false,
                    placeholder: "結果會顯示在這裡"
                )

                footer
            }
            .padding(22)
        }
        .frame(minWidth: 460, minHeight: 560)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 1) {
                Text("FQEncoder")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("把文字變成 F U C K Y O u")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
    }

    private func editorCard(title: String, systemImage: String, text: Binding<String>,
                            editable: Bool, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
                if !editable && !text.wrappedValue.isEmpty {
                    Button {
                        copyOutput()
                    } label: {
                        Label(didCopy ? "已複製" : "複製", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14, design: editable ? .default : .monospaced))
                        .foregroundStyle(.secondary)
                        // Match the TextEditor's text origin: outer padding (13/6)
                        // plus NSTextView's default 5pt lineFragmentPadding on the left.
                        .padding(.leading, 13 + 5)
                        .padding(.trailing, 13)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .focused($inputFocused)
                    .disabled(!editable)
                    .font(.system(size: 14, design: editable ? .default : .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button(action: runEncode) {
                Label("Encode", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button(action: runDecode) {
                Label("Decode", systemImage: "arrow.up.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
        .controlSize(.large)
        .buttonStyle(GlassButtonStyle())
    }

    private var footer: some View {
        Group {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Encode 任意文字 · Decode 只接受 F U C K Y O u")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func runEncode() {
        errorMessage = nil
        output = Codec.encode(input)
    }

    private func runDecode() {
        errorMessage = nil
        do {
            output = try Codec.decode(input.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            output = ""
            errorMessage = error.localizedDescription
        }
    }

    private func copyOutput() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(output, forType: .string)
        ClipboardMonitor.shared.noteAppWrote(output)
        withAnimation { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { didCopy = false }
        }
    }
}

/// Frosted-glass styled button to keep the modern, non-engineering look.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.22))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
