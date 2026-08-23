//
//  TagsListView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The catalogue as a plain table, pushed from Settings rather than presented as a sheet — this
/// is a place to manage tags that already exist, not the picker a day reaches for. Editing and
/// deleting both hand off to the same pieces the picker already uses: a tap opens the tag in
/// `NewTagSheetView`, and a swipe asks the same confirmation `NewTagSheetView`'s own delete row
/// does, in the same words, because it is the same consequence either way.
struct TagsListView: View {
    @EnvironmentObject var store: AppStore

    /// Doubles as the edit sheet's presentation state, the same one-flag shape
    /// `TagsSheetView.editingTag` uses and for the same reason: there is exactly one tag a tap
    /// can be editing at a time.
    @State private var editingTag: UserTagRecord?
    /// Set by the swipe action, cleared once the confirmation dialog it drives is answered either
    /// way. A row's own destructive button cannot delete on tap — that would make a slow swipe
    /// indistinguishable from a fast one — so the row only records *which* tag asked, and the
    /// dialog is what actually calls `deleteUserTag`.
    @State private var pendingDeletion: UserTagRecord?

    private let swatchSize: CGFloat = 14

    var body: some View {
        Group {
            if tagsByCategory.isEmpty {
                Text("Тегов пока нет")
                    .foregroundColor(.secondary)
            } else {
                list
            }
        }
        .navigationTitle("Теги")
        .navigationBarTitleDisplayMode(.inline)
        // A sheet, not a push: the row it opens from is a tap on a tag, the same gesture that
        // opens it from the picker's long press, and that one is a sheet too.
        .sheet(isPresented: editingTagPresented) {
            if let editingTag {
                NewTagSheetView(isPresented: editingTagPresented, editingTag: editingTag)
                    .environmentObject(store)
                    .tint(accent)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            // No section header: a category has no name anywhere in the app (see
            // `TagCategory`), and a table that named the four here would be the one screen that
            // broke that. The grouping itself, and each row's own swatch, are what carry the
            // colour instead.
            ForEach(tagsByCategory) { group in
                Section {
                    ForEach(group.tags, id: \.id, content: row)
                }
            }
        }
        .listStyle(.insetGrouped)
        // Named after the consequence, exactly as `NewTagSheetView.deleteSection` is, so the one
        // line a user reads before confirming says the same thing wherever it appears.
        .confirmationDialog(
            "Удалить тег?",
            isPresented: pendingDeletionPresented,
            titleVisibility: .visible
        ) {
            Button("Удалить тег", role: .destructive, action: performDelete)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("«\(pendingDeletion?.name ?? "")» пропадёт со всех дней, где он был проставлен.")
        }
    }

    private func row(_ tag: UserTagRecord) -> some View {
        Button {
            editingTag = tag
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.tagColor(for: tag.category))
                    .frame(width: swatchSize, height: swatchSize)

                Text(tag.name ?? "")
                    .foregroundColor(.primary)

                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            // No `role: .destructive` here — that role is what plays the row's own removal
            // animation the instant the button is tapped, whatever the closure does. Nothing
            // has been deleted yet at that point, only asked about, so the row collapsed and
            // then snapped back once the confirmation dialog appeared instead of anything being
            // gone. `.tint(.red)` gets back the same look without the built-in behaviour; the
            // row only animates out once, when `performDelete` actually removes the tag.
            Button {
                pendingDeletion = tag
            } label: {
                Label("Удалить", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    // MARK: - Private Methods

    /// Grouped by category, same order `TagsSheetView.tagsByCategory` sorts in, so a tag sits
    /// next to the same neighbours here that it does in the picker. A soft-deleted row (`name ==
    /// nil`) is dropped the same way the picker drops it — there is no hard delete to draw
    /// instead.
    private var tagsByCategory: [TagListSection] {
        let tags = store.state.calendarState.userTags.filter { $0.name != nil }

        return Dictionary(grouping: tags) { $0.category }
            .sorted { $0.key < $1.key }
            .map { entry in
                TagListSection(
                    category: entry.key,
                    tags: entry.value.sorted { ($0.name ?? "") < ($1.name ?? "") }
                )
            }
    }

    private var accent: Color {
        store.state.accentTheme.accent
    }

    private func performDelete() {
        guard let tag = pendingDeletion else { return }
        var deleted = tag
        deleted.name = nil
        deleted.updatedAt = nil
        store.send(.data(.deleteUserTag(deleted)))
        pendingDeletion = nil
    }

    private var editingTagPresented: Binding<Bool> {
        Binding(
            get: { editingTag != nil },
            set: { isPresented in
                guard !isPresented else { return }
                editingTag = nil
            }
        )
    }

    private var pendingDeletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                guard !isPresented else { return }
                pendingDeletion = nil
            }
        )
    }
}

/// One category's tags, in the order they are drawn. See `TagsSheetView.TagCategoryGroup` — same
/// shape, kept as a separate type because this screen groups full records, not picker rows.
private struct TagListSection: Identifiable {
    let category: Int
    let tags: [UserTagRecord]

    var id: Int { category }
}

#Preview {
    NavigationView {
        TagsListView()
            .tint(AccentTheme.coral.accent)
            .environmentObject(
                AppStore(
                    initialState: AppState(
                        authState: .authenticated(deviceId: "test", userDetails: nil),
                        calendarState: CalendarState(
                            userTags: [
                                UserTagRecord(id: "1", name: "Головная боль", category: 0),
                                UserTagRecord(id: "2", name: "Усталость", category: 0),
                                UserTagRecord(id: "3", name: "Раздражительность", category: 1),
                                UserTagRecord(id: "4", name: "Спокойствие", category: 1),
                                UserTagRecord(id: "5", name: "Тренировка", category: 2)
                            ]
                        )
                    ),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}

#Preview("Без тегов") {
    NavigationView {
        TagsListView()
            .tint(AccentTheme.coral.accent)
            .environmentObject(
                AppStore(
                    initialState: AppState(
                        authState: .authenticated(deviceId: "test", userDetails: nil)
                    ),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}
