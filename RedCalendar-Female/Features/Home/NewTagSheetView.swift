//
//  NewTagSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

// The one sheet in this corner of the app that does *not* save on the way out, and the
// difference is that this one creates rather than edits. A comment and a day's tags are changes
// to a day that already exists, so the safe reading of a swipe down is "keep what I typed"; a
// half-filled creation form has no such prior — dismissing it means the tag was never made, and
// saving one out from under the user would leave an unnamed row in a catalogue they then have to
// go and clean up. So the close button and the swipe both cancel, and "Сохранить" is the only
// thing that writes.
struct NewTagSheetView: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var category: TagCategory = .fallback
    @FocusState private var isFocused: Bool

    private let sectionSpacing: CGFloat = 24
    private let swatchDiameter: CGFloat = 32
    private let swatchSpacing: CGFloat = 16
    // Padding first, ring inside it: the gap between the swatch and its ring is the difference.
    private let swatchRingInset: CGFloat = 4
    private let swatchRingWidth: CGFloat = 2

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                nameField
                categoryPicker

                Spacer(minLength: sectionSpacing)

                // The accent is passed in rather than read from the asset: `PrimaryButton`
                // fills with it, and a fill has to answer to the theme the user chose.
                PrimaryButton("Сохранить", isEnabled: canSave, accent: accent, action: save)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DayDetailsMetrics.screenInset)
            .padding(.vertical, sectionSpacing)
            .navigationTitle("Новый тег")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar { isPresented = false }
        }
        // Set from `.task` rather than `.onAppear`, as the comment editor does: the focus lands
        // after the first render pass instead of during it, which is what lets the keyboard come
        // up with the sheet rather than fighting the frame it is being presented in.
        .task { isFocused = true }
        .duckKeyboardOnInteractiveDismiss(isFocused: $isFocused)
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

    // MARK: - Private Methods

    private var accent: Color {
        store.state.accentTheme.accent
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicate
    }

    /// Compared against the whole catalogue rather than against the chosen category alone: a
    /// chip carries a name and a colour and nothing else, so two tags reading the same in two
    /// colours pose the user a question they have no way to answer from the picker.
    private var isDuplicate: Bool {
        guard !trimmedName.isEmpty else { return false }
        return store.state.calendarState.userTags.contains {
            $0.name?.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private func save() {
        guard canSave else { return }
        store.send(.data(.createUserTag(.newLocal(name: trimmedName, category: category))))
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
