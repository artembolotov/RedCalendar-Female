//
//  Animation+App.swift
//  RedCalendar-Female
//

import SwiftUI

extension Animation {
    /// The curve the day card enters, leaves and pages with. Matches what `.bouncy` gives on
    /// iOS 17, spelled in the iOS 13 API so it is available on the deployment target.
    static let cardEntrance = Animation.spring(response: 0.5, dampingFraction: 0.7)
}
