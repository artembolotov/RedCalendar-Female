//
//  EmailAuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum EmailAuthState {
    case entry                                       // Enter email address
    case checking(email: String)                     // Checking if email exists
    case passwordEntry(                             // Enter password for existing user
        email: String,
        userName: String,
        error: AuthenticationError? = nil
    )
    case passwordVerifying(                         // Verifying email + password
        email: String,
        password: String
    )
    case registration(                              // New user registration flow
        email: String,
        step: RegistrationStep
    )
    case passwordRecovery(                          // Forgot password flow
        email: String,
        step: PasswordRecoveryStep
    )
}

enum RegistrationStep {
    case userDataEntry                              // Enter name and create password (combined screen)
    case creating(                                  // Creating account on server
        name: String,
        password: String
    )
    case emailVerification(verificationCode: String?) // Verify email with code
    case verifyingEmail(                           // Verifying email code on server
        verificationCode: String
    )
}

enum PasswordRecoveryStep {
    case codeRequesting                            // Requesting verification code
    case codeVerification(error: AuthenticationError? = nil) // Enter 6-digit code
    case verifyingCode(code: String)               // Verifying code on server
    case passwordReset                             // Enter new password + confirmation
    case resettingPassword(                        // Resetting password on server
        newPassword: String,
        confirmPassword: String
    )
}
