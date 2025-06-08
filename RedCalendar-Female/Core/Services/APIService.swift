//
//  APIService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 05.06.2025.
//

import Foundation
import UIKit

protocol APIServiceProtocol {
    func migrateUser(userId: String) async throws -> MigrationResponse
    func verifyDevice(deviceId: String) async throws -> VerificationResponse
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse
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

struct APIError: Codable {
    let success: Bool
    let error: String
    let timestamp: String
}

struct APNSTokenResponse: Codable {
    let success: Bool
    let message: String?
    let timestamp: String
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
    
    // MARK: - Migration
    func migrateUser(userId: String) async throws -> MigrationResponse {
        let url = URL(string: "\(baseURL)/auth/migrate")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deviceModel = await getDeviceModel()
        let requestBody = [
            "user_id": userId,
            "device_model": deviceModel
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode >= 400 {
                // Try to parse error response
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                } else {
                    throw APIServiceError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        let migrationResponse = try JSONDecoder().decode(MigrationResponse.self, from: data)
        return migrationResponse
    }
    
    // MARK: - Verification
    func verifyDevice(deviceId: String) async throws -> VerificationResponse {
        let url = URL(string: "\(baseURL)/auth/verify")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                } else {
                    throw APIServiceError.httpError(httpResponse.statusCode)
                }
            }
        }
        
        let verificationResponse = try JSONDecoder().decode(VerificationResponse.self, from: data)
        return verificationResponse
    }
    
    // MARK: - APNS Token Update
    func updateAPNSToken(deviceId: String, apnsToken: String) async throws -> APNSTokenResponse {
        let url = URL(string: "\(baseURL)/auth/apns-token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(deviceId)", forHTTPHeaderField: "Authorization")
        
        let body = ["apns_token": apnsToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                throw APIServiceError.serverError(errorResponse.error)
            } else {
                throw APIServiceError.httpError(httpResponse.statusCode)
            }
        }
        
        return try JSONDecoder().decode(APNSTokenResponse.self, from: data)
    }
    
    // MARK: - Helpers
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
