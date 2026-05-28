import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器响应异常"
        case .server(let message):
            return message
        }
    }
}

final class APIClient {
    nonisolated(unsafe) static let shared = APIClient()

    var baseURL = URL(string: "https://ctsafe.top/api")!
    var tokenProvider: () -> String? = { nil }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private init() {}

    func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "GET"
        authorize(&request)
        return try await send(request)
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        authorize(&request)
        return try await send(request)
    }

    func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        authorize(&request)
        return try await send(request)
    }

    // Multipart file upload — returns decoded response T
    func uploadFile<T: Decodable>(_ path: String, fileURL: URL, fieldName: String = "file") async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var data = Data()

        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mimeType = mimeType(for: fileURL.pathExtension)

        data.append("--\(boundary)\r\n".utf8Data)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".utf8Data)
        data.append("Content-Type: \(mimeType)\r\n\r\n".utf8Data)
        data.append(fileData)
        data.append("\r\n--\(boundary)--\r\n".utf8Data)

        var request = URLRequest(url: url(for: path))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        authorize(&request)
        return try await send(request)
    }

    private func authorize(_ request: inout URLRequest) {
        guard let token = tokenProvider() else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    func url(for path: String) -> URL {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appending(path: normalizedPath)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            let message = payload?["error"] as? String ?? payload?["detail"] as? String
            throw APIError.server(message ?? "请求失败：\(http.statusCode)")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc": return "application/msword"
        case "txt": return "text/plain"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}
