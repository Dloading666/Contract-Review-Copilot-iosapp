import Foundation
import SwiftUI

@MainActor
final class AuthStore: ObservableObject {
    @Published var user: AuthUser?
    @Published var token: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenKey = "ctsafe.jwt"

    init() {
        APIClient.shared.tokenProvider = {
            KeychainStore.read(key: "ctsafe.jwt")
        }
    }

    func restoreSession() async {
        guard let storedToken = KeychainStore.read(key: tokenKey) else { return }
        token = storedToken
        await refreshUser()
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: LoginResponse = try await APIClient.shared.post(
                "/auth/login",
                body: ["email": email, "password": password]
            )
            guard let nextToken = response.token, let nextUser = response.user else {
                throw APIError.server(response.error ?? "登录失败")
            }
            token = nextToken
            user = nextUser
            KeychainStore.save(nextToken, key: tokenKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRegisterCode(email: String, clientElapsedMs: Int) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = SendCodeRequest(
                email: email,
                website: "",
                clientElapsedMs: clientElapsedMs,
                captchaToken: nil
            )
            let response: BasicAuthResponse = try await APIClient.shared.post("/auth/send-code", body: request)
            return response.devCode
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func register(email: String, code: String, password: String, clientElapsedMs: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let request = RegisterRequest(
                email: email,
                code: code,
                password: password,
                website: "",
                clientElapsedMs: clientElapsedMs,
                captchaToken: nil
            )
            let _: BasicAuthResponse = try await APIClient.shared.post("/auth/register", body: request)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshUser() async {
        do {
            let response: MeResponse = try await APIClient.shared.get("/auth/me")
            user = response.user
        } catch {
            logout()
        }
    }

    func acceptOAuthToken(_ nextToken: String) async {
        token = nextToken
        KeychainStore.save(nextToken, key: tokenKey)
        await refreshUser()
    }

    func logout() {
        token = nil
        user = nil
        KeychainStore.delete(key: tokenKey)
    }
}
