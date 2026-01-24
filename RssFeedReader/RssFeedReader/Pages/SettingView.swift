import SwiftUI

struct SettingView: View {
    @ObservedObject var vm: FeedViewModel
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
                        Feed(
                            url: t,
                            limit: nil,
                            pubDateLimitDay: nil,
                            show: true                            
                        )
                    )
                    newURL = ""
                }
            }

            // 登録済みURL一覧
            List {
                Section("RSSフィード") {
                    ForEach($vm.feeds, id: \.self) { $feed in
                        HStack {
                            Toggle(isOn: $feed.show) {
                                Text(feed.url)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }.toggleStyle(.switch)
                        }
                        
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
