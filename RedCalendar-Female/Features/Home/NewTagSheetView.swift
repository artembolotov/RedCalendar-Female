//
//  NewTagSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

// The one sheet in this corner of the app that does *not* save on the way out, whether it is
// making a tag or changing one. A comment and a day's tags are changes to a day that already
// exists, so the safe reading of a swipe down is "keep what I typed"; a half-filled tag form has
// no such prior — dismissing a new one means the tag was never made, and dismissing an edit means
// the rename or recolour was never applied, so saving either out from under the user would leave
// a change (or an unnamed row) they never confirmed. So "Отмена" and the swipe both cancel, and
// "Готово" is the only thing that writes.
//
// The two live in the navigation bar rather than as a `CloseButton` plus a full-width button
// under the form, unlike every other sheet in this corner of the app: those close on one action
// and save (if at all) as a side effect of typing, where this screen has two actions that are
// genuinely different — cancel and create — so both get a named button instead of one of them
// hiding behind an X. `.cancellationAction` / `.confirmationAction` are plain `ToolbarItem`
// placements and have carried a leading and a trailing bar button since long before iOS 26; the
// `#available` split lives one level down, in `ConfirmButton`, because from iOS 26 the confirm
// side renders as the platform's own blue checkmark (`ButtonRole.confirm`) rather than the word
// "Готово", the same way `CloseButton` renders an X instead of a word.
struct NewTagSheetView: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool

    /// The tag this screen is changing, or `nil` for a fresh one. The one difference between
    /// the two modes this screen has: everywhere else — the fields, the validation, the layout —
    /// creating and editing are the same form, which is the point of reusing it rather than
    /// building a second screen.
    private let editingTag: UserTagRecord?

    @State private var name: String
    @State private var category: TagCategory
    @FocusState private var isFocused: Bool
    /// Only ever set while `editingTag != nil` — the button that sets it doesn't exist on the
    /// creation form (see `deleteSection`), so there's nothing on that path to set it from.
    @State private var showDeleteConfirmation = false

    private let sectionSpacing: CGFloat = 24
    private let swatchDiameter: CGFloat = 32
    private let swatchSpacing: CGFloat = 16
    // Padding first, ring inside it: the gap between the swatch and its ring is the difference.
    private let swatchRingInset: CGFloat = 4
    private let swatchRingWidth: CGFloat = 2

    init(isPresented: Binding<Bool>, editingTag: UserTagRecord? = nil) {
        self._isPresented = isPresented
        self.editingTag = editingTag
        self._name = State(initialValue: editingTag?.name ?? "")
        self._category = State(initialValue: editingTag.flatMap { TagCategory(rawValue: $0.category) } ?? .fallback)
    }

    var body: some View {
        NavigationView {
            // A ScrollView, not a bare VStack pinned to the top: the field is focused the
            // moment this screen appears (see `.task` below), so the keyboard is always up, and
            // SwiftUI's keyboard avoidance for a plain VStack works by sliding the *whole* body
            // upward, not by shrinking it — there is nothing under a VStack that can absorb that
            // shift, so once the available height (title bar to keyboard) drops below the
            // content's height, the excess slides out past the top of the frame and under the
            // opaque navigation bar, which is a fixed layer on top of it. That height keeps
            // shrinking through a slow interactive dismiss, since the sheet card's top edge
            // keeps moving down while the keyboard stays put, so the overlap isn't a one-time
            // layout question, it recurs continuously as the drag proceeds. A `ScrollView`
            // absorbs the same keyboard inset by scrolling its content within its own clipped
            // bounds instead of translating the layer that bounds are computed from — the same
            // fix `TagsSheetView.tagsList` already uses for its own always-focusable search field.
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    nameField
                    categoryPicker

                    // Only on the form this tag already has a row to remove. `editingTag` is
                    // exactly that test — a fresh tag isn't in the catalogue yet, so there is
                    // nothing here for "Удалить тег" to act on.
                    if editingTag != nil {
                        deleteSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DayDetailsMetrics.screenInset)
                .padding(.vertical, sectionSpacing)
            }
            .navigationTitle(editingTag == nil ? "Новый тег" : "Тег")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton("Готово", isEnabled: canSave, action: save)
                }
            }
        }
        // Set from `.task` rather than `.onAppear`, as the comment editor does: the focus lands
        // after the first render pass instead of during it, which is what lets the keyboard come
        // up with the sheet rather than fighting the frame it is being presented in.
        .task { isFocused = true }
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Название", text: $name)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(save)
                .formFieldStyle()

            // Said rather than left for the disabled button to imply. The name is the only
            // thing the user typed, so a button that has gone grey without a reason reads as
            // the app having lost the text.
            if isDuplicate {
                Text("Такой тег уже есть")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Category

    // Four swatches and no words. A category is a colour on the day's dots and a colour on the
    // chips in the picker; it is not read out as anything anywhere else in the app, so the one
    // screen where it is chosen must not be the one place that gives it a name. `FlowLayout`
    // went with the names — four colours fit on any line at any Dynamic Type size.
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Категория")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: swatchSpacing) {
                ForEach(TagCategory.allCases) { candidate in
                    swatch(candidate)
                }
            }
        }
    }

    private func swatch(_ candidate: TagCategory) -> some View {
        let isSelected = candidate == category

        return Button {
            category = candidate
        } label: {
            Circle()
                .fill(candidate.color)
                .frame(width: swatchDiameter, height: swatchDiameter)
                // The ring is drawn around the padding rather than on the swatch itself, the
                // way the calendar rings the selected day: a chosen swatch grows a ring instead
                // of losing a ring's width of its own colour, and the row cannot reflow when
                // the choice moves, because the space is taken either way.
                .padding(swatchRingInset)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? candidate.color : Color.clear, lineWidth: swatchRingWidth)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // A colour has nothing to say to VoiceOver, so the swatches are numbered rather than
        // named — the position in the row is the only thing about them that is stable.
        .accessibilityLabel(Text("Категория \(candidate.rawValue + 1)"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Delete

    // A plain row rather than a second toolbar button: the two toolbar slots already read as
    // "cancel this form" and "commit this form", and a third destructive action up there would
    // have to fight both of them for a corner. Placed under the fields it edits instead, the way
    // a destructive action sits at the bottom of its own form on this platform generally — one
    // more thing to scroll past, not a third top-level choice next to "Отмена" and "Готово".
    private var deleteSection: some View {
        Button("Удалить тег", role: .destructive) {
            showDeleteConfirmation = true
        }
        // On the button itself rather than on the `NavigationView`, which is where this sat
        // before: a popover-style dialog is anchored to the exact view carrying the modifier, so
        // hanging it off the whole screen pointed its tail at the screen's centre instead of at
        // this row. Named after what it warns about rather than after the action, so the one
        // line a user actually reads says the consequence — a tag lives on every day it was put
        // on, and deleting it here does not ask those days first.
        .confirmationDialog(
            "Удалить тег?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить тег", role: .destructive, action: delete)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("«\(editingTag?.name ?? "")» пропадёт со всех дней, где он был проставлен.")
        }
    }

    // MARK: - Private Methods

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicate
    }

    /// Compared against the whole catalogue rather than against the chosen category alone: a
    /// chip carries a name and a colour and nothing else, so two tags reading the same in two
    /// colours pose the user a question they have no way to answer from the picker. The tag
    /// being edited is excluded from its own check — leaving the name untouched is not a
    /// collision with itself.
    private var isDuplicate: Bool {
        guard !trimmedName.isEmpty else { return false }
        return store.state.calendarState.userTags.contains {
            $0.id != editingTag?.id &&
            $0.name?.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private func save() {
        guard canSave else { return }
        if let editingTag {
            var updated = editingTag
            updated.name = trimmedName
            updated.category = category.rawValue
            store.send(.data(.updateUserTag(updated)))
        } else {
            store.send(.data(.createUserTag(.newLocal(name: trimmedName, category: category))))
        }
        isPresented = false
    }

    /// Called only from the confirmation dialog's own destructive button — `deleteSection` only
    /// asks for that dialog, never for this directly. `editingTag` is always set by the time this
    /// runs: the row that opens the dialog exists only while it is.
    private func delete() {
        guard let editingTag else { return }
        var deleted = editingTag
        deleted.name = nil
        store.send(.data(.deleteUserTag(deleted)))
        isPresented = false
    }
}

#Preview {
    // The sheet takes its accent from the store rather than from the asset, but the navigation
    // bar and the text field's caret take it from the `.tint` whoever presents it applies — so
    // the preview has to stand in for that too, or it lies about the one thing this screen's
    // colour depends on.
    NewTagSheetView(isPresented: .constant(true))
        .tint(AccentTheme.coral.accent)
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test", userDetails: nil),
                    calendarState: CalendarState(
                        userTags: [
                            UserTagRecord(id: "1", name: "Головная боль", category: 0)
                        ]
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Редактирование") {
    NewTagSheetView(
        isPresented: .constant(true),
        editingTag: UserTagRecord(id: "1", name: "Головная боль", category: 0)
    )
        .tint(AccentTheme.coral.accent)
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test", userDetails: nil),
                    calendarState: CalendarState(
                        userTags: [
                            UserTagRecord(id: "1", name: "Головная боль", category: 0)
                        ]
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
