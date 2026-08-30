//
//  APIService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 05.06.2025.
//

import Foundation
import UIKit

// MARK: - Protocol
protocol APIServiceProtocol: Sendable {
    func migrateUser(userId: String) async throws -> MigrationResponse
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse
    func logout(deviceId: String) async throws -> LogoutResponse
    /// Requests account deletion (SYNC.md §17.3). Marks the account for deletion, drops every
    /// session server-side and answers with the date the mark becomes permanent — logging back in
    /// before then restores everything (§17.4).
    func deleteAccount(deviceId: String) async throws -> DeleteAccountResponse
    func checkEmail(_ email: String) async throws -> CheckEmailResponse
    func checkPhone(_ phone: String) async throws -> CheckPhoneResponse
    func verifyCode(email: String, code: String, name: String?) async throws -> VerifyCodeResponse
    func verifyFlashCall(requestId: String, code: String) async throws -> VerifyFlashCallResponse
    func sync(deviceId: String, request: SyncRequest) async throws -> SyncResponse
}

// MARK: - Request Models
struct MigrateUserRequest: Codable {
    let userId: String
    let deviceModel: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceModel = "device_model"
    }
}

struct UpdateAPNSTokenRequest: Codable {
    let apnsToken: String
    let isDevelopment: Bool
    
    enum CodingKeys: String, CodingKey {
        case apnsToken = "apns_token"
        case isDevelopment = "is_development"
    }
}

struct CheckEmailRequest: Codable {
    let email: String
}

struct CheckPhoneRequest: Codable {
    let phone: String
}

struct VerifyCodeRequest: Codable {
    let email: String
    let code: String
    let deviceModel: String
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case email
        case code
        case deviceModel = "device_model"
        case name
    }
}

struct VerifyFlashCallRequest: Codable {
    let requestId: String
    let code: String
    let deviceModel: String
    
    enum CodingKeys: String, CodingKey {
        case requestId
        case code
        case deviceModel = "device_model"
    }
}

// MARK: - Response Models
struct MigrationResponse: Codable {
    let success: Bool
    let data: MigrationData?
    let message: String?
    let timestamp: String
    
    struct MigrationData: Codable {
        let deviceId: String
        let userId: String
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
            case userId = "user_id"
        }
    }
}

struct APNSTokenResponse: Codable {
    let success: Bool
    let message: String?
    let timestamp: String
}

struct LogoutResponse: Codable {
    let success: Bool
    let message: String?
    let timestamp: String
}

struct DeleteAccountResponse: Codable {
    let success: Bool
    let data: DeleteAccountData?
    let message: String?
    let timestamp: String

    struct DeleteAccountData: Codable {
        /// ISO 8601. When this passes with the mark still standing, the nightly purge is free to
        /// erase the row (SYNC.md §17.6) — logging in before it lands undoes the mark instead.
        let purgeAfter: String

        enum CodingKeys: String, CodingKey {
            case purgeAfter = "purge_after"
        }
    }
}

struct CheckEmailResponse: Codable {
    let data: CheckEmailData
    let timestamp: String
    
    struct CheckEmailData: Codable {
        let exists: Bool
        let email: String
        let name: String?
    }
}

struct CheckPhoneResponse: Codable {
    let success: Bool
    let error: String?
    let message: String?
    let data: CheckPhoneData?
    let timestamp: String
    
    struct CheckPhoneData: Codable {
        let phone: String
        let exists: Bool
        let flashCall: FlashCallData?
        
        enum CodingKeys: String, CodingKey {
            case phone
            case exists
            case flashCall = "flash_call"
        }
    }
    
    struct FlashCallData: Codable {
        let requestId: String
        let from: String
        
        enum CodingKeys: String, CodingKey {
            case requestId
            case from
        }
    }
}

struct VerifyCodeResponse: Codable {
    let success: Bool
    let data: VerifyCodeData?
    let message: String?
    let timestamp: String
    
    struct VerifyCodeData: Codable {
        let deviceId: String
        let user: UserDetails  // ← Simplified - removed userId and isNewUser
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
            case user
        }
    }
}

struct VerifyFlashCallResponse: Codable {
    let success: Bool
    let error: String?
    let message: String?
    let data: VerifyFlashCallData?
    let timestamp: String
    
    struct VerifyFlashCallData: Codable {
        let deviceId: String
        let user: UserDetails  // ← Now uses shared UserDetails
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
            case user
        }
    }
}

struct APIError: Codable {
    let error: String        // Error code (e.g., "CODE_ALREADY_SENT")
    let message: String?     // Localized error message from server
    let timestamp: String
}

// MARK: - Errors
enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case httpError(Int)
    case serverError(String)
    case networkError(Error)
    case unauthorized
    case phoneNotAllowed(String) // New error type for phone authentication
    case rateLimited(retryAfter: TimeInterval?, message: String?)   // 429
    case serverUnavailable(status: Int, message: String?)           // 5xx

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "User not authorized"
        case .phoneNotAllowed(let message):
            return message
        case .rateLimited(_, let message):
            return message ?? "Too many requests. Please try again later."
        case .serverUnavailable(let status, let message):
            return message ?? "Server unavailable (HTTP \(status))."
        }
    }
}

// MARK: - API Service Implementation
final class APIService: APIServiceProtocol, Sendable {
    
    // MARK: - Properties
    private let baseURL = Constants.URLs.api
    private let session: URLSession
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Migrates user to new device authentication system
    func migrateUser(userId: String) async throws -> MigrationResponse {
        let url = URL(string: "\(baseURL)/auth/migrate")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceModel = await getDeviceModel()
        let requestBody = MigrateUserRequest(
            userId: userId,
            deviceModel: deviceModel
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(MigrationResponse.self, from: data)
    }
    
    /// Updates APNS token for push notifications
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse {
        let url = URL(string: "\(baseURL)/auth/apns-token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        // Automatic environment detection
        #if DEBUG
        let isDevelopment = true
        #else
        let isDevelopment = false
        #endif
        
        let body = UpdateAPNSTokenRequest(
            apnsToken: apnsToken,
            isDevelopment: isDevelopment
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(APNSTokenResponse.self, from: data)
    }
    
    /// Logs out user from device
    func logout(deviceId: String) async throws -> LogoutResponse {
        let url = URL(string: "\(baseURL)/auth/logout")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(LogoutResponse.self, from: data)
    }

    /// Marks the account for deletion — same endpoint family as `logout`, `DELETE` and
    /// `Authorization: Bearer <device_id>`, under the same session budget (SYNC.md §17.3).
    func deleteAccount(deviceId: String) async throws -> DeleteAccountResponse {
        let url = URL(string: "\(baseURL)/auth/account")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        try validateHTTPResponse(response, data: data)

        return try JSONDecoder().decode(DeleteAccountResponse.self, from: data)
    }

    /// Checks if email exists and returns user info
    func checkEmail(_ email: String) async throws -> CheckEmailResponse {
        let url = URL(string: "\(baseURL)/auth/check-email")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add language headers for localized responses
        addLanguageHeaders(to: &request)
        
        let requestBody = CheckEmailRequest(email: email)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(CheckEmailResponse.self, from: data)
    }
    
    /// Checks if phone exists in old database and initiates Flash Call
    func checkPhone(_ phone: String) async throws -> CheckPhoneResponse {
        let url = URL(string: "\(baseURL)/auth/check-phone")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add language headers for localized responses
        addLanguageHeaders(to: &request)
        
        let requestBody = CheckPhoneRequest(phone: phone)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(CheckPhoneResponse.self, from: data)
    }
    
    /// Verifies code and registers/logs in user with device
    func verifyCode(email: String, code: String, name: String?) async throws -> VerifyCodeResponse {
        let url = URL(string: "\(baseURL)/auth/verify-code")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add language headers for localized responses
        addLanguageHeaders(to: &request)
        
        let requestBody = VerifyCodeRequest(
            email: email,
            code: code,
            deviceModel: await getDeviceModel(),
            name: name
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(VerifyCodeResponse.self, from: data)
    }
    
    /// Verifies Flash Call code and authenticates user
    func verifyFlashCall(requestId: String, code: String) async throws -> VerifyFlashCallResponse {
        let url = URL(string: "\(baseURL)/auth/verify-flash-call")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add language headers for localized responses
        addLanguageHeaders(to: &request)
        
        let deviceModel = await getDeviceModel()
        let requestBody = VerifyFlashCallRequest(
            requestId: requestId,
            code: code,
            deviceModel: deviceModel
        )
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await performRequest(request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(VerifyFlashCallResponse.self, from: data)
    }
    
    /// One round of a sync run (SYNC.md §4).
    ///
    /// The 200 body is the bare object of §4.2 — no `success`/`timestamp` envelope, because a run
    /// has no partial success and `rejected` is not an error. 4xx and 5xx *do* come wrapped, and
    /// `validateHTTPResponse` reads them exactly as it does for the auth endpoints.
    ///
    /// Its request and response models live in `SyncPayload.swift` rather than here with the
    /// others: `DatabaseServiceProtocol.applySync` takes the same rows, so they are a shape two
    /// services share.
    func sync(deviceId: String, request syncRequest: SyncRequest) async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/data/sync")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONEncoder().encode(syncRequest)

        let (data, response) = try await performRequest(request)

        try validateHTTPResponse(response, data: data)

        return try JSONDecoder().decode(SyncResponse.self, from: data)
    }

    // MARK: - Private Methods

    /// Runs the request and wraps any transport-level failure (DNS, timeout, offline, TLS…)
    /// as `APIServiceError.networkError` — the single choke point for that, same role
    /// `validateHTTPResponse` plays for HTTP status. Without it, a raw `URLError` reaches
    /// `AuthenticationError.from(_:)`, doesn't match its `APIServiceError.networkError` case,
    /// and falls through to the generic `.unknownError`.
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as APIServiceError {
            throw error
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Gets device model identifier
    @MainActor
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Return exact device identifier (e.g., "iPhone17,4", "iPad14,5")
        return identifier
    }
    
    /// Validates HTTP response and handles errors
    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }
        
        if httpResponse.statusCode == 401 {
            AppLogger.warn("API returned 401 Unauthorized - user needs re-authentication")
            throw APIServiceError.unauthorized
        }

        let errorResponse = try? JSONDecoder().decode(APIError.self, from: data)

        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw APIServiceError.rateLimited(retryAfter: retryAfter, message: errorResponse?.message ?? errorResponse?.error)
        }

        if httpResponse.statusCode >= 500 {
            throw APIServiceError.serverUnavailable(status: httpResponse.statusCode, message: errorResponse?.message ?? errorResponse?.error)
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse {
                // Use localized message from server if available, otherwise fall back to error code
                let errorMessage = errorResponse.message ?? errorResponse.error
                throw APIServiceError.serverError(errorMessage)
            } else {
                throw APIServiceError.httpError(httpResponse.statusCode)
            }
        }
    }
    
    /// Add language-related headers to request
    private func addLanguageHeaders(to request: inout URLRequest) {
        let currentLanguage = Locale.current.languageCode ?? "en"
        // Custom headers for our API
        request.setValue(
            currentLanguage,
            forHTTPHeaderField: "X-App-Language"
        )
    }
}
