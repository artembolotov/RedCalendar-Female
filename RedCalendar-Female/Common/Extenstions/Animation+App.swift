//
//  Animation+App.swift
//  RedCalendar-Female
//

import SwiftUI

extension Animation {
    /// The curve the day card enters, leaves and pages with. Matches what `.bouncy` gives on
    /// iOS 17, spelled in the iOS 13 API so it is available on the deployment target.
    static let cardEntrance = Animation.spring(response: 0.5, dampingFraction: 0.7)

    /// The card moving from the level it inherited to the one its own content asks for. Calmer
    /// than the entrance: the top edge travels alone here, and a bounce on it reads as a glitch.
    static let cardLevelChange = Animation.spring(response: 0.35, dampingFraction: 0.9)
}
