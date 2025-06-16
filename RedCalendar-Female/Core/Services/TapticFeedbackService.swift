//
//  TapticFeedbackService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import UIKit

// MARK: - TapticFeedbackService Protocol
protocol TapticFeedbackServiceProtocol {
    func playSuccess()
    func playError()
    func playWarning()
    func prepare()
}

// MARK: - TapticFeedbackService Implementation
final class TapticFeedbackService: TapticFeedbackServiceProtocol {
    
    // MARK: - Private Properties
    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Initialization
    init() {
        // Initialize without preparation - call prepare() manually when needed
    }
    
    // MARK: - Public Methods
    
    /// Plays success haptic feedback
    func playSuccess() {
        notificationFeedbackGenerator.notificationOccurred(.success)
    }
    
    /// Plays error haptic feedback
    func playError() {
        notificationFeedbackGenerator.notificationOccurred(.error)
    }
    
    /// Plays warning haptic feedback
    func playWarning() {
        notificationFeedbackGenerator.notificationOccurred(.warning)
    }
    
    /// Prepares haptic generators for immediate use
    func prepare() {
        notificationFeedbackGenerator.prepare()
    }
}
