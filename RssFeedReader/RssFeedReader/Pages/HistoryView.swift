import SwiftUI

struct HistoryView: View {
    let historyEntries: [HistoryEntry]
    let onOpen: (HistoryEntry) -> Void
    let onDelete: (HistoryEntry) -> Void
    let onClearAll: () -> Void

    @State private var showClearConfirmation = false

    var body: some View {
        Group {
            if historyEntries.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("すべて削除") {
                    showClearConfirmation = true
                }
                .disabled(historyEntries.isEmpty)
            }
        }
        .confirmationDialog(
            "閲覧履歴をすべて削除しますか？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("すべて削除", role: .destructive) {
                onClearAll()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("閲覧履歴はありません")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        VStack {
            List {
                ForEach(historyEntries) { entry in
                    entryRow(entry)
                        .contextMenu {
                            Button("この履歴を削除", role: .destructive) {
                                onDelete(entry)
                            }
                        }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding()
    }

    @ViewBuilder
    private func entryRow(_ entry: HistoryEntry) -> some View {
        let canOpen = Self.isValidLink(entry.link)

        Button {
            onOpen(entry)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? "(no title)" : entry.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.feedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(Self.formatViewedAt(entry.viewedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
    }

    // MARK: - Helpers

    static func isValidLink(_ link: String) -> Bool {
        !link.isEmpty && URL(string: link) != nil
    }

    static func formatViewedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView(
        historyEntries: [
            HistoryEntry(
                stableID: "id-1",
                title: "Swift 6 の新機能について詳しく解説します",
                link: "https://swift.org/blog/swift6",
                feedName: "Swift.org",
                viewedAt: Date().addingTimeInterval(-3600)
            ),
            HistoryEntry(
                stableID: "id-1",
                title: "Swift 6 の新機能について詳しく解説します",
                link: "https://swift.org/blog/swift6",
                feedName: "Swift.org",
                viewedAt: Date().addingTimeInterval(-3600)
            ),
        ],
        onOpen: { _ in },
        onDelete: { _ in },
        onClearAll: {}
    )
    .frame(width: 600, height: 500)
}

#Preview("空の状態") {
    HistoryView(
        historyEntries: [],
        onOpen: { _ in },
        onDelete: { _ in },
        onClearAll: {}
    )
    .frame(width: 600, height: 500)
}
