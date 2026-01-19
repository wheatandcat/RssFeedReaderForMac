import SwiftUI

enum tab: Hashable {
    case rss
    case config
}


struct ContentView: View {
    @StateObject private var vm = FeedViewModel()
    @State private var selectedTab: tab = .rss

    var body: some View {
        TabView(selection: $selectedTab) {
            RssView(
                items: vm.items,
                reload: vm.reload,
            )
            .tabItem {
                Label("Rss", systemImage: "gearshape")
            }
            .tag(tab.rss)
            SettingView(
                vm:vm
            )
            .tabItem {
                Label("Config", systemImage: "person.2")
            }
            .tag(tab.config)
        }
    }
}

#Preview {
    ContentView()
}

