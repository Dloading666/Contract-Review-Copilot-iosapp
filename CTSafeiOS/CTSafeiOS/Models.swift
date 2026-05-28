import Foundation
import SwiftUI

struct AuthUser: Codable, Identifiable {
    let id: String
    let email: String?
    let emailVerified: Bool
    let accountStatus: String
    let createdAt: String?
    let hasPassword: Bool?
}

struct LoginResponse: Codable {
    let success: Bool?
    let token: String?
    let user: AuthUser?
    let error: String?
}

struct BasicAuthResponse: Codable {
    let success: Bool?
    let message: String?
    let devCode: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case devCode = "dev_code"
        case error
    }
}

struct SendCodeRequest: Codable {
    let email: String
    let website: String
    let clientElapsedMs: Int
    let captchaToken: String?

    enum CodingKeys: String, CodingKey {
        case email
        case website
        case clientElapsedMs = "client_elapsed_ms"
        case captchaToken = "captcha_token"
    }
}

struct RegisterRequest: Codable {
    let email: String
    let code: String
    let password: String
    let website: String
    let clientElapsedMs: Int
    let captchaToken: String?

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case password
        case website
        case clientElapsedMs = "client_elapsed_ms"
        case captchaToken = "captcha_token"
    }
}

struct MeResponse: Codable {
    let user: AuthUser?
}

enum RiskLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case critical

    var title: String {
        switch self {
        case .low: "低风险"
        case .medium: "中风险"
        case .high, .critical: "高风险"
        }
    }

    var color: Color {
        switch self {
        case .low: DogeTheme.green
        case .medium: DogeTheme.orange
        case .high, .critical: DogeTheme.red
        }
    }
}

struct DocumentSummary: Codable, Identifiable {
    struct LatestReview: Codable {
        let sessionId: String?
        let status: String?
        let overallRisk: RiskLevel?
        let riskCounts: [String: Int]?
        let completedAt: String?
    }

    let id: String
    let filename: String
    let sourceType: String
    let status: String
    let createdAt: String?
    let updatedAt: String?
    let latestReview: LatestReview?
}

struct DocumentsResponse: Codable {
    let documents: [DocumentSummary]
}

struct ReviewSessionSummary: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let documentId: String?
    let filename: String
    let status: String
    let reviewStage: String
    let overallRisk: RiskLevel
    let riskCounts: [String: Int]
    let issues: [RiskFinding]
    let reportParagraphs: [String]
    let createdAt: String?
    let updatedAt: String?
    let completedAt: String?
}

struct ReviewSessionDetail: Codable {
    let sessionId: String
    let documentId: String?
    let filename: String
    let contractText: String
    let status: String
    let reviewStage: String
    let overallRisk: RiskLevel
    let riskCounts: [String: Int]
    let issues: [RiskFinding]
    let reportParagraphs: [String]
    let createdAt: String?
    let updatedAt: String?
    let completedAt: String?
}

struct ReviewSessionsResponse: Codable {
    let sessions: [ReviewSessionSummary]
}

struct ReviewSessionResponse: Codable {
    let session: ReviewSessionDetail
}

struct RiskFinding: Codable, Identifiable {
    var id: String { "\(clause)-\(issue)" }
    let clause: String
    let issue: String
    let level: RiskLevel?
    let riskLevel: Int?
    let suggestion: String?
    let legalReference: String?
    let matchedText: String?

    enum CodingKeys: String, CodingKey {
        case clause
        case issue
        case level
        case riskLevel = "risk_level"
        case suggestion
        case legalReference = "legal_reference"
        case matchedText = "matched_text"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: String
    let sessionId: String?
    let role: String
    let content: String
    let status: String?
    let model: String?
    let createdAt: String?
}

struct ChatMessagesResponse: Codable {
    let messages: [ChatMessage]
}

struct ChatResponse: Codable {
    let reply: String
    let model: String?
    let degraded: Bool?
}

// OCR file upload response from /api/ocr/ingest (backend returns snake_case)
struct OcrIngestResponse: Codable {
    let mergedText: String
    let displayName: String?
    let documentId: String?
    let sourceType: String?
    let warnings: [String]?

    enum CodingKeys: String, CodingKey {
        case mergedText = "merged_text"
        case displayName = "display_name"
        case documentId = "document_id"
        case sourceType = "source_type"
        case warnings
    }
}

// Confirm breakpoint — used internally, response is SSE (handled by SSEClient)
struct ConfirmReviewBody: Codable {
    let confirmed: Bool
    let contractText: String
    let issues: [RiskFinding]
    let filename: String?
}

// Review queue submission
struct ReviewQueueResponse: Codable {
    let taskId: String
    let sessionId: String
    let status: String
}
