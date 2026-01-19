import SwiftUI

struct SettingView: View {
    let vm: FeedViewModel
    @State private var newURL: String = ""

    var body: some View {
        VStack(spacing: 12) {
            // URL追加UI
            HStack {
                TextField("RSS URL を追加", text: $newURL)
                    .textFieldStyle(.roundedBorder)

                Button("追加") {
                    let t = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    vm.feeds.append(
                        Feed(url: t, limit: nil)
                    )
                    newURL = ""
                }
            }

            // 登録済みURL一覧
            List {
                Section("RSSフィード") {
                    ForEach(vm.feeds, id: \.self) { feed in
                        Text(feed.url)
                    }
                    .onDelete { vm.feeds.remove(atOffsets: $0) }
                }
            }
        }
        .padding()
    }
}

#Preview {
    SettingView(
        vm: FeedViewModel()
    )
}
