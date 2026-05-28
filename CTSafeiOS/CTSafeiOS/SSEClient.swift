import Foundation

struct SSEEvent: Sendable {
    let event: String
    let data: Data
}

final class SSEClient {
    private var task: Task<Void, Never>?

    // Legacy callback-based start (used by other callers if any)
    func start(path: String, body: [String: Any], token: String?, onEvent: @escaping @Sendable (SSEEvent) -> Void) {
        stop()
        let url = APIClient.shared.url(for: path)
        let bodyData = try? JSONSerialization.data(withJSONObject: body)
        task = Task {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = bodyData
            do {
                let (bytes, _) = try await URLSession.shared.bytes(for: request)
                var eventName = "message"
                var dataLines: [String] = []
                for try await line in bytes.lines {
                    if Task.isCancelled { return }
                    if line.isEmpty {
                        if !dataLines.isEmpty {
                            let payload = dataLines.joined(separator: "\n").data(using: .utf8) ?? Data()
                            onEvent(SSEEvent(event: eventName, data: payload))
                        }
                        eventName = "message"
                        dataLines.removeAll()
                        continue
                    }
                    if line.hasPrefix("event:") {
                        eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                }
            } catch { }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    // Async-stream based: yields SSEEvents until stream ends or task is cancelled
    static func stream(path: String, body: [String: Any], token: String?) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let url = APIClient.shared.url(for: path)
            let bodyData = try? JSONSerialization.data(withJSONObject: body)
            let t = Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                request.httpBody = bodyData

                do {
                    let session: URLSession = {
                        let cfg = URLSessionConfiguration.default
                        cfg.timeoutIntervalForRequest = 300
                        cfg.timeoutIntervalForResource = 600
                        return URLSession(configuration: cfg)
                    }()
                    let (bytes, _) = try await session.bytes(for: request)
                    var eventName = "message"
                    var dataLines: [String] = []
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty {
                            if !dataLines.isEmpty {
                                let payload = dataLines.joined(separator: "\n").data(using: .utf8) ?? Data()
                                continuation.yield(SSEEvent(event: eventName, data: payload))
                            }
                            eventName = "message"
                            dataLines.removeAll()
                            continue
                        }
                        if line.hasPrefix("event:") {
                            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in t.cancel() }
        }
    }
}
