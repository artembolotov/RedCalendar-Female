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
    @State private var showNewTagSheet = false

    private let categorySpacing: CGFloat = 24

    var body: some View {
        NavigationView {
            // Two screens, not one screen with things hidden. With no tags yet there is nothing
            // to search, nothing to edit and nothing a chip could say — a search field over an
            // empty page and a "Ничего не найдено" under it describe a failure, when what has
            // actually happened is that the user has not started. So the empty catalogue gets
            // the explanation and one thing to do, and the picker appears with the first tag.
            Group {
                if availableTags.isEmpty {
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
            // A sheet over this one rather than a push, so the creation form closes from the same
            // trailing corner every other sheet in the app does. The store and the tint are
            // handed over explicitly, the way the day card hands them to this sheet.
            //
            // Attached to the content *inside* the `NavigationView` rather than to the
            // `NavigationView` itself, which is where it was when neither the empty screen's
            // button nor the picker's bottom bar could open it. This is the app's first sheet
            // presented from inside another sheet, and it was also the only `.sheet` in the app
            // hanging off a navigation container instead of off ordinary content — `HomeMenuView`
            // attaches its two to the button, `WelcomeView` to its stack, the day card to the
            // card. A presentation on the root of a sheet's own content has the sheet that is
            // already on screen between it and anything that could present it; on the content it
            // is the navigation container's own, which is what the working three are.
            //
            // On the `Group` rather than inside a branch, because the branch is not stable: the
            // catalogue stops being empty the moment "Сохранить" reduces, so `introduction` is
            // replaced by `picker` while the form it presented is still dismissing. The `Group`
            // outlives that swap, as `navigationTitle` and the close button already do.
            .sheet(isPresented: $showNewTagSheet) {
                NewTagSheetView(isPresented: $showNewTagSheet)
                    .environmentObject(store)
                    .tint(accent)
            }
        }
        // These two stay on the outside, where the sheet's own appearance and dismissal are:
        // moved in with the presentation they would answer to the navigation container instead,
        // and the save that catches a swipe down would fire on a screen change.
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
            PrimaryButton("Новый тег", accent: accent) { showNewTagSheet = true }
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
                    Button("Новый тег") { showNewTagSheet = true }
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
                        tagChip(tag)
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

    // Filled means the tag is on the day; see `TagChip` for why that is a fill and not a shade.
    private func tagChip(_ tag: PickerTag) -> some View {
        TagChip(title: tag.name, color: Color.tagColor(for: tag.category), isFilled: tag.isSelected) {
            if tag.isSelected {
                selectedIds.remove(tag.id)
            } else {
                selectedIds.insert(tag.id)
            }
        }
    }

    // MARK: - Private Methods

    /// Grouped the way the day card sorts the same tags — by category, then by name — so a tag
    /// sits in the same place relative to its neighbours in both. A category this build does not
    /// know is a group of its own rather than a tag folded in somewhere it does not belong; it
    /// sorts after the four by its own number and draws grey.
    ///
    /// Whether a tag is on the day is resolved here, into the value the rows are drawn from,
    /// rather than being read out of `selectedIds` inside the chip builder. Both spellings put
    /// the same chip on screen; only this one makes picking a tag a *difference* in what the
    /// list below is handed, which is what a `ForEach` and a `FlowLayout` compare before they
    /// decide whether anything needs redrawing.
    private var tagsByCategory: [TagCategoryGroup] {
        let filtered = searchText.isEmpty
            ? availableTags
            : availableTags.filter { $0.name?.localizedCaseInsensitiveContains(searchText) == true }

        return Dictionary(grouping: filtered) { $0.category }
            .sorted { $0.key < $1.key }
            .map { entry in
                TagCategoryGroup(
                    category: entry.key,
                    tags: entry.value
                        .sorted { ($0.name ?? "") < ($1.name ?? "") }
                        .map { tag in
                            PickerTag(
                                id: tag.id,
                                name: tag.name ?? "",
                                category: tag.category,
                                isSelected: selectedIds.contains(tag.id)
                            )
                        }
                )
            }
    }

    /// The catalogue as this screen sees it. A deleted tag is a row whose name is `nil` — the
    /// table has no hard delete — so it would otherwise draw as a nameless chip that can still
    /// be put on a day, and a catalogue with nothing but deleted rows in it would show the
    /// picker with no tags in it rather than the introduction. The day card drops them the
    /// same way.
    private var availableTags: [UserTagRecord] {
        store.state.calendarState.userTags.filter { $0.name != nil }
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
private struct TagCategoryGroup: Identifiable, Equatable {
    let category: Int
    let tags: [PickerTag]

    var id: Int { category }
}

/// A tag as one row of the picker draws it — everything the chip needs and nothing else, the
/// selection included. See `tagsByCategory` for why the selection belongs in the value rather
/// than in a lookup the chip builder does for itself.
private struct PickerTag: Identifiable, Equatable {
    let id: String
    let name: String
    let category: Int
    let isSelected: Bool
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
