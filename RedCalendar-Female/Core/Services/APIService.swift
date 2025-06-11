//
//  APIService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 05.06.2025.
//

import Foundation
import UIKit

// MARK: - Protocol
protocol APIServiceProtocol {
    func migrateUser(userId: String) async throws -> MigrationResponse
    func verifyDevice(deviceId: String) async throws -> VerificationResponse
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse
    func logout(deviceId: String) async throws -> LogoutResponse
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

struct VerificationResponse: Codable {
    let success: Bool
    let data: VerificationData?
    let timestamp: String
    
    struct VerificationData: Codable {
        let userId: String
        let deviceId: String
        let lastVisitAt: String
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case deviceId = "device_id"
            case lastVisitAt = "last_visit_at"
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

struct APIError: Codable {
    let success: Bool
    let error: String
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
        }
    }
}

// MARK: - API Service Implementation
final class APIService: APIServiceProtocol {
    
    // MARK: - Properties
    private let baseURL = "https://api.calendar.red"
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
        
        let (data, response) = try await session.data(for: request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(MigrationResponse.self, from: data)
    }
    
    /// Verifies device authentication
    func verifyDevice(deviceId: String) async throws -> VerificationResponse {
        let url = URL(string: "\(baseURL)/auth/verify")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(VerificationResponse.self, from: data)
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
        
        let (data, response) = try await session.data(for: request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(APNSTokenResponse.self, from: data)
    }
    
    /// Logs out user from device
    func logout(deviceId: String) async throws -> LogoutResponse {
        let url = URL(string: "\(baseURL)/auth/logout")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try validateHTTPResponse(response, data: data)
        
        return try JSONDecoder().decode(LogoutResponse.self, from: data)
    }
    
    // MARK: - Private Methods
    
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
        
        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw APIServiceError.serverError(errorResponse.error)
            } else {
                throw APIServiceError.httpError(httpResponse.statusCode)
            }
        }
    }
}
