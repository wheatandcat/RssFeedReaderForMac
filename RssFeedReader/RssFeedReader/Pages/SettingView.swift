import AppKit
import SwiftUI

private enum OllamaStatus {
    case checking
    case connected
    case disconnected
    case launching
}

struct SettingView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var newURL: String = ""
    @State private var ollamaStatus: OllamaStatus = .checking

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                Section("") {}
                Section("ラベル設定") {
                    // Ollama ステータス
                    ollamaStatusView.listRowSeparator(.hidden)

                    // ラベル再取得
                    Button("ラベルを再取得（デバッグ用）") {
                        vm.relabelAll()
                    }
                    .foregroundStyle(.orange).padding(.bottom, 16)
                }
                Section("RSSフィード") {
                    // URL追加UI
                    HStack {
                        TextField("RSS URL を追加", text: $newURL)
                            .textFieldStyle(.roundedBorder)

                        Button("追加") {
                            let t = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            vm.feeds.append(
                                Feed(
                                    url: t,
                                    limit: nil,
                                    pubDateLimitDay: nil,
                                    show: true
                                )
                            )
                            newURL = ""
                        }
                    }.padding(.bottom, 16)

                    ForEach($vm.feeds, id: \.self) { $feed in
                        HStack {
                            Toggle(isOn: $feed.show) {
                                Text(feed.url)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }.toggleStyle(.switch)
                        }.padding(.horizontal, 8)
                    }
                    .onDelete { vm.feeds.remove(atOffsets: $0) }
                }.listRowSeparator(.hidden)
            }.listStyle(.plain)
        }

        .task { await checkOllama() }
    }

    private var ollamaStatusView: some View {
        HStack(spacing: 10) {
            switch ollamaStatus {
            case .checking:
                ProgressView().controlSize(.small)
                Text("Ollama 確認中…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .connected:
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                Text("Ollama 起動中")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            case .disconnected:
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                Text("Ollama 未起動")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Button("起動する") {
                    Task { await launchOllama() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            case .launching:
                ProgressView().controlSize(.small)
                Text("Ollama 起動中…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await checkOllama() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .shadow(radius: 1)
        )
    }

    private func launchOllama() async {
        ollamaStatus = .launching
        let ollamaAppURL = URL(fileURLWithPath: "/Applications/Ollama.app")
        if FileManager.default.fileExists(atPath: ollamaAppURL.path) {
            NSWorkspace.shared.open(ollamaAppURL)
        } else {
            // アプリが見つからない場合は ollama serve をバックグラウンドで実行
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
            process.arguments = ["serve"]
            try? process.run()
        }
        // 起動を待ってから再チェック
        try? await Task.sleep(for: .seconds(3))
        await checkOllama()
    }

    private func checkOllama() async {
        ollamaStatus = .checking
        guard let url = URL(string: "http://localhost:11434") else {
            ollamaStatus = .disconnected
            return
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 3)
            request.httpMethod = "GET"
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) {
                ollamaStatus = .connected
            } else {
                ollamaStatus = .disconnected
            }
        } catch {
            ollamaStatus = .disconnected
        }
    }
}

#Preview {
    SettingView(vm: FeedViewModel())
}
