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
    /// Set by the trailing "+", separate from `editingTag` even though both present
    /// `NewTagSheetView` — one is a fresh tag, the other a record already in the catalogue, and
    /// `NewTagSheetView` itself tells the two apart by whether `editingTag` is `nil`. Sharing one
    /// flag would mean this screen inventing an empty record to stand in for "new".
    @State private var showNewTagSheet = false

    private let swatchSize: CGFloat = 14

    var body: some View {
        Group {
            if tagsByCategory.isEmpty {
                Text("TagList.Empty")
                    .foregroundColor(.secondary)
            } else {
                list
            }
        }
        .navigationTitle("TagList.Title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewTagSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // A sheet, not a push: the row it opens from is a tap on a tag, the same gesture that
        // opens it from the picker's long press, and that one is a sheet too.
        .sheet(isPresented: editingTagPresented) {
            if let editingTag {
                NewTagSheetView(isPresented: editingTagPresented, editingTag: editingTag)
                    .environmentObject(store)
                    .tint(accent)
            }
        }
        .sheet(isPresented: $showNewTagSheet) {
            NewTagSheetView(isPresented: $showNewTagSheet)
                .environmentObject(store)
                .tint(accent)
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
                Label("Common.Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        // On the row itself rather than on the whole `List`, for the reason
        // `NewTagSheetView.deleteSection` already gives: a `confirmationDialog` is a popover on
        // iPad, anchored to the exact view carrying the modifier, so hanging it off the whole
        // list pointed it at the list's own centre for every row instead of at the one being
        // deleted. `pendingDeletion == tag` (not merely non-nil) is what keeps that anchor
        // correct — every row's own copy of this modifier would otherwise open together the
        // moment any one of them set `pendingDeletion`.
        .confirmationDialog(
            "TagEditor.Delete.Confirm.Title",
            isPresented: deletionConfirmationPresented(for: tag),
            titleVisibility: .visible
        ) {
            Button("TagEditor.Delete.Button", role: .destructive, action: performDelete)
            Button("Common.Cancel", role: .cancel) {}
        } message: {
            Text(String.localized("TagEditor.Delete.Confirm.Message", tag.name ?? ""))
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

    private func deletionConfirmationPresented(for tag: UserTagRecord) -> Binding<Bool> {
        Binding(
            get: { pendingDeletion == tag },
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
                        authState: .authenticated(deviceId: "test"),
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
                        authState: .authenticated(deviceId: "test")
                    ),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}
