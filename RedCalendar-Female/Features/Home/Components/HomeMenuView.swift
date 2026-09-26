//
//  HomeMenuView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

/// Which of the menu's sheets is up. One value rather than a flag per sheet, because both hang off
/// the same button and only one can be on screen: with two flags, a notification tap that opened
/// Settings over Statistics left Statistics' flag standing, and SwiftUI brought it back the moment
/// Settings closed.
///
/// `openingOnEmail` is what the settings sheet's *root* is: normally the settings list, but
/// straight to `ProfileView` when a pending "add your email" tap is why the sheet is opening at
/// all. It is fixed for the whole presentation rather than read live off
/// `store.state.emailBinding != nil`: `.sheet`'s content re-evaluates on every render while
/// presented, and a live value would swap the root the moment the email screen finishes (which
/// clears `emailBinding` well before the person is done with `ProfileView` underneath it) —
/// closing the whole sheet instead of just the email step.
enum HomeMenuSheet: Identifiable, Hashable {
    case settings(openingOnEmail: Bool)
    case statistics

    var id: Self { self }
}

// MARK: - HomeMenuView Component
struct HomeMenuView: View {
    // Passed in rather than pulled from the environment: this view is toolbar content, and an
    // `@EnvironmentObject` there is not reliably reachable — a miss would be a crash, not a
    // wrong colour.
    let accent: Color

    // Owned by `HomeView`, not here, for the same reason: a pending "add your email" notification
    // tap (SYNC.md §20's engagement pushes) has to be able to open Settings from outside, and
    // that needs `store` — which this view cannot read reliably. `HomeView` can, and does it from
    // `openSettingsIfEmailPending()`; the menu's own buttons set it here.
    @Binding var presentedSheet: HomeMenuSheet?

    // What iOS 26 gives a toolbar button on its own. Matched by eye rather than derived —
    // there is no public metric for it, and it only has to read as the same control.
    private let fallbackDiameter: CGFloat = 36

    // MARK: - Body

    var body: some View {
        button
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .settings(openingOnEmail: true):
                    EmailEntryDeepLink()
                        .tint(accent)
                case .settings(openingOnEmail: false):
                    SettingsView()
                        .tint(accent)
                case .statistics:
                    StatisticsView()
                        .tint(accent)
                }
            }
    }

    // MARK: - Private Views

    // The calendar runs under the navigation bar now, so the glyph no longer sits on a plate —
    // it sits on whatever day happens to be passing beneath it. From iOS 26 the system draws
    // the button its own glass backing and nothing is needed here; below it the backing is
    // drawn by hand, same as `CloseButton` fills in the close role it does not have.
    @ViewBuilder
    private var button: some View {
        if #available(iOS 26.0, *) {
            menu
        } else {
            // `Menu`'s own rendering of an icon-only label is off-centre on iOS <26 — measured
            // ~4pt right of the circle's true centre, and unaffected by any `.frame` put on the
            // `Menu` or on the label's `Image`, because the misregistration happens inside the
            // control's own layout before either frame is applied. So the control's own glyph is
            // never what gets drawn: it stays `.clear` (see `menu`), while a second,
            // non-interactive `Image` — positioned by nothing but this `ZStack` — is what the
            // user actually sees. The `Menu` itself is left fully opaque and untouched, because
            // it also has to stay tappable: UIKit's hit-testing drops a view below a small alpha
            // threshold, which cost an earlier version of this its interaction entirely at
            // `.opacity(0)` — and still failed, silently, all the way up to `.opacity(0.02)`. That
            // threshold is undocumented and not something to build reliability on, so the fix
            // makes the glyph transparent instead of the control.
            ZStack {
                Circle().fill(.ultraThinMaterial)
                menu
                // `Menu`'s own label picks up the accent as its tint; a plain `Image` outside
                // that context does not, and needs it spelled out or it renders in the default
                // (black/white) foreground.
                Image(systemName: "ellipsis")
                    .foregroundStyle(accent)
                    .allowsHitTesting(false)
            }
            .frame(width: fallbackDiameter, height: fallbackDiameter)
        }
    }

    // Built with an explicit label rather than `Menu(_:systemImage:)`. That form carried the
    // title `HomeMenuView.Menu`, a key with no translation behind it in `Localizable.xcstrings`,
    // so it resolved to the key itself — invisible in a bare navigation bar, and not invisible
    // at all once iOS 26 put a glass circle around the control. Styling the title away is not
    // the fix: `labelStyle` travels through the environment and would strip the text off the
    // menu's own items too. The glyph is the whole control, so the glyph is the whole label,
    // and the name goes to VoiceOver directly.
    private var menu: some View {
        Menu {
            Button(action: {
                presentedSheet = .settings(openingOnEmail: false)
            }) {
                Label("HomeMenu.Settings.Button", systemImage: "gear")
            }

            Button(action: {
                presentedSheet = .statistics
            }) {
                Label("HomeMenu.Statistics.Button", systemImage: "chart.bar")
            }

            if #available(iOS 16.0, *) {
                Divider()

                let link = URL(string: Constants.URLs.appLink)!
                ShareLink(item: link) {
                    Label("HomeMenu.Share.Button", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            if #available(iOS 26.0, *) {
                Image(systemName: "ellipsis")
            } else {
                // Invisible, not absent: the overlay in `button` draws the glyph the user
                // actually sees. Kept as a real `Image` (rather than swapped for `EmptyView`)
                // so the control's own hit-target sizing and VoiceOver behaviour stay exactly
                // what an icon-only `Menu` would otherwise have.
                Image(systemName: "ellipsis")
                    .foregroundStyle(.clear)
            }
        }
        .accessibilityLabel("HomeMenu.A11y")
    }
}

/// The settings sheet's alternate root for `.settings(openingOnEmail: true)`: `ProfileView` alone,
/// with its own close button since there is no `SettingsView` list underneath it to supply one via
/// a back arrow.
///
/// A dedicated view rather than an inline `NavigationView { ProfileView() }` in `HomeMenuView`'s
/// body, so that the two roots carry the same `emailBindingSheet()` in the same place. Clearing
/// `AppState.emailBinding` once the whole settings sheet closes is `HomeView`'s job, for both
/// roots alike.
private struct EmailEntryDeepLink: View {
    var body: some View {
        NavigationView {
            ProfileView()
                .closeButtonToolbar()
        }
        .emailBindingSheet()
    }
}
