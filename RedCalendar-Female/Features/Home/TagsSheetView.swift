//
//  TagsSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

// The same sheet the comment editor is, for the same reasons. Its header was an `HStack` with a
// `Divider` under it where every other sheet in the app uses `navigationTitle` +
// `closeButtonToolbar`, so the title sat at its own weight and the rule was drawn whether or not
// content had reached it; its search box was a hand-rolled field where the platform has one; and
// its two next-stage buttons were a second hand-drawn bar at the bottom.
//
// The confirmation goes with them. Everything else on the day card applies on the tap that caused
// it, so "Готово" made a chosen tag the one edit that could be lost, and lost by the exit a user
// expects to be safe: swiping the sheet down. Saving on the way out covers both exits and frees
// the trailing corner for the `CloseButton`.
struct TagsSheetView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var isPresented: Bool

    @State private var searchText = ""
    @State private var selectedIds: Set<String> = []

    private let categorySpacing: CGFloat = 24
    private let chipCornerRadius: CGFloat = 8

    var body: some View {
        NavigationView {
            // Two screens, not one screen with things hidden. With no tags yet there is nothing
            // to search, nothing to edit and nothing a chip could say — a search field over an
            // empty page and a "Ничего не найдено" under it describe a failure, when what has
            // actually happened is that the user has not started. So the empty catalogue gets
            // the explanation and one thing to do, and the picker appears with the first tag.
            Group {
                if store.state.calendarState.userTags.isEmpty {
                    introduction
                } else {
                    picker
                }
            }
            .navigationTitle("Теги")
            .navigationBarTitleDisplayMode(.inline)
            // Saved before the dismissal rather than after it. `onDisappear` fires at the
            // *end* of the sheet's animation, so hanging the only save off it meant the day
            // card sat visible for the length of that animation still showing the old tags.
            .closeButtonToolbar {
                save()
                isPresented = false
            }
        }
        .onAppear { selectedIds = savedIds }
        // The swipe down never reaches the close button, and SwiftUI offers a sheet no hook for
        // the *start* of an interactive dismissal — so that exit is still caught here, a beat
        // later than the button's. Calling it twice on the button's path costs nothing: the
        // guard in `save` compares against state the reducer has already updated, so the second
        // call finds nothing to do.
        .onDisappear(perform: save)
    }

    // MARK: - Introduction

    // The onboarding slides' shape — glyph, title, a sentence of why — because this is the same
    // kind of moment: a part of the app the user has not met yet, explained where they arrived
    // rather than in a place they would have to go and find.
    private var introduction: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tag")
                .font(.system(size: 56))
                .foregroundColor(accent)

            VStack(spacing: 12) {
                Text("Отмечайте, как прошёл день")
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Тег — короткая пометка: симптом, настроение, лекарство. Дни с тегами видно в календаре, и со временем заметно, что повторяется из цикла в цикл.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // The accent is passed in rather than read from the asset: `PrimaryButton` fills
            // with it, and a fill has to answer to the theme the user chose.
            PrimaryButton("Новый тег", accent: accent) { /* next stage */ }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Picker

    private var picker: some View {
        tagsList
            // Always drawn rather than revealed by a pull: the list is grouped by category
            // with no headings to scroll back to, so search is how a long list is navigated
            // and not an occasional extra.
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск"
            )
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // No colour of their own: the sheet is handed `.tint(accentTheme.accent)`
                    // by the day card, and a `.foregroundColor` here would be the second red.
                    Button("Новый тег") { /* next stage */ }
                    Spacer()
                    Button("Редактировать") { /* next stage */ }
                }
            }
    }

    // MARK: - Tags list

    private var tagsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: categorySpacing) {
                ForEach(tagsByCategory) { group in
                    FlowLayout(data: group.tags, id: \.id, spacing: 8, rowSpacing: 8) { tag in
                        tagChip(tag, color: Color.tagColor(for: group.category))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DayDetailsMetrics.screenInset)
            .padding(.vertical, DayDetailsMetrics.screenInset)
        }
        .overlay {
            if tagsByCategory.isEmpty {
                // Only a search that matched nothing reaches this: an empty catalogue never
                // draws the list at all.
                Text("Ничего не найдено")
                    .foregroundColor(.secondary)
            }
        }
    }

    // Outlined when the tag is not on the day and filled when it is, rather than a difference in
    // shade: a chip is small enough that a step in density has no area to read in, and the day
    // card already draws an assigned tag as an outline of the category's colour.
    private func tagChip(_ tag: UserTagRecord, color: Color) -> some View {
        let isSelected = selectedIds.contains(tag.id)

        return Button {
            if isSelected {
                selectedIds.remove(tag.id)
            } else {
                selectedIds.insert(tag.id)
            }
        } label: {
            Text(tag.name ?? "")
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: chipCornerRadius)
                        .fill(isSelected ? color : Color.clear)
                )
                // `strokeBorder` rather than `stroke`, so the outline stays inside the chip's
                // own bounds instead of straddling them — that is what keeps the outlined and
                // the filled chip exactly the same size, and it is what the day card draws.
                .overlay(
                    RoundedRectangle(cornerRadius: chipCornerRadius)
                        .strokeBorder(color, lineWidth: 1)
                )
        }
    }

    // MARK: - Private Methods

    /// Grouped the way the day card sorts the same tags — by category, then by name — so a tag
    /// sits in the same place relative to its neighbours in both.
    private var tagsByCategory: [TagCategoryGroup] {
        let allTags = store.state.calendarState.userTags
        let filtered = searchText.isEmpty
            ? allTags
            : allTags.filter { $0.name?.localizedCaseInsensitiveContains(searchText) == true }

        return Dictionary(grouping: filtered) { $0.category ?? 0 }
            .sorted { $0.key < $1.key }
            .map { TagCategoryGroup(category: $0.key, tags: $0.value.sorted { ($0.name ?? "") < ($1.name ?? "") }) }
    }

    private var accent: Color {
        store.state.accentTheme.accent
    }

    private var savedIds: Set<String> {
        Set(store.state.calendarState.visibleDayTags[dayStamp] ?? [])
    }

    private func save() {
        guard selectedIds != savedIds else { return }
        // Sorted for deterministic storage — `Set` iteration order is random, and the row would
        // otherwise be rewritten with the same tags in a different order.
        store.send(.data(.setDayTags(dayStamp, selectedIds.sorted())))
    }
}

/// One category's tags, in the order they are drawn. A named type rather than the tuple this
/// was, because `ForEach` needs an identity and a key path cannot name a tuple's element.
private struct TagCategoryGroup: Identifiable {
    let category: Int
    let tags: [UserTagRecord]

    var id: Int { category }
}

#Preview {
    // The sheet takes its accent from whoever presents it, so the preview has to stand in for
    // the `.tint` the day card applies — without it the bottom bar renders in the system blue
    // and the preview lies about the one thing this screen's colour depends on.
    TagsSheetView(dayStamp: 2000, isPresented: .constant(true))
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

#Preview("Без тегов") {
    // The catalogue is empty until the first sync lands or the user makes a tag, and that is
    // the first thing most people will see here — so it gets a preview of its own.
    TagsSheetView(dayStamp: 2000, isPresented: .constant(true))
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
