//
//  CommentSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

// The comment applies as it is written, not on a confirmation. Everything else on the day card
// dispatches on the tap that caused it — the flow level, the period buttons — so a comment that
// needed an explicit "Готово" was the one edit in the app that could be lost, and it was lost
// exactly the way a user expects to be safe: by swiping the sheet down. Saving on the way out
// covers both exits and frees the trailing corner for the `CloseButton` every other sheet in the
// app closes from.
struct CommentSheetView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var isPresented: Bool

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            editor
                .padding(.horizontal, DayDetailsMetrics.screenInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle("Комментарий")
                .navigationBarTitleDisplayMode(.inline)
                // Saved before the dismissal rather than after it. `onDisappear` fires at the
                // *end* of the sheet's animation, so hanging the only save off it meant the day
                // card sat visible for the length of that animation still showing the old text.
                .closeButtonToolbar {
                    save()
                    isPresented = false
                }
        }
        .onAppear { text = savedComment }
        // Set from `.task` rather than `.onAppear`: the focus lands after the first render pass
        // instead of during it, which is what lets the keyboard come up with the sheet rather
        // than fighting the frame it is being presented in.
        .task { isFocused = true }
        // Independent of the save-on-exit above: this only moves the keyboard as the swipe
        // starts and cancels, it never touches `text` or dispatches anything.
        .duckKeyboardOnInteractiveDismiss(isFocused: $isFocused)
        // The swipe down never reaches the close button, and SwiftUI offers a sheet no hook for
        // the *start* of an interactive dismissal — so that exit is still caught here, a beat
        // later than the button's. Calling it twice on the button's path costs nothing: the
        // guard in `save` compares against state the reducer has already updated, so the second
        // call finds nothing to do.
        .onDisappear(perform: save)
    }

    // MARK: - Editor

    // The placeholder is an overlay rather than a layer underneath, so it does not depend on the
    // editor's background being see-through — `scrollContentBackground` is iOS 16 and the target
    // is 15.4. It is hidden from hit testing so a tap anywhere in the box still reaches the text.
    private var editor: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .transparentTextEditorBackground()
            // `TextEditor` insets its own text by about 5pt and offers no way to set it, which
            // puts the first character off the vertical the navigation title is aligned to.
            .padding(.horizontal, -5)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    // A literal rather than a stored `String`, so the string catalog extracts it
                    // the way it extracts every other piece of UI text in the app.
                    Text("Как прошёл день?")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Private Methods

    private var savedComment: String {
        store.state.calendarState.visibleComments[dayStamp] ?? ""
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != savedComment else { return }
        // An empty string is how a comment is deleted — `DatabaseMiddleware` stores it as `nil`,
        // which is this table's soft delete.
        store.send(.data(.saveComment(dayStamp, trimmed)))
    }
}

#Preview {
    // The sheet takes its accent from whoever presents it, so the preview has to stand in for
    // the `.tint` the day card applies — without it the editor's caret renders in the system
    // blue and the preview lies about the one thing this screen's colour depends on.
    CommentSheetView(dayStamp: 2000, isPresented: .constant(true))
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

private extension View {
    /// Strips `TextEditor`'s own opaque background so it sits on the sheet's surface rather than
    /// drawing a rectangle of a slightly different elevation on it.
    ///
    /// Below iOS 16 the only way in is `UITextView.appearance()`, which is global — the same
    /// objection `TransparentNavigationBar` makes about `UINavigationBar.appearance()` — so
    /// nothing is done there. The mismatch it leaves is a background against a background; the
    /// placeholder above does not depend on this working.
    @ViewBuilder
    func transparentTextEditorBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
