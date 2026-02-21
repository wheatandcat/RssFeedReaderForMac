import SwiftUI

enum tab: Hashable {
    case rss
    case config
    case history
}

struct ContentView: View {
    @StateObject private var vm = FeedViewModel()
    @State private var selectedTab: tab = .rss
    @Environment(\.openURL) private var openURL

    var body: some View {
        TabView(selection: $selectedTab) {
            RssView(
                feeds: vm.feeds,
                items: vm.items,
                reload: vm.reload,
                onOpen: { item in vm.recordHistory(item) }
            )
            .tabItem {
                Label("Rss", systemImage: "gearshape")
            }
            .tag(tab.rss)

            SettingView(
                vm: vm
            )
            .tabItem {
                Label("設定", systemImage: "person.2")
            }
            .tag(tab.config)

            HistoryView(
                historyEntries: vm.historyEntries,
                onOpen: { entry in
                    if let url = URL(string: entry.link) {
                        openURL(url)
                    }
                    vm.recordHistory(FeedItem(
                        title: entry.title,
                        link: entry.link,
                        siteTitle: entry.feedName,
                        stableID: entry.stableID
                    ))
                },
                onDelete: { entry in vm.removeHistoryEntry(entry) },
                onClearAll: { vm.clearHistory() }
            )
            .tabItem {
                Label("履歴", systemImage: "clock")
            }
            .tag(tab.history)
        }
    }
}

#Preview {
    ContentView()
}
