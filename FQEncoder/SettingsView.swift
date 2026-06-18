import SwiftUI

struct SettingsView: View {
    @AppStorage(passwordDefaultsKey) private var password = ""
    @State private var reveal = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Group {
                        if reveal {
                            TextField("密碼", text: $password, prompt: Text("留空使用預設密碼"))
                        } else {
                            SecureField("密碼", text: $password, prompt: Text("留空使用預設密碼"))
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        reveal.toggle()
                    } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(reveal ? "隱藏密碼" : "顯示密碼")
                }
            } header: {
                Text("編碼密碼")
            } footer: {
                Text("密碼會混入編碼結果，讓相同文字在不同密碼下產生完全不同的字串。\n編碼與解碼必須使用相同的密碼，否則無法還原。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
    }
}

#Preview {
    SettingsView()
}
