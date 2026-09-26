//
//  ActivityView.swift
//  RedCalendar-Female
//

import SwiftUI
import UIKit

/// The system share sheet, as content for a SwiftUI `.sheet` rather than as `ShareLink`.
///
/// `ShareLink` presents the activity controller itself, out of reach of any state of ours: nothing
/// knows it is on screen, so a sheet asked for while it is up is refused by UIKit and the request
/// stays standing with nothing shown. Presented as a sheet, it is one more value of whatever state
/// drives that sheet, and replacing it is the same swap as replacing any other.
///
/// `onFinish` is not optional. The controller dismisses itself once an activity completes or is
/// cancelled, and that dismissal goes through UIKit, not through the binding that presented it —
/// the binding has to be told, or it would stand non-nil with nothing on screen.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
